//
//  KYAActivityLogger.m
//  KYAApplicationSupport
//

#import <KYAApplicationSupport/KYAActivityLogger.h>
#import <KYACommon/KYACommon.h>

NSString * const KYAActivityLogSourceUser            = @"user";
NSString * const KYAActivityLogSourceWatchedApp      = @"watched-app";
NSString * const KYAActivityLogSourceWatchedSSID     = @"watched-ssid";
NSString * const KYAActivityLogSourceACPower         = @"ac-power";
NSString * const KYAActivityLogSourceExternalDisplay = @"external-display";
NSString * const KYAActivityLogSourceSchedule        = @"schedule";
NSString * const KYAActivityLogSourceDownload        = @"download";
NSString * const KYAActivityLogSourceAudioOutput     = @"audio-output";
NSString * const KYAActivityLogSourceCPULoad         = @"cpu-load";

NSString * const KYAActivityLogEndedReasonExpired          = @"expired";
NSString * const KYAActivityLogEndedReasonUserCancelled    = @"user-cancelled";
NSString * const KYAActivityLogEndedReasonTriggerCancelled = @"trigger-cancelled";
NSString * const KYAActivityLogEndedReasonAppTerminated    = @"app-terminated";

#pragma mark - Entry

@interface KYAActivityLogEntry ()
@property (copy, nonatomic, readwrite) NSDate *startedAt;
@property (copy, nonatomic, readwrite, nullable) NSDate *endedAt;
@property (copy, nonatomic, readwrite) NSString *source;
@property (nonatomic, readwrite) NSTimeInterval requestedDuration;
@property (copy, nonatomic, readwrite, nullable) NSString *endedReason;
@end

@implementation KYAActivityLogEntry

- (instancetype)initWithStartedAt:(NSDate *)startedAt
                          endedAt:(NSDate *)endedAt
                           source:(NSString *)source
                requestedDuration:(NSTimeInterval)requestedDuration
                      endedReason:(NSString *)endedReason
{
    self = [super init];
    if(self)
    {
        _startedAt = [startedAt copy];
        _endedAt = [endedAt copy];
        _source = [source copy];
        _requestedDuration = requestedDuration;
        _endedReason = [endedReason copy];
    }
    return self;
}

- (NSDictionary *)dictionaryRepresentation
{
    Auto formatter = [NSISO8601DateFormatter new];
    NSMutableDictionary *dict = [NSMutableDictionary dictionary];
    dict[@"startedAt"] = [formatter stringFromDate:self.startedAt];
    if(self.endedAt != nil)
    {
        dict[@"endedAt"] = [formatter stringFromDate:self.endedAt];
    }
    dict[@"source"] = self.source;
    dict[@"requestedDuration"] = @(self.requestedDuration);
    if(self.endedReason != nil)
    {
        dict[@"endedReason"] = self.endedReason;
    }
    return [dict copy];
}

+ (nullable KYAActivityLogEntry *)entryFromDictionary:(NSDictionary *)dict
{
    if(![dict isKindOfClass:NSDictionary.class]) { return nil; }
    Auto formatter = [NSISO8601DateFormatter new];

    NSString *startedAtString = dict[@"startedAt"];
    if(![startedAtString isKindOfClass:NSString.class]) { return nil; }
    NSDate *startedAt = [formatter dateFromString:startedAtString];
    if(startedAt == nil) { return nil; }

    NSDate *endedAt = nil;
    NSString *endedAtString = dict[@"endedAt"];
    if([endedAtString isKindOfClass:NSString.class])
    {
        endedAt = [formatter dateFromString:endedAtString];
    }

    NSString *source = dict[@"source"];
    if(![source isKindOfClass:NSString.class]) { source = KYAActivityLogSourceUser; }

    NSTimeInterval requested = -1;
    NSNumber *requestedNumber = dict[@"requestedDuration"];
    if([requestedNumber isKindOfClass:NSNumber.class])
    {
        requested = requestedNumber.doubleValue;
    }

    NSString *reason = dict[@"endedReason"];
    if(![reason isKindOfClass:NSString.class]) { reason = nil; }

    return [[KYAActivityLogEntry alloc] initWithStartedAt:startedAt
                                                  endedAt:endedAt
                                                   source:source
                                        requestedDuration:requested
                                              endedReason:reason];
}

@end

#pragma mark - Logger

@interface KYAActivityLogger ()
@property (copy, nonatomic, readwrite) NSURL *fileURL;
@property (nonatomic, readwrite) NSUInteger maximumEntries;
@property (nonatomic) dispatch_queue_t writeQueue;
/// Index into the on-disk file pointing at the currently open entry,
/// so -recordActivationEnded knows which line to edit. -1 when no
/// session is open.
@property (nonatomic) NSInteger openEntryLineNumber;
/// Set when -closeDanglingEntriesWithReason: couldn't write its repair; the
/// next append retries it so dangling entries don't stay open on disk.
@property (copy, nonatomic, nullable) NSString *pendingDanglingRepairReason;
/// End of the open entry that couldn't be written; the next append
/// records it instead of treating the entry as an unrecorded expiry.
@property (copy, nonatomic, nullable) NSDate *pendingEndedAt;
@property (copy, nonatomic, nullable) NSString *pendingEndedReason;
@end

@implementation KYAActivityLogger

+ (instancetype)sharedLogger
{
    static dispatch_once_t once;
    static KYAActivityLogger *sharedInstance;
    dispatch_once(&once, ^{
        Auto fileManager = NSFileManager.defaultManager;
        NSURL *appSupport = [[fileManager URLsForDirectory:NSApplicationSupportDirectory
                                                  inDomains:NSUserDomainMask] firstObject];
        NSURL *kyaDir = [appSupport URLByAppendingPathComponent:@"KeepingYouAwake" isDirectory:YES];
        [fileManager createDirectoryAtURL:kyaDir
              withIntermediateDirectories:YES
                               attributes:nil
                                    error:nil];
        NSURL *url = [kyaDir URLByAppendingPathComponent:@"activity.jsonl"];
        sharedInstance = [[self alloc] initWithFileURL:url maximumEntries:1000];
    });
    return sharedInstance;
}

- (instancetype)initWithFileURL:(NSURL *)fileURL maximumEntries:(NSUInteger)maxEntries
{
    self = [super init];
    if(self)
    {
        _fileURL = [fileURL copy];
        _maximumEntries = maxEntries;
        _writeQueue = dispatch_queue_create("info.marcel-dierkes.KeepingYouAwake.activitylog",
                                            DISPATCH_QUEUE_SERIAL);
        _openEntryLineNumber = -1;
    }
    return self;
}

#pragma mark - Public API

- (void)recordActivationStartedFromSource:(NSString *)source
                        requestedDuration:(NSTimeInterval)requestedDuration
{
    NSDate *now = [NSDate date];
    dispatch_async(self.writeQueue, ^{
        Auto entry = [[KYAActivityLogEntry alloc] initWithStartedAt:now
                                                            endedAt:nil
                                                             source:source ?: KYAActivityLogSourceUser
                                                  requestedDuration:requestedDuration
                                                        endedReason:nil];
        [self appendEntry:entry];
    });
}

- (void)recordActivationEnded
{
    [self recordActivationEndedWithReason:KYAActivityLogEndedReasonUserCancelled];
}

- (void)recordActivationEndedWithReason:(NSString *)reason
{
    NSDate *now = [NSDate date];
    NSString *capturedReason = [reason copy] ?: KYAActivityLogEndedReasonUserCancelled;
    dispatch_async(self.writeQueue, ^{
        [self closeOpenEntryWithEndedAt:now reason:capturedReason];
    });
}

- (void)recordActivationEndedSynchronouslyWithReason:(NSString *)reason
{
    NSDate *now = [NSDate date];
    NSString *capturedReason = [reason copy] ?: KYAActivityLogEndedReasonUserCancelled;
    dispatch_sync(self.writeQueue, ^{
        [self closeOpenEntryWithEndedAt:now reason:capturedReason];
    });
}

- (void)closeDanglingEntriesWithReason:(NSString *)reason
{
    NSDate *now = [NSDate date];
    NSString *capturedReason = [reason copy] ?: KYAActivityLogEndedReasonAppTerminated;
    dispatch_sync(self.writeQueue, ^{
        NSMutableArray<NSDictionary *> *dicts = [[self readAllDictionariesFromFile] mutableCopy];
        BOOL changed = [self closeDanglingDictionaries:dicts endedAt:now reason:capturedReason];
        // Retry on the next append if the repair couldn't be persisted.
        self.pendingDanglingRepairReason = (changed && ![self writeAllDictionaries:dicts]) ? capturedReason : nil;
        self.openEntryLineNumber = -1;
    });
}

- (NSArray<KYAActivityLogEntry *> *)recentEntriesWithLimit:(NSUInteger)count
{
    __block NSArray<KYAActivityLogEntry *> *result = @[];
    dispatch_sync(self.writeQueue, ^{
        NSArray<NSDictionary *> *raw = [self readAllDictionariesFromFile];
        NSMutableArray<KYAActivityLogEntry *> *entries = [NSMutableArray array];
        for(NSDictionary *dict in raw)
        {
            Auto entry = [KYAActivityLogEntry entryFromDictionary:dict];
            if(entry != nil) { [entries addObject:entry]; }
        }
        if(entries.count > count)
        {
            entries = [[entries subarrayWithRange:NSMakeRange(entries.count - count, count)] mutableCopy];
        }
        result = [[entries reverseObjectEnumerator] allObjects];
    });
    return result;
}

#pragma mark - Internal IO (always called on writeQueue)

- (NSArray<NSDictionary *> *)readAllDictionariesFromFile
{
    NSError *error = nil;
    NSString *contents = [NSString stringWithContentsOfURL:self.fileURL
                                                  encoding:NSUTF8StringEncoding
                                                     error:&error];
    if(contents == nil) { return @[]; }
    NSMutableArray<NSDictionary *> *out = [NSMutableArray array];
    [contents enumerateLinesUsingBlock:^(NSString * _Nonnull line, BOOL * _Nonnull stop) {
        if(line.length == 0) { return; }
        NSData *data = [line dataUsingEncoding:NSUTF8StringEncoding];
        id parsed = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
        if([parsed isKindOfClass:NSDictionary.class])
        {
            [out addObject:parsed];
        }
    }];
    return [out copy];
}

- (BOOL)writeAllDictionaries:(NSArray<NSDictionary *> *)dicts
{
    NSMutableString *output = [NSMutableString string];
    for(NSDictionary *dict in dicts)
    {
        NSData *data = [NSJSONSerialization dataWithJSONObject:dict options:0 error:nil];
        if(data == nil) { continue; }
        NSString *line = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
        if(line == nil) { continue; }
        [output appendString:line];
        [output appendString:@"\n"];
    }
    NSError *error = nil;
    return [output writeToURL:self.fileURL
                   atomically:YES
                     encoding:NSUTF8StringEncoding
                        error:&error];
}

/// Sets `endedAt` / `endedReason` on every entry without `endedAt`.
/// Returns YES if any entry was changed. Always called on writeQueue.
- (BOOL)closeDanglingDictionaries:(NSMutableArray<NSDictionary *> *)dicts
                          endedAt:(NSDate *)endedAt
                           reason:(NSString *)reason
{
    Auto formatter = [NSISO8601DateFormatter new];
    BOOL changed = NO;
    for(NSUInteger i = 0; i < dicts.count; i++)
    {
        if(dicts[i][@"endedAt"] != nil) { continue; }
        NSMutableDictionary *dangling = [dicts[i] mutableCopy];
        dangling[@"endedAt"] = [formatter stringFromDate:endedAt];
        if(reason.length > 0) { dangling[@"endedReason"] = reason; }
        dicts[i] = [dangling copy];
        changed = YES;
    }
    return changed;
}

- (void)appendEntry:(KYAActivityLogEntry *)entry
{
    NSMutableArray<NSDictionary *> *dicts = [[self readAllDictionariesFromFile] mutableCopy];
    Auto pendingRepairReason = self.pendingDanglingRepairReason;
    if(pendingRepairReason != nil)
    {
        [self closeDanglingDictionaries:dicts endedAt:entry.startedAt reason:pendingRepairReason];
    }
    // A session still open here ended without being recorded: either its
    // end write failed (pendingEnded*), or its caffeinate exited at the
    // fire date and a new session started before the main queue delivered
    // the expiry. Close it so it isn't orphaned (a late expiry then sees a
    // newer session and skips).
    NSInteger openLine = self.openEntryLineNumber;
    if(openLine >= 0 && (NSUInteger)openLine < dicts.count && dicts[(NSUInteger)openLine][@"endedAt"] == nil)
    {
        NSMutableDictionary *open = [dicts[(NSUInteger)openLine] mutableCopy];
        open[@"endedAt"] = [[NSISO8601DateFormatter new] stringFromDate:self.pendingEndedAt ?: entry.startedAt];
        open[@"endedReason"] = self.pendingEndedReason ?: KYAActivityLogEndedReasonExpired;
        dicts[(NSUInteger)openLine] = [open copy];
    }
    [dicts addObject:[entry dictionaryRepresentation]];

    // Soft cap: drop oldest entries first.
    while(dicts.count > self.maximumEntries)
    {
        [dicts removeObjectAtIndex:0];
    }

    if([self writeAllDictionaries:dicts])
    {
        self.openEntryLineNumber = (NSInteger)dicts.count - 1;
        self.pendingDanglingRepairReason = nil;
        self.pendingEndedAt = nil;
        self.pendingEndedReason = nil;
    }
}

- (void)closeOpenEntryWithEndedAt:(NSDate *)endedAt reason:(NSString *)reason
{
    if(self.openEntryLineNumber < 0) { return; }

    NSMutableArray<NSDictionary *> *dicts = [[self readAllDictionariesFromFile] mutableCopy];
    if((NSUInteger)self.openEntryLineNumber >= dicts.count)
    {
        // The capped trim removed our open entry — nothing to close.
        self.openEntryLineNumber = -1;
        return;
    }
    NSMutableDictionary *open = [dicts[(NSUInteger)self.openEntryLineNumber] mutableCopy];
    Auto formatter = [NSISO8601DateFormatter new];
    open[@"endedAt"] = [formatter stringFromDate:endedAt];
    if(reason.length > 0) { open[@"endedReason"] = reason; }
    dicts[(NSUInteger)self.openEntryLineNumber] = [open copy];

    // Mirror -appendEntry:'s pattern — only forget the open-entry
    // pointer if the write actually persisted. Otherwise the entry
    // stays "open" and the next attempt can retry rather than
    // silently orphaning the row forever.
    if([self writeAllDictionaries:dicts])
    {
        self.openEntryLineNumber = -1;
        self.pendingEndedAt = nil;
        self.pendingEndedReason = nil;
    }
    else
    {
        self.pendingEndedAt = endedAt;
        self.pendingEndedReason = reason;
    }
}

@end
