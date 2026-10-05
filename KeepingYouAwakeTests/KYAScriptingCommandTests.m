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
