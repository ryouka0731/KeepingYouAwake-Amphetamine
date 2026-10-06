//
//  KYAScheduleMonitor.h
//  KYAApplicationSupport
//
//  Created for KeepingYouAwake-Amphetamine fork (issue #52).
//

#import <Foundation/Foundation.h>
#import <KYACommon/KYAExport.h>

NS_ASSUME_NONNULL_BEGIN

/// Dictionary keys used inside each schedule-window dictionary.
KYA_EXPORT NSString * const KYAScheduleWindowKeyWeekdays;     // NSArray<NSNumber*>, 1..7 (1=Sunday)
KYA_EXPORT NSString * const KYAScheduleWindowKeyStartMinutes; // NSNumber, 0..1439
KYA_EXPORT NSString * const KYAScheduleWindowKeyEndMinutes;   // NSNumber, 0..1439
KYA_EXPORT NSString * const KYAScheduleWindowKeyEnabled;      // optional NSNumber (BOOL); absent = enabled

@protocol KYAScheduleMonitorDelegate;

/// Watches a list of weekday × time-of-day windows and tells its
/// delegate whenever the current time enters or leaves a window.
///
/// The monitor ticks every 60 seconds while running. It does not run
/// itself off the main run loop's tick when the Mac is asleep, but
/// the next post-wake tick re-evaluates state, so the worst-case lag
/// after wake is ~1 minute.
@interface KYAScheduleMonitor : NSObject

@property (weak, nonatomic, nullable) id<KYAScheduleMonitorDelegate> delegate;

/// YES while the monitor is ticking.
@property (readonly, nonatomic, getter=isRunning) BOOL running;

/// Replace the configured windows. Each entry is the dictionary
/// shape from `kya_scheduleWindows` on NSUserDefaults+KYAKeys.
/// Empty/nil array effectively disables the monitor.
- (void)setWindows:(nullable NSArray<NSDictionary<NSString *, id> *> *)windows;

/// Start ticking. Safe to call multiple times.
- (void)start;

/// Stop ticking and forget the in-window cache.
- (void)stop;

/// Returns YES if `date` falls into any configured window.
/// Exposed for testability.
- (BOOL)dateIsInsideAnyWindow:(NSDate *)date;

@end

@protocol KYAScheduleMonitorDelegate <NSObject>
@optional
/// Sent when the wall-clock crosses from outside-any-window to
/// inside-some-window.
- (void)scheduleMonitorDidEnterWindow:(KYAScheduleMonitor *)monitor;
/// Sent on the inverse transition.
- (void)scheduleMonitorDidLeaveWindow:(KYAScheduleMonitor *)monitor;
@end

NS_ASSUME_NONNULL_END
