//
//  KYASleepWakeTimerTests.m
//  KYASleepWakeTimerTests
//
//  Created by Claude on 13.05.26.
//

// Callback-timing assertions (-completion runs with cancelled==YES; delegate didDeactivate fires on invalidate)
// are not covered here — they depend on caffeinate subprocess signal timing and race headlessly. They belong in
// the main-target XCTest slice (#85 goal 1), which can drive the timer through KYAAppController's integration paths.

#import <XCTest/XCTest.h>
#import <KYACommon/KYACommon.h>
#import <KYASleepWakeTimer/KYASleepWakeTimer.h>

@interface KYASleepWakeTimerTestDelegate : NSObject <KYASleepWakeTimerDelegate>
@property (nonatomic) NSTimeInterval lastWillActivateInterval;
@property (nonatomic) BOOL didReceiveWillActivate;
@end

@implementation KYASleepWakeTimerTestDelegate

- (instancetype)init
{
    self = [super init];
    if(self)
    {
        _lastWillActivateInterval = -1.0;
    }
    return self;
}

- (void)sleepWakeTimer:(KYASleepWakeTimer *)sleepWakeTimer willActivateWithTimeInterval:(NSTimeInterval)timeInterval
{
    self.didReceiveWillActivate = YES;
    self.lastWillActivateInterval = timeInterval;
}

@end

#pragma mark -

@interface KYASleepWakeTimerTests : XCTestCase
@property (nonatomic) KYASleepWakeTimer *timer;
@end

@implementation KYASleepWakeTimerTests

- (void)setUp
{
    [super setUp];

    self.timer = [KYASleepWakeTimer new];
}

- (void)tearDown
{
    [self.timer invalidate];
    self.timer = nil;

    [super tearDown];
}

#pragma mark - Constant

- (void)testIndefiniteConstantIsZero
{
    XCTAssertEqual(KYASleepWakeTimeIntervalIndefinite, 0.0);
}

#pragma mark - Initial state

- (void)testFreshTimerIsNotScheduled
{
    Auto timer = self.timer;
    XCTAssertFalse(timer.isScheduled);
    XCTAssertNil(timer.fireDate);
    XCTAssertEqual(timer.scheduledTimeInterval, KYASleepWakeTimeIntervalIndefinite);
}

#pragma mark - Scheduling

- (void)testScheduleSetsFireDateAndIntervalForFiniteInterval
{
    Auto timer = self.timer;
    NSTimeInterval interval = 600.0;
    Auto before = NSDate.date;

    [timer scheduleWithTimeInterval:interval completion:nil];

    XCTAssertEqual(timer.scheduledTimeInterval, interval);
    XCTAssertNotNil(timer.fireDate);
    // The fire date should be roughly `interval` seconds out from now.
    NSTimeInterval delta = [timer.fireDate timeIntervalSinceDate:before];
    XCTAssertEqualWithAccuracy(delta, interval, 5.0);
}

- (void)testScheduleIndefiniteHasNilFireDate
{
    Auto timer = self.timer;

    [timer scheduleWithTimeInterval:KYASleepWakeTimeIntervalIndefinite completion:nil];

    XCTAssertNil(timer.fireDate);
    XCTAssertEqual(timer.scheduledTimeInterval, KYASleepWakeTimeIntervalIndefinite);
}

#pragma mark - Invalidation

- (void)testInvalidateClearsScheduledState
{
    Auto timer = self.timer;
    [timer scheduleWithTimeInterval:600.0 completion:nil];

    [timer invalidate];

    XCTAssertNil(timer.fireDate);
    XCTAssertEqual(timer.scheduledTimeInterval, KYASleepWakeTimeIntervalIndefinite);
    XCTAssertFalse(timer.isScheduled);
}

- (void)testDoubleInvalidateIsSafe
{
    Auto timer = self.timer;
    [timer scheduleWithTimeInterval:600.0 completion:nil];

    XCTAssertNoThrow([timer invalidate]);
    XCTAssertNoThrow([timer invalidate]);
    XCTAssertNoThrow([timer invalidate]);
    XCTAssertNil(timer.fireDate);
}

- (void)testInvalidateWithoutSchedulingIsSafe
{
    Auto timer = self.timer;
    XCTAssertNoThrow([timer invalidate]);
    XCTAssertFalse(timer.isScheduled);
}

#pragma mark - Delegate

- (void)testDelegateReceivesWillActivateWithInterval
{
    Auto timer = self.timer;
    Auto delegate = [KYASleepWakeTimerTestDelegate new];
    timer.delegate = delegate;

    [timer scheduleWithTimeInterval:300.0 completion:nil];

    XCTAssertTrue(delegate.didReceiveWillActivate);
    XCTAssertEqual(delegate.lastWillActivateInterval, 300.0);
}

- (void)testEachSessionEndRunsThatSessionsCompletion
{
    // Forced terminations (invalidate) dispatch the completion
    // deterministically, without waiting on caffeinate signals.
    XCTestExpectation *first = [self expectationWithDescription:@"first session's completion"];
    first.assertForOverFulfill = YES;
    XCTestExpectation *second = [self expectationWithDescription:@"second session's completion"];
    second.assertForOverFulfill = YES;

    [self.timer scheduleWithTimeInterval:KYASleepWakeTimeIntervalIndefinite completion:^(BOOL cancelled) {
        XCTAssertTrue(cancelled);
        [first fulfill];
    }];
    [self.timer invalidate];
    // Replace the session before the main queue delivers the first end.
    [self.timer scheduleWithTimeInterval:KYASleepWakeTimeIntervalIndefinite completion:^(BOOL cancelled) {
        XCTAssertTrue(cancelled);
        [second fulfill];
    }];
    [self.timer invalidate];

    [self waitForExpectations:@[first, second] timeout:2.0 enforceOrder:YES];
}

- (void)testCompletionRunsOnlyOncePerSession
{
    XCTestExpectation *completed = [self expectationWithDescription:@"completion"];
    completed.assertForOverFulfill = YES;
    [self.timer scheduleWithTimeInterval:KYASleepWakeTimeIntervalIndefinite completion:^(BOOL cancelled) {
        [completed fulfill];
    }];
    [self.timer invalidate];
    // A second invalidate (app quit, dealloc) must not re-run it.
    [self.timer invalidate];
    XCTAssertNil(self.timer.completionBlock);

    [self waitForExpectations:@[completed] timeout:2.0];
    // Drain the main queue so a stray second delivery would over-fulfill.
    [[NSRunLoop mainRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.2]];
}

@end
