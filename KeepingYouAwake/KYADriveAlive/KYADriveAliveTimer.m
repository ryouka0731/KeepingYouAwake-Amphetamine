//
//  KYADriveAliveTimer.m
//  KeepingYouAwake
//

#import "KYADriveAliveTimer.h"
#import <KYACommon/KYACommon.h>

NSString * const KYADriveAlivePingFileName = @".KeepingYouAwake-DriveAlive";

@interface KYADriveAliveTimer ()
@property (nonatomic, readwrite, getter=isRunning) BOOL running;
@property (nonatomic, nullable) dispatch_source_t timer;
@property (nonatomic, copy, readonly) NSURL *pingFileURL;
@property (nonatomic) os_log_t log;
@property (nonatomic, copy) KYADriveAliveVolumesProvider volumesProvider;
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
    }
    return self;
}

+ (NSArray<NSURL *> *)externalWritableVolumeURLs
{
    NSArray<NSURLResourceKey> *keys = @[NSURLVolumeIsInternalKey, NSURLVolumeIsLocalKey,
                                        NSURLVolumeIsReadOnlyKey, NSURLVolumeIsRootFileSystemKey];
    Auto volumes = [NSFileManager.defaultManager mountedVolumeURLsIncludingResourceValuesForKeys:keys
                                                                                        options:NSVolumeEnumerationSkipHiddenVolumes];
    Auto result = [NSMutableArray<NSURL *> array];
    for(NSURL *volume in volumes)
    {
        NSDictionary<NSURLResourceKey, id> *values = [volume resourceValuesForKeys:keys error:nil];
        if([values[NSURLVolumeIsRootFileSystemKey] boolValue]) { continue; }
        if([values[NSURLVolumeIsLocalKey] boolValue] == NO) { continue; }   // network shares
        if([values[NSURLVolumeIsReadOnlyKey] boolValue]) { continue; }
        // Unknown counts as internal: only touch drives known to be external.
        NSNumber *isInternal = values[NSURLVolumeIsInternalKey];
        if(isInternal == nil || isInternal.boolValue) { continue; }
        [result addObject:volume];
    }
    return [result copy];
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

    Auto queue = dispatch_queue_create("info.marcel-dierkes.KeepingYouAwake.drive-alive",
                                        DISPATCH_QUEUE_SERIAL);
    Auto source = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, queue);
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

    // `dispatch_source_cancel` is asynchronous — an in-flight timer
    // event can still execute and rewrite the ping file. Defer the
    // removal to the cancel handler, which runs after every pending
    // event has finished, so we never race a write against a delete.
    dispatch_source_set_cancel_handler(source, ^{
        NSError *removalError = nil;
        [NSFileManager.defaultManager removeItemAtURL:pingURL error:&removalError];
        if(removalError != nil && removalError.code != NSFileNoSuchFileError)
        {
            os_log_error(log, "drive-alive stop: failed to remove ping file: %{public}@", removalError);
        }
        for(NSURL *externalPingURL in writtenExternalPingURLs)
        {
            // Best effort: the volume may have been ejected meanwhile.
            [NSFileManager.defaultManager removeItemAtURL:externalPingURL error:nil];
        }
    });
    dispatch_source_cancel(source);

    self.timer = nil;
    self.running = NO;
    os_log(self.log, "%{public}@ stopped", self);
}

- (void)touchPingFile
{
    Auto data = [[NSString stringWithFormat:@"keepingyouawake %f\n",
                  NSDate.date.timeIntervalSince1970] dataUsingEncoding:NSUTF8StringEncoding];
    NSError *error = nil;
    if(![data writeToURL:self.pingFileURL options:NSDataWritingAtomic error:&error])
    {
        os_log_error(self.log, "%{public}@ ping write failed: %{public}@", self, error);
    }

    // Re-enumerated every tick so drives attached mid-session are covered.
    for(NSURL *volume in self.volumesProvider())
    {
        NSURL *externalPingURL = [volume URLByAppendingPathComponent:KYADriveAlivePingFileName isDirectory:NO];
        // Not atomic: an in-place write is real I/O on that drive, and
        // there is no temporary file to leave behind if it is ejected.
        NSError *volumeError = nil;
        if([data writeToURL:externalPingURL options:0 error:&volumeError])
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
