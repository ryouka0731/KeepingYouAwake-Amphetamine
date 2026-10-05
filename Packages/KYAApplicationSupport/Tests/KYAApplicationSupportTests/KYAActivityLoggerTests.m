//
//  KYAActivityLoggerTests.m
//  KYAApplicationSupport
//

#import <XCTest/XCTest.h>
#import <KYACommon/KYACommon.h>
#import <KYAApplicationSupport/KYAApplicationSupport.h>

@interface KYAActivityLoggerTests : XCTestCase
@property (nonatomic) NSURL *tmpFile;
@property (nonatomic) KYAActivityLogger *logger;
@end

@implementation KYAActivityLoggerTests

- (void)setUp
{
    [super setUp];
    Auto fm = NSFileManager.defaultManager;
    NSURL *dir = [NSURL fileURLWithPath:NSTemporaryDirectory()];
    NSString *name = [NSString stringWithFormat:@"kya-activity-%@.jsonl", [NSUUID UUID].UUIDString];
    self.tmpFile = [dir URLByAppendingPathComponent:name];
    [fm removeItemAtURL:self.tmpFile error:nil];
    self.logger = [[KYAActivityLogger alloc] initWithFileURL:self.tmpFile maximumEntries:5];
}

- (void)tearDown
{
    [NSFileManager.defaultManager removeItemAtURL:self.tmpFile error:nil];
    [super tearDown];
}

- (void)flush
{
    // The logger uses an internal serial queue. -recentEntriesWithLimit:
    // is dispatch_sync on the same queue, so calling it forces all
    // earlier async writes to drain.
    [self.logger recentEntriesWithLimit:1];
}

- (void)testRecordsStartAndEndForSingleSession
{
    [self.logger recordActivationStartedFromSource:KYAActivityLogSourceUser
                                  requestedDuration:1800];
    [self.logger recordActivationEnded];
    [self flush];

    NSArray<KYAActivityLogEntry *> *entries = [self.logger recentEntriesWithLimit:10];
    XCTAssertEqual(entries.count, 1);
    KYAActivityLogEntry *entry = entries.firstObject;
    XCTAssertEqualObjects(entry.source, KYAActivityLogSourceUser);
    XCTAssertEqual(entry.requestedDuration, 1800);
    XCTAssertNotNil(entry.startedAt);
    XCTAssertNotNil(entry.endedAt);
    XCTAssertGreaterThanOrEqual([entry.endedAt timeIntervalSinceDate:entry.startedAt], 0);
}

- (void)testIndefiniteSessionStoresMinusOne
{
    [self.logger recordActivationStartedFromSource:KYAActivityLogSourceACPower
                                  requestedDuration:-1];
    [self.logger recordActivationEnded];
    [self flush];
    NSArray<KYAActivityLogEntry *> *entries = [self.logger recentEntriesWithLimit:10];
    XCTAssertEqual(entries.firstObject.requestedDuration, -1);
    XCTAssertEqualObjects(entries.firstObject.source, KYAActivityLogSourceACPower);
}

- (void)testEndWithoutStartIsNoOp
{
    [self.logger recordActivationEnded];
    [self flush];
    XCTAssertEqual([self.logger recentEntriesWithLimit:10].count, 0);
}

- (void)testCapsAtMaximumEntries
{
    // maximumEntries = 5 from setUp.
    for(NSUInteger i = 0; i < 8; i++)
    {
        NSString *src = [NSString stringWithFormat:@"src-%lu", (unsigned long)i];
        [self.logger recordActivationStartedFromSource:src requestedDuration:i];
        [self.logger recordActivationEnded];
    }
    [self flush];
    NSArray<KYAActivityLogEntry *> *entries = [self.logger recentEntriesWithLimit:100];
    XCTAssertEqual(entries.count, 5, @"capped to maximumEntries=5");
    // recentEntriesWithLimit returns newest-first
    XCTAssertEqualObjects(entries.firstObject.source, @"src-7");
    XCTAssertEqualObjects(entries.lastObject.source, @"src-3");
}

- (void)testRecentEntriesLimitNarrowsResult
{
    for(NSUInteger i = 0; i < 4; i++)
    {
        NSString *src = [NSString stringWithFormat:@"src-%lu", (unsigned long)i];
        [self.logger recordActivationStartedFromSource:src requestedDuration:0];
        [self.logger recordActivationEnded];
    }
    [self flush];
    NSArray<KYAActivityLogEntry *> *entries = [self.logger recentEntriesWithLimit:2];
    XCTAssertEqual(entries.count, 2);
    XCTAssertEqualObjects(entries.firstObject.source, @"src-3");
    XCTAssertEqualObjects(entries.lastObject.source, @"src-2");
}

- (void)testCorruptedLineIsSkipped
{
    [self.logger recordActivationStartedFromSource:KYAActivityLogSourceUser
                                  requestedDuration:0];
    [self.logger recordActivationEnded];
    [self flush];

    // Manually inject a junk line — the next read should silently skip it.
    NSString *contents = [NSString stringWithContentsOfURL:self.tmpFile
                                                  encoding:NSUTF8StringEncoding
                                                     error:nil];
    contents = [contents stringByAppendingString:@"not-json\n"];
    [contents writeToURL:self.tmpFile atomically:YES encoding:NSUTF8StringEncoding error:nil];

    NSArray<KYAActivityLogEntry *> *entries = [self.logger recentEntriesWithLimit:10];
    XCTAssertEqual(entries.count, 1, @"junk line skipped, valid entry still readable");
}

- (void)testNilSourceFallsBackToUser
{
    [self.logger recordActivationStartedFromSource:nil requestedDuration:0];
    [self.logger recordActivationEnded];
    [self flush];
    XCTAssertEqualObjects([self.logger recentEntriesWithLimit:10].firstObject.source,
                          KYAActivityLogSourceUser);
}

#pragma mark - endedReason

- (void)testDefaultEndedReasonIsUserCancelled
{
    [self.logger recordActivationStartedFromSource:KYAActivityLogSourceUser requestedDuration:0];
    [self.logger recordActivationEnded];   // no-arg variant
    [self flush];
    XCTAssertEqualObjects([self.logger recentEntriesWithLimit:10].firstObject.endedReason,
                          KYAActivityLogEndedReasonUserCancelled);
}

- (void)testExpiredReasonIsRecorded
{
    [self.logger recordActivationStartedFromSource:KYAActivityLogSourceUser requestedDuration:0];
    [self.logger recordActivationEndedWithReason:KYAActivityLogEndedReasonExpired];
    [self flush];
    XCTAssertEqualObjects([self.logger recentEntriesWithLimit:10].firstObject.endedReason,
                          KYAActivityLogEndedReasonExpired);
}

- (void)testTriggerCancelledReasonIsRecorded
{
    [self.logger recordActivationStartedFromSource:KYAActivityLogSourceACPower requestedDuration:-1];
    [self.logger recordActivationEndedWithReason:KYAActivityLogEndedReasonTriggerCancelled];
    [self flush];
    KYAActivityLogEntry *entry = [self.logger recentEntriesWithLimit:10].firstObject;
    XCTAssertEqualObjects(entry.endedReason, KYAActivityLogEndedReasonTriggerCancelled);
    XCTAssertEqualObjects(entry.source, KYAActivityLogSourceACPower);
}

- (void)testOpenEntryHasNilEndedReason
{
    [self.logger recordActivationStartedFromSource:KYAActivityLogSourceUser requestedDuration:0];
    [self flush];
    KYAActivityLogEntry *entry = [self.logger recentEntriesWithLimit:10].firstObject;
    XCTAssertNotNil(entry);
    XCTAssertNil(entry.endedAt);
    XCTAssertNil(entry.endedReason);
}

#pragma mark - App termination / dangling entries

- (void)testSynchronousEndClosesOpenEntryWithoutFlush
{
    [self.logger recordActivationStartedFromSource:KYAActivityLogSourceACPower
                                  requestedDuration:-1];
    [self.logger recordActivationEndedSynchronouslyWithReason:KYAActivityLogEndedReasonAppTerminated];

    // Read through a fresh logger: the write must already be on disk.
    Auto reader = [[KYAActivityLogger alloc] initWithFileURL:self.tmpFile maximumEntries:5];
    Auto entry = [reader recentEntriesWithLimit:1].firstObject;
    XCTAssertNotNil(entry.endedAt);
    XCTAssertEqualObjects(entry.endedReason, KYAActivityLogEndedReasonAppTerminated);
}

- (void)testCloseDanglingEntriesClosesEntriesLeftOpenByPreviousProcess
{
    // A previous process opened a session and died without closing it.
    [self.logger recordActivationStartedFromSource:KYAActivityLogSourceUser
                                  requestedDuration:-1];
    [self flush];

    Auto relaunched = [[KYAActivityLogger alloc] initWithFileURL:self.tmpFile maximumEntries:5];
    [relaunched closeDanglingEntriesWithReason:KYAActivityLogEndedReasonAppTerminated];

    Auto entries = [relaunched recentEntriesWithLimit:10];
    XCTAssertEqual(entries.count, 1);
    XCTAssertNotNil(entries.firstObject.endedAt);
    XCTAssertEqualObjects(entries.firstObject.endedReason, KYAActivityLogEndedReasonAppTerminated);
}

- (void)testCloseDanglingEntriesKeepsClosedEntriesAndNewSessionsWork
{
    [self.logger recordActivationStartedFromSource:KYAActivityLogSourceUser
                                  requestedDuration:60];
    [self.logger recordActivationEndedWithReason:KYAActivityLogEndedReasonExpired];
    [self flush];

    Auto relaunched = [[KYAActivityLogger alloc] initWithFileURL:self.tmpFile maximumEntries:5];
    [relaunched closeDanglingEntriesWithReason:KYAActivityLogEndedReasonAppTerminated];
    [relaunched recordActivationStartedFromSource:KYAActivityLogSourceUser
                               requestedDuration:-1];
    [relaunched recordActivationEnded];

    Auto entries = [relaunched recentEntriesWithLimit:10];
    XCTAssertEqual(entries.count, 2);
    XCTAssertEqualObjects(entries[1].endedReason, KYAActivityLogEndedReasonExpired,
                          @"an already-closed entry keeps its reason");
    XCTAssertEqualObjects(entries[0].endedReason, KYAActivityLogEndedReasonUserCancelled);
}

- (void)testFailedDanglingRepairIsRetriedOnNextAppend
{
    [self.logger recordActivationStartedFromSource:KYAActivityLogSourceUser
                                  requestedDuration:-1];
    [self flush];

    // Make the repair's atomic write fail: a read-only parent directory
    // blocks creating the temporary file.
    NSURL *dir = self.tmpFile.URLByDeletingLastPathComponent;
    NSString *isolated = [NSString stringWithFormat:@"kya-ro-%@", [NSUUID UUID].UUIDString];
    NSURL *roDir = [dir URLByAppendingPathComponent:isolated isDirectory:YES];
    Auto fm = NSFileManager.defaultManager;
    XCTAssertTrue([fm createDirectoryAtURL:roDir withIntermediateDirectories:YES attributes:nil error:nil]);
    NSURL *roFile = [roDir URLByAppendingPathComponent:@"activity.jsonl"];
    XCTAssertTrue([fm copyItemAtURL:self.tmpFile toURL:roFile error:nil]);
    XCTAssertTrue([fm setAttributes:@{NSFilePosixPermissions: @0555} ofItemAtPath:roDir.path error:nil]);

    Auto relaunched = [[KYAActivityLogger alloc] initWithFileURL:roFile maximumEntries:5];
    [relaunched closeDanglingEntriesWithReason:KYAActivityLogEndedReasonAppTerminated];
    XCTAssertNil([relaunched recentEntriesWithLimit:1].firstObject.endedAt, @"write failed, still open on disk");

    // Writable again: the next session's append also persists the repair.
    XCTAssertTrue([fm setAttributes:@{NSFilePosixPermissions: @0755} ofItemAtPath:roDir.path error:nil]);
    [relaunched recordActivationStartedFromSource:KYAActivityLogSourceUser requestedDuration:-1];

    Auto entries = [relaunched recentEntriesWithLimit:10];
    XCTAssertEqual(entries.count, 2);
    XCTAssertNil(entries[0].endedAt, @"the new session is open");
    XCTAssertEqualObjects(entries[1].endedReason, KYAActivityLogEndedReasonAppTerminated);
    [fm removeItemAtURL:roDir error:nil];
}

- (void)testStartingWhileAnEntryIsOpenClosesItAsExpired
{
    // Natural expiry raced with a new activation: the expiry's log write
    // hasn't happened when the next session starts.
    [self.logger recordActivationStartedFromSource:KYAActivityLogSourceUser requestedDuration:60];
    [self.logger recordActivationStartedFromSource:KYAActivityLogSourceACPower requestedDuration:-1];
    [self flush];

    Auto entries = [self.logger recentEntriesWithLimit:10];
    XCTAssertEqual(entries.count, 2);
    XCTAssertNil(entries[0].endedAt, @"the new session is open");
    XCTAssertNotNil(entries[1].endedAt);
    XCTAssertEqualObjects(entries[1].endedReason, KYAActivityLogEndedReasonExpired);
}

- (void)testFailedEndWriteKeepsItsReasonOnNextAppend
{
    Auto fm = NSFileManager.defaultManager;
    NSString *isolated = [NSString stringWithFormat:@"kya-end-%@", [NSUUID UUID].UUIDString];
    NSURL *dir = [self.tmpFile.URLByDeletingLastPathComponent URLByAppendingPathComponent:isolated isDirectory:YES];
    XCTAssertTrue([fm createDirectoryAtURL:dir withIntermediateDirectories:YES attributes:nil error:nil]);
    Auto logger = [[KYAActivityLogger alloc] initWithFileURL:[dir URLByAppendingPathComponent:@"activity.jsonl"]
                                              maximumEntries:5];

    [logger recordActivationStartedFromSource:KYAActivityLogSourceUser requestedDuration:-1];
    [logger recentEntriesWithLimit:1];
    // The user ends the session, but the write fails.
    XCTAssertTrue([fm setAttributes:@{NSFilePosixPermissions: @0555} ofItemAtPath:dir.path error:nil]);
    [logger recordActivationEndedWithReason:KYAActivityLogEndedReasonUserCancelled];
    [logger recentEntriesWithLimit:1];
    XCTAssertTrue([fm setAttributes:@{NSFilePosixPermissions: @0755} ofItemAtPath:dir.path error:nil]);

    [logger recordActivationStartedFromSource:KYAActivityLogSourceACPower requestedDuration:-1];
    Auto entries = [logger recentEntriesWithLimit:10];
    XCTAssertEqual(entries.count, 2);
    XCTAssertEqualObjects(entries[1].endedReason, KYAActivityLogEndedReasonUserCancelled,
                          @"a failed user end must not be relabelled as expired");
    [fm removeItemAtURL:dir error:nil];
}

@end
