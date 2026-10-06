//
//  KYAScheduleMonitorTests.m
//  KYAApplicationSupport
//

#import <XCTest/XCTest.h>
#import <KYACommon/KYACommon.h>
#import <KYAApplicationSupport/KYAApplicationSupport.h>

@interface KYAScheduleMonitorTests : XCTestCase
@property (nonatomic) KYAScheduleMonitor *monitor;
@property (nonatomic) NSCalendar *calendar;
@end

@implementation KYAScheduleMonitorTests

- (void)setUp
{
    [super setUp];
    self.monitor = [KYAScheduleMonitor new];
    self.calendar = NSCalendar.currentCalendar;
}

- (NSDate *)dateForWeekday:(NSInteger)weekday hour:(NSInteger)hour minute:(NSInteger)minute
{
    // Build a date in the current week for the given weekday (1..7) at H:M.
    NSDate *now = [NSDate date];
    NSDateComponents *current = [self.calendar components:NSCalendarUnitYear | NSCalendarUnitMonth | NSCalendarUnitDay | NSCalendarUnitWeekday
                                                fromDate:now];
    NSInteger delta = weekday - current.weekday;
    NSDate *target = [self.calendar dateByAddingUnit:NSCalendarUnitDay value:delta toDate:now options:0];

    NSDateComponents *comps = [self.calendar components:NSCalendarUnitYear | NSCalendarUnitMonth | NSCalendarUnitDay
                                               fromDate:target];
    comps.hour = hour;
    comps.minute = minute;
    comps.second = 0;
    return [self.calendar dateFromComponents:comps];
}

- (NSDictionary *)windowWithWeekdays:(NSArray<NSNumber *> *)weekdays start:(NSInteger)start end:(NSInteger)end
{
    return @{
        KYAScheduleWindowKeyWeekdays: weekdays,
        KYAScheduleWindowKeyStartMinutes: @(start),
        KYAScheduleWindowKeyEndMinutes: @(end),
    };
}

#pragma mark -

- (void)testEmptyWindowsReturnsNo
{
    [self.monitor setWindows:@[]];
    XCTAssertFalse([self.monitor dateIsInsideAnyWindow:[NSDate date]]);
}

- (void)testNilWindowsReturnsNo
{
    [self.monitor setWindows:nil];
    XCTAssertFalse([self.monitor dateIsInsideAnyWindow:[NSDate date]]);
}

- (void)testSimpleWeekdayWindow_inside
{
    // Monday (weekday=2) 09:00 to 18:00, query at Monday 12:00 → inside
    [self.monitor setWindows:@[ [self windowWithWeekdays:@[@2] start:9 * 60 end:18 * 60] ]];
    NSDate *target = [self dateForWeekday:2 hour:12 minute:0];
    XCTAssertTrue([self.monitor dateIsInsideAnyWindow:target]);
}

- (void)testSwitchedOffWindowNeverMatches
{
    NSMutableDictionary *window = [[self windowWithWeekdays:@[@2] start:9 * 60 end:18 * 60] mutableCopy];
    window[KYAScheduleWindowKeyEnabled] = @NO;
    [self.monitor setWindows:@[ window ]];
    XCTAssertFalse([self.monitor dateIsInsideAnyWindow:[self dateForWeekday:2 hour:12 minute:0]]);

    window[KYAScheduleWindowKeyEnabled] = @YES;
    [self.monitor setWindows:@[ window ]];
    XCTAssertTrue([self.monitor dateIsInsideAnyWindow:[self dateForWeekday:2 hour:12 minute:0]]);
}

- (void)testSimpleWeekdayWindow_outsideSameDay
{
    // Monday 09:00 to 18:00, query at Monday 08:30 → outside
    [self.monitor setWindows:@[ [self windowWithWeekdays:@[@2] start:9 * 60 end:18 * 60] ]];
    NSDate *target = [self dateForWeekday:2 hour:8 minute:30];
    XCTAssertFalse([self.monitor dateIsInsideAnyWindow:target]);
}

- (void)testSimpleWeekdayWindow_outsideWrongDay
{
    // Monday-only window, query Tuesday → outside
    [self.monitor setWindows:@[ [self windowWithWeekdays:@[@2] start:9 * 60 end:18 * 60] ]];
    NSDate *target = [self dateForWeekday:3 hour:12 minute:0];
    XCTAssertFalse([self.monitor dateIsInsideAnyWindow:target]);
}

- (void)testEndIsExclusive
{
    // Window [09:00, 18:00). At 18:00 exactly → outside.
    [self.monitor setWindows:@[ [self windowWithWeekdays:@[@2] start:9 * 60 end:18 * 60] ]];
    NSDate *target = [self dateForWeekday:2 hour:18 minute:0];
    XCTAssertFalse([self.monitor dateIsInsideAnyWindow:target]);
}

- (void)testStartIsInclusive
{
    [self.monitor setWindows:@[ [self windowWithWeekdays:@[@2] start:9 * 60 end:18 * 60] ]];
    NSDate *target = [self dateForWeekday:2 hour:9 minute:0];
    XCTAssertTrue([self.monitor dateIsInsideAnyWindow:target]);
}

- (void)testMultiWeekdayWindow
{
    // Weekdays 2,3,4,5,6 (Mon-Fri) 09-18
    [self.monitor setWindows:@[ [self windowWithWeekdays:@[@2,@3,@4,@5,@6] start:9 * 60 end:18 * 60] ]];
    XCTAssertTrue([self.monitor dateIsInsideAnyWindow:[self dateForWeekday:2 hour:12 minute:0]]);
    XCTAssertTrue([self.monitor dateIsInsideAnyWindow:[self dateForWeekday:5 hour:17 minute:59]]);
    // Saturday → outside
    XCTAssertFalse([self.monitor dateIsInsideAnyWindow:[self dateForWeekday:7 hour:12 minute:0]]);
}

- (void)testWrappingWindow_lateNight
{
    // Friday 22:00 → 06:00 next day. Window passes weekday=6 (Fri) start=22*60, end=6*60.
    // - Fri 23:00 → inside (today's tail)
    // - Sat 02:00 → inside (yesterday's wrap)
    // - Sat 07:00 → outside
    // - Fri 21:00 → outside
    [self.monitor setWindows:@[ [self windowWithWeekdays:@[@6] start:22 * 60 end:6 * 60] ]];
    XCTAssertTrue([self.monitor dateIsInsideAnyWindow:[self dateForWeekday:6 hour:23 minute:0]]);
    XCTAssertTrue([self.monitor dateIsInsideAnyWindow:[self dateForWeekday:7 hour:2 minute:0]]);
    XCTAssertFalse([self.monitor dateIsInsideAnyWindow:[self dateForWeekday:7 hour:7 minute:0]]);
    XCTAssertFalse([self.monitor dateIsInsideAnyWindow:[self dateForWeekday:6 hour:21 minute:0]]);
}

- (void)testInvalidWindow_dropped
{
    NSDictionary *bad = @{
        KYAScheduleWindowKeyWeekdays: @[@99],            // out of range
        KYAScheduleWindowKeyStartMinutes: @(60),
        KYAScheduleWindowKeyEndMinutes: @(120),
    };
    [self.monitor setWindows:@[bad]];
    XCTAssertFalse([self.monitor dateIsInsideAnyWindow:[NSDate date]]);
}

- (void)testInvalidWindow_missingKeys_dropped
{
    NSDictionary *bad = @{ KYAScheduleWindowKeyWeekdays: @[@2] };  // missing start/end
    [self.monitor setWindows:@[bad]];
    XCTAssertFalse([self.monitor dateIsInsideAnyWindow:[NSDate date]]);
}

- (void)testNonDictionaryEntry_dropped
{
    [self.monitor setWindows:(NSArray *)@[ @"not-a-dict" ]];
    XCTAssertFalse([self.monitor dateIsInsideAnyWindow:[NSDate date]]);
}

- (void)testStartGreaterThanEndIsTreatedAsWrap
{
    // start=120, end=60 → wraps. weekday=2 should match Mon 02:30 AND Sun 00:30 (yesterday wrap).
    [self.monitor setWindows:@[ [self windowWithWeekdays:@[@2] start:120 end:60] ]];
    XCTAssertTrue([self.monitor dateIsInsideAnyWindow:[self dateForWeekday:2 hour:2 minute:30]]);  // Mon, > start
    XCTAssertTrue([self.monitor dateIsInsideAnyWindow:[self dateForWeekday:3 hour:0 minute:30]]);  // Tue, < end → Mon wrap
    XCTAssertFalse([self.monitor dateIsInsideAnyWindow:[self dateForWeekday:2 hour:1 minute:30]]); // Mon, < start, no Sun in weekdays
}

@end
