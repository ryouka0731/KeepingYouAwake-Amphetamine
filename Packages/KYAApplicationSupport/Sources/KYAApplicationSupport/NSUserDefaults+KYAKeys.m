//
//  NSUserDefaults+KYAKeys.m
//  KYAApplicationSupport
//
//  Created by Marcel Dierkes on 25.10.15.
//  Copyright © 2015 Marcel Dierkes. All rights reserved.
//

#import <KYAApplicationSupport/NSUserDefaults+KYAKeys.h>
#import <KYAApplicationSupport/KYAScheduleMonitor.h>
#import <KYACommon/KYACommon.h>

// A macro to define a new user defaults convenience property for BOOL values.
// - _short_getter_name represents the name of the getter,
//                      e.g. `isSomethingEnabled` without the `kya_` prefix.
// - _property_name represents the name of the property and the setter,
//                      e.g. `somethingEnabled` without the `kya_` prefix.
// - _short_defaults_key represents a user defaults key,
//                      e.g. `SomethingEnabled` without any prefixes
//
// These values will generate the implementation for a property
// e.g. `@property (nonatomic, getter=kya_isSomethingEnabled) BOOL kya_somethingEnabled;`
// and for a user defaults key constant
// e.g. `KYA_EXPORT NSString * const KYAUserDefaultsKeySomethingEnabled;`
// which will create an actual string key in the pre-defined format
// e.g. `info.marcel-dierkes.KeepingYouAwake.SomethingEnabled`
#define KYA_GENERATE_BOOL_PROPERTY(_short_getter_name, _property_name, _short_defaults_key) \
NSString * const KYAUserDefaultsKey##_short_defaults_key =                                  \
    @"info.marcel-dierkes.KeepingYouAwake." #_short_defaults_key;                           \
                                                                                            \
- (BOOL)kya_##_short_getter_name                                                            \
{                                                                                           \
    return [self boolForKey:KYAUserDefaultsKey##_short_defaults_key];                       \
}                                                                                           \
- (void)setKya_##_property_name:(BOOL)enabled                                               \
{                                                                                           \
    [self setBool:enabled forKey:KYAUserDefaultsKey##_short_defaults_key];                  \
}

@implementation NSUserDefaults (KYAKeys)

KYA_GENERATE_BOOL_PROPERTY(isActivatedOnLaunch,
                           activateOnLaunch,
                           ActivateOnLaunch);

KYA_GENERATE_BOOL_PROPERTY(shouldAllowDisplaySleep,
                           allowDisplaySleep,
                           AllowDisplaySleep);

KYA_GENERATE_BOOL_PROPERTY(isPreventDiskSleepEnabled,
                           preventDiskSleepEnabled,
                           PreventDiskSleepEnabled);

KYA_GENERATE_BOOL_PROPERTY(isMenuBarIconHighlightDisabled,
                           menuBarIconHighlightDisabled,
                           MenuBarIconHighlightDisabled);

KYA_GENERATE_BOOL_PROPERTY(isMenuBarCountdownDisabled,
                           menuBarCountdownDisabled,
                           MenuBarCountdownDisabled);

KYA_GENERATE_BOOL_PROPERTY(arePreReleaseUpdatesEnabled,
                           preReleaseUpdatesEnabled,
                           PreReleaseUpdatesEnabled);

KYA_GENERATE_BOOL_PROPERTY(isQuitOnTimerExpirationEnabled,
                           quitOnTimerExpirationEnabled,
                           IsQuitOnTimerExpirationEnabled);

KYA_GENERATE_BOOL_PROPERTY(isActivateOnExternalDisplayConnectedEnabled,
                           activateOnExternalDisplayConnectedEnabled,
                           ActivateOnExternalDisplayConnectedEnabled);


KYA_GENERATE_BOOL_PROPERTY(isDeactivateOnUserSwitchEnabled,
                           deactivateOnUserSwitchEnabled,
                           DeactivateOnUserSwitchEnabled);

KYA_GENERATE_BOOL_PROPERTY(isBatteryCapacityThresholdEnabled,
                           batteryCapacityThresholdEnabled,
                           BatteryCapacityThresholdEnabled);

KYA_GENERATE_BOOL_PROPERTY(isLowPowerModeMonitoringEnabled,
                           lowPowerModeMonitoringEnabled,
                           LowPowerModeMonitoringEnabled);

KYA_GENERATE_BOOL_PROPERTY(isDeactivateOnFullChargeEnabled,
                           deactivateOnFullChargeEnabled,
                           DeactivateOnFullChargeEnabled);

KYA_GENERATE_BOOL_PROPERTY(isDriveAliveEnabled,
                           driveAliveEnabled,
                           DriveAliveEnabled);

KYA_GENERATE_BOOL_PROPERTY(isActivateOnACPowerEnabled,
                           activateOnACPowerEnabled,
                           ActivateOnACPowerEnabled);

KYA_GENERATE_BOOL_PROPERTY(isScheduleEnabled,
                           scheduleEnabled,
                           ScheduleEnabled);

KYA_GENERATE_BOOL_PROPERTY(isDownloadInProgressActivationEnabled,
                           downloadInProgressActivationEnabled,
                           DownloadInProgressActivationEnabled);

KYA_GENERATE_BOOL_PROPERTY(isMouseJigglerEnabled,
                           mouseJigglerEnabled,
                           MouseJigglerEnabled);
KYA_GENERATE_BOOL_PROPERTY(isActivateOnExternalAudioOutputEnabled,
                           activateOnExternalAudioOutputEnabled,
                           ActivateOnExternalAudioOutputEnabled);

KYA_GENERATE_BOOL_PROPERTY(isActivateOnCPULoadEnabled,
                           activateOnCPULoadEnabled,
                           ActivateOnCPULoadEnabled);

#pragma mark - CPU Load Activation Threshold

NSString * const KYAUserDefaultsKeyCPULoadActivationThreshold = @"info.marcel-dierkes.KeepingYouAwake.CPULoadActivationThreshold";

- (double)kya_cpuLoadActivationThreshold
{
    if([self objectForKey:KYAUserDefaultsKeyCPULoadActivationThreshold] == nil) { return 50.0; }
    double value = [self doubleForKey:KYAUserDefaultsKeyCPULoadActivationThreshold];
    return MAX(1.0, MIN(99.0, value));
}

- (void)setKya_cpuLoadActivationThreshold:(double)threshold
{
    [self setDouble:MAX(1.0, MIN(99.0, threshold))
             forKey:KYAUserDefaultsKeyCPULoadActivationThreshold];
}

#pragma mark - Watched Wi-Fi SSIDs

NSString * const KYAUserDefaultsKeyWatchedWiFiSSIDs = @"info.marcel-dierkes.KeepingYouAwake.WatchedWiFiSSIDs";

- (NSArray<NSString *> *)kya_watchedWiFiSSIDs
{
    Auto raw = [self arrayForKey:KYAUserDefaultsKeyWatchedWiFiSSIDs];
    if(raw.count == 0) { return nil; }

    Auto sanitized = [NSMutableArray<NSString *> arrayWithCapacity:raw.count];
    for(id entry in raw)
    {
        if([entry isKindOfClass:NSString.class] && [(NSString *)entry length] > 0)
        {
            [sanitized addObject:(NSString *)entry];
        }
    }
    if(sanitized.count == 0) { return nil; }
    return [sanitized copy];
}

- (void)setKya_watchedWiFiSSIDs:(NSArray<NSString *> *)ssids
{
    if(ssids.count == 0)
    {
        [self removeObjectForKey:KYAUserDefaultsKeyWatchedWiFiSSIDs];
    }
    else
    {
        [self setObject:[ssids copy] forKey:KYAUserDefaultsKeyWatchedWiFiSSIDs];
    }
}

#pragma mark - Watched Application Bundle Identifiers

NSString * const KYAUserDefaultsKeyWatchedApplicationBundleIdentifiers = @"info.marcel-dierkes.KeepingYouAwake.WatchedApplicationBundleIdentifiers";

- (NSArray<NSString *> *)kya_watchedApplicationBundleIdentifiers
{
    Auto raw = [self arrayForKey:KYAUserDefaultsKeyWatchedApplicationBundleIdentifiers];
    if(raw.count == 0) { return nil; }

    Auto sanitized = [NSMutableArray<NSString *> arrayWithCapacity:raw.count];
    for(id entry in raw)
    {
        if([entry isKindOfClass:NSString.class] && [(NSString *)entry length] > 0)
        {
            [sanitized addObject:(NSString *)entry];
        }
    }
    if(sanitized.count == 0) { return nil; }
    return [sanitized copy];
}

- (void)setKya_watchedApplicationBundleIdentifiers:(NSArray<NSString *> *)bundleIdentifiers
{
    if(bundleIdentifiers.count == 0)
    {
        [self removeObjectForKey:KYAUserDefaultsKeyWatchedApplicationBundleIdentifiers];
    }
    else
    {
        [self setObject:[bundleIdentifiers copy] forKey:KYAUserDefaultsKeyWatchedApplicationBundleIdentifiers];
    }
}

#pragma mark - Schedule Windows

NSString * const KYAUserDefaultsKeyScheduleWindows = @"info.marcel-dierkes.KeepingYouAwake.ScheduleWindows";

- (NSArray<NSDictionary<NSString *, id> *> *)kya_scheduleWindows
{
    Auto raw = [self arrayForKey:KYAUserDefaultsKeyScheduleWindows];
    if(raw.count == 0) { return nil; }

    Auto sanitized = [NSMutableArray<NSDictionary<NSString *, id> *> arrayWithCapacity:raw.count];
    for(id entry in raw)
    {
        if([entry isKindOfClass:NSDictionary.class])
        {
            [sanitized addObject:(NSDictionary *)entry];
        }
    }
    if(sanitized.count == 0) { return nil; }
    return [sanitized copy];
}

- (void)setKya_scheduleWindows:(NSArray<NSDictionary<NSString *, id> *> *)windows
{
    if(windows.count == 0)
    {
        [self removeObjectForKey:KYAUserDefaultsKeyScheduleWindows];
    }
    else
    {
        [self setObject:[windows copy] forKey:KYAUserDefaultsKeyScheduleWindows];
    }
}

#pragma mark - Download Directories

NSString * const KYAUserDefaultsKeyDownloadDirectories = @"info.marcel-dierkes.KeepingYouAwake.DownloadDirectories";

- (NSArray<NSString *> *)kya_downloadDirectories
{
    Auto raw = [self arrayForKey:KYAUserDefaultsKeyDownloadDirectories];
    if(raw.count == 0) { return nil; }

    Auto sanitized = [NSMutableArray<NSString *> arrayWithCapacity:raw.count];
    for(id entry in raw)
    {
        if([entry isKindOfClass:NSString.class] && [(NSString *)entry length] > 0)
        {
            [sanitized addObject:(NSString *)entry];
        }
    }
    if(sanitized.count == 0) { return nil; }
    return [sanitized copy];
}

- (void)setKya_downloadDirectories:(NSArray<NSString *> *)directories
{
    if(directories.count == 0)
    {
        [self removeObjectForKey:KYAUserDefaultsKeyDownloadDirectories];
    }
    else
    {
        [self setObject:[directories copy] forKey:KYAUserDefaultsKeyDownloadDirectories];
    }
}

#pragma mark - Switched-off Watched Items

NSString * const KYAUserDefaultsKeyDisabledWatchedWiFiSSIDs = @"info.marcel-dierkes.KeepingYouAwake.DisabledWatchedWiFiSSIDs";
NSString * const KYAUserDefaultsKeyDisabledWatchedApplicationBundleIdentifiers = @"info.marcel-dierkes.KeepingYouAwake.DisabledWatchedApplicationBundleIdentifiers";
NSString * const KYAUserDefaultsKeyDisabledDownloadDirectories = @"info.marcel-dierkes.KeepingYouAwake.DisabledDownloadDirectories";

/// Non-empty strings stored under `key`, or nil.
- (nullable NSArray<NSString *> *)kya_nonEmptyStringsForKey:(NSString *)key
{
    Auto raw = [self arrayForKey:key];
    Auto strings = [NSMutableArray<NSString *> arrayWithCapacity:raw.count];
    for(id entry in raw)
    {
        if([entry isKindOfClass:NSString.class] && [(NSString *)entry length] > 0)
        {
            [strings addObject:(NSString *)entry];
        }
    }
    return (strings.count > 0) ? [strings copy] : nil;
}

- (void)kya_setStrings:(nullable NSArray<NSString *> *)strings forKey:(NSString *)key
{
    if(strings.count == 0)
    {
        [self removeObjectForKey:key];
    }
    else
    {
        [self setObject:[strings copy] forKey:key];
    }
}

/// `items` without the entries in `disabled`. `ignoringCase` matches the
/// way the trigger itself compares entries (SSIDs and bundle identifiers
/// case-insensitively, folder paths exactly).
static NSArray<NSString *> *KYAEnabledItems(NSArray<NSString *> *items, NSArray<NSString *> *disabled, BOOL ignoringCase)
{
    if(disabled.count == 0) { return items; }
    Auto off = [NSMutableSet<NSString *> setWithCapacity:disabled.count];
    for(NSString *entry in disabled)
    {
        [off addObject:ignoringCase ? entry.lowercaseString : entry];
    }
    Auto enabled = [NSMutableArray<NSString *> arrayWithCapacity:items.count];
    for(NSString *item in items)
    {
        if(![off containsObject:ignoringCase ? item.lowercaseString : item]) { [enabled addObject:item]; }
    }
    return [enabled copy];
}

- (NSArray<NSString *> *)kya_disabledWatchedWiFiSSIDs
{
    return [self kya_nonEmptyStringsForKey:KYAUserDefaultsKeyDisabledWatchedWiFiSSIDs];
}

- (void)setKya_disabledWatchedWiFiSSIDs:(NSArray<NSString *> *)ssids
{
    [self kya_setStrings:ssids forKey:KYAUserDefaultsKeyDisabledWatchedWiFiSSIDs];
}

- (NSArray<NSString *> *)kya_disabledWatchedApplicationBundleIdentifiers
{
    return [self kya_nonEmptyStringsForKey:KYAUserDefaultsKeyDisabledWatchedApplicationBundleIdentifiers];
}

- (void)setKya_disabledWatchedApplicationBundleIdentifiers:(NSArray<NSString *> *)bundleIdentifiers
{
    [self kya_setStrings:bundleIdentifiers forKey:KYAUserDefaultsKeyDisabledWatchedApplicationBundleIdentifiers];
}

- (NSArray<NSString *> *)kya_disabledDownloadDirectories
{
    return [self kya_nonEmptyStringsForKey:KYAUserDefaultsKeyDisabledDownloadDirectories];
}

- (void)setKya_disabledDownloadDirectories:(NSArray<NSString *> *)directories
{
    [self kya_setStrings:directories forKey:KYAUserDefaultsKeyDisabledDownloadDirectories];
}

- (NSArray<NSString *> *)kya_enabledWatchedWiFiSSIDs
{
    Auto enabled = KYAEnabledItems(self.kya_watchedWiFiSSIDs, self.kya_disabledWatchedWiFiSSIDs, YES);
    return (enabled.count > 0) ? enabled : nil;
}

- (NSArray<NSString *> *)kya_enabledWatchedApplicationBundleIdentifiers
{
    Auto enabled = KYAEnabledItems(self.kya_watchedApplicationBundleIdentifiers,
                                   self.kya_disabledWatchedApplicationBundleIdentifiers, YES);
    return (enabled.count > 0) ? enabled : nil;
}

- (NSArray<NSString *> *)kya_enabledDownloadDirectories
{
    Auto directories = self.kya_downloadDirectories;
    if(directories == nil) { return nil; }
    return KYAEnabledItems(directories, self.kya_disabledDownloadDirectories, NO);
}

- (NSArray<NSDictionary<NSString *, id> *> *)kya_enabledScheduleWindows
{
    Auto enabled = [NSMutableArray<NSDictionary<NSString *, id> *> new];
    for(NSDictionary<NSString *, id> *window in self.kya_scheduleWindows)
    {
        id flag = window[KYAScheduleWindowKeyEnabled];
        if([flag isKindOfClass:NSNumber.class] && ![(NSNumber *)flag boolValue]) { continue; }
        [enabled addObject:window];
    }
    return (enabled.count > 0) ? [enabled copy] : nil;
}

#pragma mark - Battery Capacity Threshold

NSString * const KYAUserDefaultsKeyBatteryCapacityThreshold = @"info.marcel-dierkes.KeepingYouAwake.BatteryCapacityThreshold";

- (CGFloat)kya_batteryCapacityThreshold
{
    CGFloat threshold = [self floatForKey:KYAUserDefaultsKeyBatteryCapacityThreshold];
    return MAX(10.0f , threshold);
}

- (void)setKya_batteryCapacityThreshold:(CGFloat)batteryCapacityThreshold
{
    [self setFloat:(float)batteryCapacityThreshold forKey:KYAUserDefaultsKeyBatteryCapacityThreshold];
}

@end
