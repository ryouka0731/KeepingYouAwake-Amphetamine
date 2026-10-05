//
//  KYADriveAliveTimer.m
//  KeepingYouAwake
//

#import "KYADriveAliveTimer.h"
#import <KYACommon/KYACommon.h>
#include <fcntl.h>
#include <sys/stat.h>
#include <unistd.h>

NSString * const KYADriveAlivePingFileName = @".KeepingYouAwake-DriveAlive";

/// Every ping file starts with this, followed by the writing timer's token.
/// A file without it is someone else's and is never written or removed.
static NSString * const KYADriveAliveContentPrefix = @"keepingyouawake ";

/// First bytes of a regular file at `path` (symlinks are not followed).
/// nil if it doesn't exist, isn't a regular file or can't be read.
static NSString * _Nullable KYADriveAliveReadHead(NSString *path)
{
    int fd = open(path.fileSystemRepresentation, O_RDONLY | O_NOFOLLOW);
    if(fd < 0) { return nil; }
    struct stat info;
    if(fstat(fd, &info) != 0 || !S_ISREG(info.st_mode))
    {
        close(fd);
        return nil;
    }
    char buffer[128];
    ssize_t count = read(fd, buffer, sizeof(buffer));
    close(fd);
    if(count <= 0) { return @""; }
    return [[NSString alloc] initWithBytes:buffer length:(NSUInteger)count encoding:NSUTF8StringEncoding] ?: @"";
}

/// One queue for every timer's ticks and cleanup, so checking a ping's
/// owner and removing it can't interleave with another timer's write to
/// the same path.
static dispatch_queue_t KYADriveAliveQueue(void)
{
    static dispatch_queue_t queue;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        queue = dispatch_queue_create("info.marcel-dierkes.KeepingYouAwake.drive-alive", DISPATCH_QUEUE_SERIAL);
    });
    return queue;
}

/// Writes `data` in place (real I/O on that drive) unless the path holds
/// something that isn't a Drive Alive ping: a user's file, a directory or
/// a symlink is left untouched.
static BOOL KYADriveAliveWritePing(NSString *path, NSData *data, NSError **outError)
{
    const char *fsPath = path.fileSystemRepresentation;
    int fd = open(fsPath, O_WRONLY | O_CREAT | O_EXCL | O_NOFOLLOW, 0644);
    if(fd < 0 && errno == EEXIST)
    {
        // Ours from an earlier session (or a crashed one) is fine to reuse,
        // and so is an empty file: what an interrupted or failed write of
        // ours leaves behind.
        NSString *head = KYADriveAliveReadHead(path);
        if(head == nil || (head.length > 0 && ![head hasPrefix:KYADriveAliveContentPrefix]))
        {
            if(outError) { *outError = [NSError errorWithDomain:NSPOSIXErrorDomain code:EEXIST userInfo:nil]; }
            return NO;
        }
        fd = open(fsPath, O_WRONLY | O_TRUNC | O_NOFOLLOW);
    }
    if(fd < 0)
    {
        if(outError) { *outError = [NSError errorWithDomain:NSPOSIXErrorDomain code:errno userInfo:nil]; }
        return NO;
    }
    ssize_t written = write(fd, data.bytes, data.length);
    int writeErrno = errno;
    if(written != (ssize_t)data.length)
    {
        // Leave an empty file, which the next tick reclaims, rather than a
        // partial one that no longer carries the marker.
        (void)ftruncate(fd, 0);
    }
    close(fd);
    if(written != (ssize_t)data.length)
    {
        if(outError) { *outError = [NSError errorWithDomain:NSPOSIXErrorDomain code:writeErrno userInfo:nil]; }
        return NO;
    }
    return YES;
}

/// Removes `path` only if it is a ping written by the timer with `token`,
/// so a replacement timer's file (or anyone else's) survives.
static void KYADriveAliveRemovePing(NSString *path, NSString *token)
{
    NSString *ownPrefix = [KYADriveAliveContentPrefix stringByAppendingFormat:@"%@ ", token];
    if([KYADriveAliveReadHead(path) hasPrefix:ownPrefix])
    {
        unlink(path.fileSystemRepresentation);
    }
}

@interface KYADriveAliveTimer ()
@property (nonatomic, readwrite, getter=isRunning) BOOL running;
@property (nonatomic, nullable) dispatch_source_t timer;
@property (nonatomic, copy, readonly) NSURL *pingFileURL;
@property (nonatomic) os_log_t log;
@property (nonatomic, copy) KYADriveAliveVolumesProvider volumesProvider;
/// Identifies this timer's ping files (see KYADriveAliveRemovePing).
@property (nonatomic, copy) NSString *token;
/// External ping files written this run (removed on stop). Only touched on
/// the timer queue.
@property (nonatomic, nullable) NSMutableSet<NSURL *> *writtenExternalPingURLs;
/// Volumes whose write already failed this run, so the log isn't spammed
/// every tick. Only touched on the timer queue.
@property (nonatomic, nullable) NSMutableSet<NSURL *> *failedVolumeURLs;
@end

@implementation KYADriveAliveTimer
@synthesize pingFileURL = _pingFileURL;

- (instancetype)initWithInterval:(NSTimeInterval)interval
{
    return [self initWithInterval:interval volumesProvider:nil];
}

- (instancetype)initWithInterval:(NSTimeInterval)interval
                 volumesProvider:(KYADriveAliveVolumesProvider)volumesProvider
{
    self = [super init];
    if(self)
    {
        _interval = interval > 0 ? interval : 30.0;
        _log = KYALogCreateWithCategory("DriveAlive");
        if(volumesProvider == nil)
        {
            volumesProvider = ^NSArray<NSURL *> *{
                return [KYADriveAliveTimer externalWritableVolumeURLs];
            };
        }
        _volumesProvider = [volumesProvider copy];
        _token = [NSUUID UUID].UUIDString;
    }
    return self;
}

+ (NSArray<NSURL *> *)externalWritableVolumeURLs
{
    NSArray<NSURLResourceKey> *keys = @[NSURLVolumeIsInternalKey, NSURLVolumeIsLocalKey,
                                        NSURLVolumeIsReadOnlyKey, NSURLVolumeIsRootFileSystemKey];
    // Hidden volumes too: an external drive can be mounted hidden; the
    // eligibility check below filters out the system ones.
    Auto volumes = [NSFileManager.defaultManager mountedVolumeURLsIncludingResourceValuesForKeys:keys
                                                                                        options:0];
    Auto result = [NSMutableArray<NSURL *> array];
    for(NSURL *volume in volumes)
    {
        NSDictionary<NSURLResourceKey, id> *values = [volume resourceValuesForKeys:keys error:nil];
        if([self isEligibleVolumeWithResourceValues:values]) { [result addObject:volume]; }
    }
    return [result copy];
}

+ (BOOL)isEligibleVolumeWithResourceValues:(NSDictionary<NSURLResourceKey, id> *)values
{
    if([values[NSURLVolumeIsRootFileSystemKey] boolValue]) { return NO; }
    if([values[NSURLVolumeIsLocalKey] boolValue] == NO) { return NO; }   // network shares
    if([values[NSURLVolumeIsReadOnlyKey] boolValue]) { return NO; }
    // Unknown counts as internal: only touch drives known to be external.
    NSNumber *isInternal = values[NSURLVolumeIsInternalKey];
    return isInternal != nil && isInternal.boolValue == NO;
}

- (void)dealloc
{
    [self stop];
}

- (NSURL *)pingFileURL
{
    if(_pingFileURL == nil)
    {
        Auto fileName = [NSString stringWithFormat:@"info.marcel-dierkes.KeepingYouAwake.drive-alive.%d",
                         NSProcessInfo.processInfo.processIdentifier];
        _pingFileURL = [NSURL fileURLWithPath:[NSTemporaryDirectory() stringByAppendingPathComponent:fileName]
                                  isDirectory:NO];
    }
    return _pingFileURL;
}

- (void)start
{
    if(self.running) { return; }

    Auto source = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, KYADriveAliveQueue());
    uint64_t intervalNs = (uint64_t)(self.interval * NSEC_PER_SEC);
    // Fire immediately so a drive that's already near its spin-down
    // threshold gets touched before it stops; subsequent fires use
    // a loose 10% tolerance — exact firing isn't important.
    dispatch_source_set_timer(source,
                              DISPATCH_TIME_NOW,
                              intervalNs,
                              intervalNs / 10);

    AutoWeak weakSelf = self;
    dispatch_source_set_event_handler(source, ^{
        [weakSelf touchPingFile];
    });
    self.writtenExternalPingURLs = [NSMutableSet set];
    self.failedVolumeURLs = [NSMutableSet set];
    dispatch_resume(source);

    self.timer = source;
    self.running = YES;
    os_log(self.log, "%{public}@ started, interval=%.1fs, file=%{public}@", self, self.interval, self.pingFileURL.path);
}

- (void)stop
{
    if(!self.running) { return; }

    Auto source = self.timer;
    Auto pingURL = self.pingFileURL;
    Auto log = self.log;
    // Read in the cancel handler, after the last event on the same queue.
    Auto writtenExternalPingURLs = self.writtenExternalPingURLs;
    Auto token = self.token;

    // `dispatch_source_cancel` is asynchronous — an in-flight timer
    // event can still execute and rewrite the ping file. Defer the
    // removal to the cancel handler, which runs after every pending
    // event has finished, so we never race a write against a delete.
    dispatch_source_set_cancel_handler(source, ^{
        // Only files this timer wrote: a replacement timer (same paths)
        // may already have rewritten them. Best effort for external
        // volumes, which may have been ejected meanwhile.
        KYADriveAliveRemovePing(pingURL.path, token);
        for(NSURL *externalPingURL in writtenExternalPingURLs)
        {
            KYADriveAliveRemovePing(externalPingURL.path, token);
        }
        os_log(log, "drive-alive stop: removed this session's ping files");
    });
    dispatch_source_cancel(source);

    self.timer = nil;
    self.running = NO;
    os_log(self.log, "%{public}@ stopped", self);
}

- (void)touchPingFile
{
    Auto data = [[NSString stringWithFormat:@"%@%@ %f\n", KYADriveAliveContentPrefix, self.token,
                  NSDate.date.timeIntervalSince1970] dataUsingEncoding:NSUTF8StringEncoding];
    NSError *error = nil;
    if(!KYADriveAliveWritePing(self.pingFileURL.path, data, &error))
    {
        os_log_error(self.log, "%{public}@ ping write failed: %{public}@", self, error);
    }

    // Re-enumerated every tick so drives attached mid-session are covered.
    for(NSURL *volume in self.volumesProvider())
    {
        NSURL *externalPingURL = [volume URLByAppendingPathComponent:KYADriveAlivePingFileName isDirectory:NO];
        NSError *volumeError = nil;
        if(KYADriveAliveWritePing(externalPingURL.path, data, &volumeError))
        {
            [self.writtenExternalPingURLs addObject:externalPingURL];
            [self.failedVolumeURLs removeObject:volume];
        }
        else if(![self.failedVolumeURLs containsObject:volume])
        {
            [self.failedVolumeURLs addObject:volume];
            os_log_error(self.log, "%{public}@ ping write to %{public}@ failed: %{public}@", self, volume.path, volumeError);
        }
    }
}

@end
