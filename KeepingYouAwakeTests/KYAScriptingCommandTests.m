//
//  KYAScriptingCommandTests.m
//  KeepingYouAwakeTests
//
//  Issue #85 acceptance criterion: "Cover the AppleScript command
//  `-performDefaultImplementation` paths (mock NSWorkspace.openURL)."
//
//  The three AppleScript commands (activate / deactivate / toggle)
//  emit `keepingyouawake:///…` URLs through a class-level dispatcher
//  seam on `KYAScriptingProxy`. In production the seam falls through
//  to the in-process `-[KYAEventHandler handleEventForURL:]`. These
//  tests install a capturing dispatcher in `setUp`, exercise each
//  command's `-performDefaultImplementation`, and assert both the
//  return value (always `@YES`, per the dispatched-not-completed
//  contract documented in `KYAScripting.m`) and the emitted URL.
//
//  Test-side scaffolding:
//   * Subclasses override `-evaluatedArguments` so we can inject the
//     `Duration` parameter without constructing a real
//     `NSScriptCommandDescription`. This is the cleanest path that
//     avoids the AppleScript runtime entirely.
//   * `tearDown` restores the default dispatcher to keep the static
//     seam from leaking across tests.
//

#import <XCTest/XCTest.h>
#import <KYAApplicationEvents/KYAApplicationEvents.h>
#import <KYAApplicationSupport/KYAApplicationSupport.h>
#import "KYAScripting.h"

#pragma mark - Testable command subclasses

/// Activate-command subclass with an injectable `evaluatedArguments`
/// dictionary. Avoids creating a synthetic `NSScriptCommandDescription`
/// while preserving the production `-performDefaultImplementation`
/// behaviour under test.
@interface KYATestableActivateCommand : KYAActivateScriptCommand
@property (nonatomic, copy, nullable) NSDictionary *injectedArguments;
@end

@implementation KYATestableActivateCommand
- (NSDictionary *)evaluatedArguments { return self.injectedArguments ?: @{}; }
@end

@interface KYATestableDeactivateCommand : KYADeactivateScriptCommand
@end
@implementation KYATestableDeactivateCommand
- (NSDictionary *)evaluatedArguments { return @{}; }
@end

@interface KYATestableToggleCommand : KYAToggleScriptCommand
@end
@implementation KYATestableToggleCommand
- (NSDictionary *)evaluatedArguments { return @{}; }
@end

#pragma mark - Tests

@interface KYAScriptingCommandTests : XCTestCase
@property (nonatomic, nullable) NSURL *capturedURL;
@end

@implementation KYAScriptingCommandTests

- (void)setUp
{
    [super setUp];
    self.capturedURL = nil;
    __weak typeof(self) weakSelf = self;
    [KYAScriptingProxy kya_setURLDispatcherForTesting:^(NSURL *url) {
        // Capture only — never call through to the event handler.
        weakSelf.capturedURL = url;
    }];
}

- (void)tearDown
{
    [KYAScriptingProxy kya_setURLDispatcherForTesting:nil];
    self.capturedURL = nil;
    [super tearDown];
}

#pragma mark - Activate

- (void)testActivateCommandWithFinitePostsActivateURLWithSeconds
{
    KYATestableActivateCommand *cmd = [KYATestableActivateCommand new];
    cmd.injectedArguments = @{ @"Duration": @1800 };

    id result = [cmd performDefaultImplementation];

    XCTAssertEqualObjects(result, @YES,
                          @"activate command must return @YES (dispatched contract)");
    XCTAssertNotNil(self.capturedURL, @"activate must post a URL");
    XCTAssertEqualObjects(self.capturedURL.absoluteString,
                          @"keepingyouawake:///activate?seconds=1800");
}

- (void)testActivateCommandWithZeroPostsIndefiniteURL
{
    KYATestableActivateCommand *cmd = [KYATestableActivateCommand new];
    cmd.injectedArguments = @{ @"Duration": @0 };

    id result = [cmd performDefaultImplementation];

    XCTAssertEqualObjects(result, @YES);
    // SDEF contract: 0 = indefinite, emitted as `seconds=0` (the URL
    // handler interprets that as KYASleepWakeTimeIntervalIndefinite).
    XCTAssertEqualObjects(self.capturedURL.absoluteString,
                          @"keepingyouawake:///activate?seconds=0");
}

- (void)testActivateCommandWithNegativePostsIndefiniteURL
{
    KYATestableActivateCommand *cmd = [KYATestableActivateCommand new];
    cmd.injectedArguments = @{ @"Duration": @(-5) };

    id result = [cmd performDefaultImplementation];

    XCTAssertEqualObjects(result, @YES);
    // Negative values are clamped to 0 (indefinite) before emission.
    XCTAssertEqualObjects(self.capturedURL.absoluteString,
                          @"keepingyouawake:///activate?seconds=0");
}

- (void)testActivateCommandWithoutDurationPostsIndefiniteURL
{
    KYATestableActivateCommand *cmd = [KYATestableActivateCommand new];
    cmd.injectedArguments = @{};

    id result = [cmd performDefaultImplementation];

    XCTAssertEqualObjects(result, @YES);
    // No `Duration` key -> seconds stays at 0 -> indefinite emission.
    // Critically the command must still emit an explicit `seconds=0`
    // (omitting the query item would fall through to the menu default
    // on the receiving side, which is NOT indefinite).
    XCTAssertEqualObjects(self.capturedURL.absoluteString,
                          @"keepingyouawake:///activate?seconds=0");
}

#pragma mark - Deactivate

- (void)testDeactivateCommandPostsDeactivateURL
{
    KYATestableDeactivateCommand *cmd = [KYATestableDeactivateCommand new];

    id result = [cmd performDefaultImplementation];

    XCTAssertEqualObjects(result, @YES);
    XCTAssertEqualObjects(self.capturedURL.absoluteString,
                          @"keepingyouawake:///deactivate");
}

#pragma mark - Toggle

- (void)testToggleCommandPostsToggleURL
{
    KYATestableToggleCommand *cmd = [KYATestableToggleCommand new];

    id result = [cmd performDefaultImplementation];

    XCTAssertEqualObjects(result, @YES);
    XCTAssertEqualObjects(self.capturedURL.absoluteString,
                          @"keepingyouawake:///toggle");
}

#pragma mark - Stale-entry guard

- (void)testEntryStartedInLaunchSecondIsNotStale
{
    // Launch at x.4s; the session started at x.7s but the JSONL only
    // keeps whole seconds, so it reads back as x.0s.
    NSDate *launch = [NSDate dateWithTimeIntervalSinceReferenceDate:1000.4];
    NSDate *startedAt = [NSDate dateWithTimeIntervalSinceReferenceDate:1000.0];

    XCTAssertTrue([KYAScriptingProxy kya_isEntryStartedAt:startedAt fromLaunchAt:launch]);
}

- (void)testEntryStartedAfterLaunchIsNotStale
{
    NSDate *launch = [NSDate dateWithTimeIntervalSinceReferenceDate:1000.4];
    NSDate *startedAt = [NSDate dateWithTimeIntervalSinceReferenceDate:1005.0];

    XCTAssertTrue([KYAScriptingProxy kya_isEntryStartedAt:startedAt fromLaunchAt:launch]);
}

- (void)testEntryStartedBeforeLaunchSecondIsStale
{
    NSDate *launch = [NSDate dateWithTimeIntervalSinceReferenceDate:1000.4];
    NSDate *startedAt = [NSDate dateWithTimeIntervalSinceReferenceDate:999.0];

    XCTAssertFalse([KYAScriptingProxy kya_isEntryStartedAt:startedAt fromLaunchAt:launch]);
}

- (void)testUnknownLaunchDateTrustsEntry
{
    NSDate *startedAt = [NSDate dateWithTimeIntervalSinceReferenceDate:0];

    XCTAssertTrue([KYAScriptingProxy kya_isEntryStartedAt:startedAt fromLaunchAt:nil]);
}

@end

#pragma mark - Proxy state (regression tests for the /code-review findings)

/// Exercises `KYAScriptingProxy` end to end against a temporary
/// activity-log file, with the launch date pinned so the stale-entry
/// guard is deterministic. Each test reproduces a bug that the
/// previous implementation had; see the per-test comments.
@interface KYAScriptingProxyStateTests : XCTestCase
@property (nonatomic) NSURL *logURL;
@property (nonatomic) KYAScriptingProxy *proxy;
@end

@implementation KYAScriptingProxyStateTests

/// 2026-01-01T00:00:00Z — whole seconds, as the JSONL stores it.
static NSString * const KYATestStartedAtString = @"2026-01-01T00:00:00Z";

- (NSDate *)startedAt
{
    return [[NSISO8601DateFormatter new] dateFromString:KYATestStartedAtString];
}

- (void)setUp
{
    [super setUp];
    NSString *name = [NSString stringWithFormat:@"kya-scripting-%@.jsonl", NSUUID.UUID.UUIDString];
    self.logURL = [NSURL fileURLWithPath:[NSTemporaryDirectory() stringByAppendingPathComponent:name]];

    self.proxy = KYAScriptingProxy.sharedProxy;
    [self.proxy kya_resetForTesting];
    [self.proxy kya_setActivityLoggerForTesting:[[KYAActivityLogger alloc] initWithFileURL:self.logURL
                                                                           maximumEntries:100]];
    // Default: launched well before the entry, so it is never stale.
    [self.proxy kya_setLaunchDateForTesting:[self.startedAt dateByAddingTimeInterval:-60]];
}

- (void)tearDown
{
    [self.proxy kya_resetForTesting];
    [KYAScriptingProxy kya_setURLDispatcherForTesting:nil];
    for(NSString *action in @[@"activate", @"deactivate", @"toggle"])
    {
        [KYAEventHandler.defaultHandler removeActionNamed:action];
    }
    [NSFileManager.defaultManager removeItemAtURL:self.logURL error:nil];
    [super tearDown];
}

- (void)writeOpenEntry
{
    NSString *line = [NSString stringWithFormat:
        @"{\"startedAt\":\"%@\",\"source\":\"ac-power\",\"requestedDuration\":-1}\n",
        KYATestStartedAtString];
    XCTAssertTrue([line writeToURL:self.logURL atomically:YES encoding:NSUTF8StringEncoding error:nil]);
}

- (void)writeClosedEntry
{
    NSString *line = [NSString stringWithFormat:
        @"{\"startedAt\":\"%@\",\"endedAt\":\"2026-01-01T00:00:05Z\",\"source\":\"ac-power\","
        @"\"requestedDuration\":-1,\"endedReason\":\"user-cancelled\"}\n",
        KYATestStartedAtString];
    XCTAssertTrue([line writeToURL:self.logURL atomically:YES encoding:NSUTF8StringEncoding error:nil]);
}

- (void)captureDispatchedURLs
{
    [KYAScriptingProxy kya_setURLDispatcherForTesting:^(NSURL *url) {}];
}

#pragma mark Finding 1: session started in the launch second

- (void)testSessionStartedInLaunchSecondIsActive
{
    // Launched at 00:00:00.4; the session started at 00:00:00.7 but is
    // persisted as 00:00:00. A sub-second comparison treated it as
    // stale, so `active` stayed false for the whole session.
    [self.proxy kya_setLaunchDateForTesting:[self.startedAt dateByAddingTimeInterval:0.4]];
    [self writeOpenEntry];

    XCTAssertTrue(self.proxy.isActive);
    XCTAssertEqualObjects(self.proxy.source, @"ac-power");
}

- (void)testSessionFromPreviousLaunchIsStale
{
    // Guard must still reject an entry left open by a prior process.
    [self.proxy kya_setLaunchDateForTesting:[self.startedAt dateByAddingTimeInterval:1.4]];
    [self writeOpenEntry];

    XCTAssertFalse(self.proxy.isActive);
    XCTAssertEqualObjects(self.proxy.source, @"");
    XCTAssertEqual(self.proxy.remainingSeconds, -1);
}

#pragma mark Finding 2: commands must stay in-process

- (void)testCommandsDispatchToInProcessEventHandler
{
    // With no test dispatcher installed the commands used to go through
    // NSWorkspace / Launch Services, which may deliver the URL to a
    // different app registering keepingyouawake:// (or to none at all
    // in a test bundle). They must reach this process's handler.
    NSDictionary<NSString *, XCTestExpectation *> *expectations = @{
        @"activate":   [self expectationWithDescription:@"activate handled in-process"],
        @"deactivate": [self expectationWithDescription:@"deactivate handled in-process"],
        @"toggle":     [self expectationWithDescription:@"toggle handled in-process"],
    };
    __block NSString *activateSeconds = nil;
    [expectations enumerateKeysAndObjectsUsingBlock:^(NSString *action, XCTestExpectation *expectation, BOOL *stop) {
        [KYAEventHandler.defaultHandler registerActionNamed:action block:^(KYAEvent *event) {
            if([action isEqualToString:@"activate"]) { activateSeconds = event.arguments[@"seconds"]; }
            [expectation fulfill];
        }];
    }];

    KYATestableActivateCommand *activate = [KYATestableActivateCommand new];
    activate.injectedArguments = @{ @"Duration": @1800 };
    XCTAssertEqualObjects([activate performDefaultImplementation], @YES);
    XCTAssertEqualObjects([[KYATestableDeactivateCommand new] performDefaultImplementation], @YES);
    XCTAssertEqualObjects([[KYATestableToggleCommand new] performDefaultImplementation], @YES);

    [self waitForExpectationsWithTimeout:2.0 handler:nil];
    XCTAssertEqualObjects(activateSeconds, @"1800");
}

#pragma mark Finding 3: stale cache after a command

- (void)testDeactivateIsVisibleImmediately
{
    [self captureDispatchedURLs];
    [self writeOpenEntry];
    XCTAssertTrue(self.proxy.isActive, @"primes the 1 s cache with the open entry");

    // The app ends the session…
    [self writeClosedEntry];
    [[KYATestableDeactivateCommand new] performDefaultImplementation];

    // …and the next read (well inside the old 1 s TTL) must see it.
    XCTAssertFalse(self.proxy.isActive);
    XCTAssertEqual(self.proxy.remainingSeconds, -1);
    XCTAssertEqualObjects(self.proxy.source, @"");
}

- (void)testReadBetweenDispatchAndActionDoesNotPinOldState
{
    [self captureDispatchedURLs];
    [self writeOpenEntry];
    XCTAssertTrue(self.proxy.isActive);

    // Command dispatched, but the asynchronous action hasn't run yet:
    // a read now legitimately sees the old state…
    [[KYATestableDeactivateCommand new] performDefaultImplementation];
    XCTAssertTrue(self.proxy.isActive);

    // …and once the action lands it must not be masked by that read.
    [self writeClosedEntry];
    XCTAssertFalse(self.proxy.isActive);
}

- (void)testCacheStillServesRepeatedReadsWithoutCommands
{
    // Sanity check that the TTL cache still does its job: with no
    // command in between, a read inside the TTL is served from cache.
    [self writeOpenEntry];
    XCTAssertTrue(self.proxy.isActive);
    [self writeClosedEntry];
    XCTAssertTrue(self.proxy.isActive, @"served from the 1 s cache");
}

@end
