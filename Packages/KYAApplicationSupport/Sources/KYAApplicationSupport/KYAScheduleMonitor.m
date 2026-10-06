//
//  KYAScheduleMonitor.m
//  KYAApplicationSupport
//

#import <KYAApplicationSupport/KYAScheduleMonitor.h>
#import <KYACommon/KYACommon.h>

NSString * const KYAScheduleWindowKeyWeekdays     = @"weekdays";
NSString * const KYAScheduleWindowKeyStartMinutes = @"startMinutes";
NSString * const KYAScheduleWindowKeyEndMinutes   = @"endMinutes";
NSString * const KYAScheduleWindowKeyEnabled      = @"enabled";

#pragma mark - In-memory parsed window

@interface KYAParsedScheduleWindow : NSObject
@property (nonatomic) NSSet<NSNumber *> *weekdays;
@property (nonatomic) NSInteger startMinutes;
@property (nonatomic) NSInteger endMinutes;
@end

@implementation KYAParsedScheduleWindow

+ (nullable KYAParsedScheduleWindow *)parseDictionary:(NSDictionary *)dict
{
    if(![dict isKindOfClass:NSDictionary.class]) { return nil; }
    // A window switched off in Watched Items never matches.
    id rawEnabled = dict[KYAScheduleWindowKeyEnabled];
    if([rawEnabled isKindOfClass:NSNumber.class] && ![(NSNumber *)rawEnabled boolValue]) { return nil; }

    NSArray *rawWeekdays = dict[KYAScheduleWindowKeyWeekdays];
    NSNumber *rawStart = dict[KYAScheduleWindowKeyStartMinutes];
    NSNumber *rawEnd = dict[KYAScheduleWindowKeyEndMinutes];
    if(![rawWeekdays isKindOfClass:NSArray.class]) { return nil; }
    if(![rawStart isKindOfClass:NSNumber.class]) { return nil; }
    if(![rawEnd isKindOfClass:NSNumber.class]) { return nil; }

    NSMutableSet<NSNumber *> *weekdays = [NSMutableSet set];
    for(id wd in rawWeekdays)
    {
        if(![wd isKindOfClass:NSNumber.class]) { continue; }
        NSInteger value = [(NSNumber *)wd integerValue];
        if(value >= 1 && value <= 7) { [weekdays addObject:@(value)]; }
    }
    if(weekdays.count == 0) { return nil; }

    NSInteger start = MAX(0, MIN(1439, rawStart.integerValue));
    NSInteger end   = MAX(0, MIN(1439, rawEnd.integerValue));

    Auto window = [KYAParsedScheduleWindow new];
    window.weekdays = [weekdays copy];
    window.startMinutes = start;
    window.endMinutes = end;
    return window;
}

- (BOOL)containsCalendarComponents:(NSDateComponents *)components
{
    NSInteger weekday = components.weekday;            // 1..7
    NSInteger minutes = components.hour * 60 + components.minute;

    BOOL wraps = (self.endMinutes <= self.startMinutes);

    if(!wraps)
    {
        // Same-day window: weekday must match, time within [start, end).
        if(![self.weekdays containsObject:@(weekday)]) { return NO; }
        return (minutes >= self.startMinutes) && (minutes < self.endMinutes);
    }
    else
    {
        // Wraps past midnight. Today's matching part: weekday + [start, 1440).
        if([self.weekdays containsObject:@(weekday)] && minutes >= self.startMinutes)
        {
            return YES;
        }
        // Yesterday's matching part: previous weekday + [0, end).
        NSInteger prevWeekday = ((weekday - 1) <= 0) ? 7 : (weekday - 1);
        if([self.weekdays containsObject:@(prevWeekday)] && minutes < self.endMinutes)
        {
            return YES;
        }
        return NO;
    }
}

@end

#pragma mark - Monitor

@interface KYAScheduleMonitor ()
@property (nonatomic) NSArray<KYAParsedScheduleWindow *> *parsedWindows;
@property (nonatomic, nullable) NSTimer *tickTimer;
@property (nonatomic, readwrite, getter=isRunning) BOOL running;
@property (nonatomic) BOOL lastInsideState;
@end

@implementation KYAScheduleMonitor

- (instancetype)init
{
    self = [super init];
    if(self)
    {
        _parsedWindows = @[];
        _lastInsideState = NO;
    }
    return self;
}

- (void)dealloc
{
    [_tickTimer invalidate];
}

- (void)setWindows:(NSArray<NSDictionary<NSString *, id> *> *)windows
{
    NSMutableArray<KYAParsedScheduleWindow *> *parsed = [NSMutableArray array];
    for(NSDictionary *dict in windows)
    {
        Auto window = [KYAParsedScheduleWindow parseDictionary:dict];
        if(window != nil) { [parsed addObject:window]; }
    }
    self.parsedWindows = [parsed copy];
    if(self.running) { [self evaluateAndNotify]; }
}

- (void)start
{
    if(self.running) { return; }
    self.running = YES;
    self.lastInsideState = NO;

    [self evaluateAndNotify];

    AutoWeak weakSelf = self;
    Auto timer = [NSTimer scheduledTimerWithTimeInterval:60.0
                                                 repeats:YES
                                                   block:^(NSTimer * _Nonnull t) {
        [weakSelf evaluateAndNotify];
    }];
    timer.tolerance = 5.0;
    self.tickTimer = timer;
}

- (void)stop
{
    [self.tickTimer invalidate];
    self.tickTimer = nil;
    self.running = NO;
    self.lastInsideState = NO;
}

- (BOOL)dateIsInsideAnyWindow:(NSDate *)date
{
    if(self.parsedWindows.count == 0) { return NO; }
    Auto calendar = NSCalendar.currentCalendar;
    NSDateComponents *components = [calendar components:NSCalendarUnitWeekday | NSCalendarUnitHour | NSCalendarUnitMinute
                                               fromDate:date];
    for(KYAParsedScheduleWindow *window in self.parsedWindows)
    {
        if([window containsCalendarComponents:components]) { return YES; }
    }
    return NO;
}

- (void)evaluateAndNotify
{
    BOOL inside = [self dateIsInsideAnyWindow:[NSDate date]];
    if(inside == self.lastInsideState) { return; }
    self.lastInsideState = inside;

    Auto delegate = self.delegate;
    if(inside)
    {
        if([delegate respondsToSelector:@selector(scheduleMonitorDidEnterWindow:)])
        {
            [delegate scheduleMonitorDidEnterWindow:self];
        }
    }
    else
    {
        if([delegate respondsToSelector:@selector(scheduleMonitorDidLeaveWindow:)])
        {
            [delegate scheduleMonitorDidLeaveWindow:self];
        }
    }
}

@end
