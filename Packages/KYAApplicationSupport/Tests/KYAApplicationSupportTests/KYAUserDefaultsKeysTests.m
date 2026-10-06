//
//  KYAUserDefaultsKeysTests.m
//  KYAApplicationSupport
//
//  Created by Marcel Dierkes on 11.05.22.
//

#import <XCTest/XCTest.h>
#import <KYACommon/KYACommon.h>
#import <KYAApplicationSupport/KYAApplicationSupport.h>
#import <KYAApplicationSupport/KYAScheduleMonitor.h>
#import "../../Sources/KYAApplicationSupport/KYAApplicationSupportLog.h"

#define KYA_GENERATE_BOOL_TEST(_short_getter_name, _property_name, _defaults_key)           \
- (void)testProperty_##_property_name                                                       \
{                                                                                           \
    Auto defaults = self.defaults;                                                          \
    Auto key = _defaults_key;                                                               \
                                                                                            \
    defaults.kya_##_property_name = YES;                                                    \
    XCTAssertTrue([defaults kya_##_short_getter_name]);                                     \
    XCTAssertTrue([defaults boolForKey:key]);                                               \
                                                                                            \
    defaults.kya_##_property_name = NO;                                                     \
    XCTAssertFalse([defaults kya_##_short_getter_name]);                                    \
    XCTAssertFalse([defaults boolForKey:key]);                                              \
                                                                                            \
    [defaults setBool:YES forKey:key];                                                      \
    XCTAssertTrue([defaults kya_##_short_getter_name]);                                     \
    os_log(KYAApplicationSupportLog(), "Tested User Defaults Key '%{public}@'.", key);      \
}

@interface KYAUserDefaultsKeysTests : XCTestCase
@property (nonatomic) NSUserDefaults *defaults;
@end

@implementation KYAUserDefaultsKeysTests

- (void)setUp
{
    [super setUp];
    
    self.defaults = [[NSUserDefaults alloc] initWithSuiteName:NSStringFromClass([self class])];
}

KYA_GENERATE_BOOL_TEST(isActivatedOnLaunch,
                       activateOnLaunch,
                       KYAUserDefaultsKeyActivateOnLaunch);

KYA_GENERATE_BOOL_TEST(shouldAllowDisplaySleep,
                       allowDisplaySleep,
                       KYAUserDefaultsKeyAllowDisplaySleep);

KYA_GENERATE_BOOL_TEST(isPreventDiskSleepEnabled,
                       preventDiskSleepEnabled,
                       KYAUserDefaultsKeyPreventDiskSleepEnabled);

KYA_GENERATE_BOOL_TEST(isMenuBarIconHighlightDisabled,
                       menuBarIconHighlightDisabled,
                       KYAUserDefaultsKeyMenuBarIconHighlightDisabled);

KYA_GENERATE_BOOL_TEST(arePreReleaseUpdatesEnabled,
                       preReleaseUpdatesEnabled,
                       KYAUserDefaultsKeyPreReleaseUpdatesEnabled);

KYA_GENERATE_BOOL_TEST(isQuitOnTimerExpirationEnabled,
                       quitOnTimerExpirationEnabled,
                       KYAUserDefaultsKeyIsQuitOnTimerExpirationEnabled);

KYA_GENERATE_BOOL_TEST(isActivateOnExternalDisplayConnectedEnabled,
                       activateOnExternalDisplayConnectedEnabled,
                       KYAUserDefaultsKeyActivateOnExternalDisplayConnectedEnabled);

KYA_GENERATE_BOOL_TEST(isDeactivateOnUserSwitchEnabled,
                       deactivateOnUserSwitchEnabled,
                       KYAUserDefaultsKeyDeactivateOnUserSwitchEnabled);

KYA_GENERATE_BOOL_TEST(isBatteryCapacityThresholdEnabled,
                       batteryCapacityThresholdEnabled,
                       KYAUserDefaultsKeyBatteryCapacityThresholdEnabled);

KYA_GENERATE_BOOL_TEST(isLowPowerModeMonitoringEnabled,
                       lowPowerModeMonitoringEnabled,
                       KYAUserDefaultsKeyLowPowerModeMonitoringEnabled);

KYA_GENERATE_BOOL_TEST(isDeactivateOnFullChargeEnabled,
                       deactivateOnFullChargeEnabled,
                       KYAUserDefaultsKeyDeactivateOnFullChargeEnabled);

KYA_GENERATE_BOOL_TEST(isActivateOnACPowerEnabled,
                       activateOnACPowerEnabled,
                       KYAUserDefaultsKeyActivateOnACPowerEnabled);

KYA_GENERATE_BOOL_TEST(isDriveAliveEnabled,
                       driveAliveEnabled,
                       KYAUserDefaultsKeyDriveAliveEnabled);

KYA_GENERATE_BOOL_TEST(isMenuBarCountdownDisabled,
                       menuBarCountdownDisabled,
                       KYAUserDefaultsKeyMenuBarCountdownDisabled);

#pragma mark - Watched Wi-Fi SSIDs sanitization

- (void)testWatchedWiFiSSIDs_roundTrip
{
    Auto defaults = self.defaults;
    NSArray *input = @[@"Office-WiFi", @"Home-5G"];
    defaults.kya_watchedWiFiSSIDs = input;
    XCTAssertEqualObjects(defaults.kya_watchedWiFiSSIDs, input);
    XCTAssertEqualObjects([defaults arrayForKey:KYAUserDefaultsKeyWatchedWiFiSSIDs], input);
}

- (void)testWatchedWiFiSSIDs_emptyArrayClearsKey
{
    Auto defaults = self.defaults;
    defaults.kya_watchedWiFiSSIDs = @[@"x"];
    defaults.kya_watchedWiFiSSIDs = @[];
    XCTAssertNil(defaults.kya_watchedWiFiSSIDs);
    XCTAssertNil([defaults arrayForKey:KYAUserDefaultsKeyWatchedWiFiSSIDs]);
}

- (void)testWatchedWiFiSSIDs_nilClearsKey
{
    Auto defaults = self.defaults;
    defaults.kya_watchedWiFiSSIDs = @[@"x"];
    defaults.kya_watchedWiFiSSIDs = nil;
    XCTAssertNil(defaults.kya_watchedWiFiSSIDs);
}

- (void)testWatchedWiFiSSIDs_dropsNonStringAndEmptyEntries
{
    Auto defaults = self.defaults;
    // Bypass the setter to force a malformed plist underneath. This is
    // exactly how a fat-fingered `defaults write` could land in prefs.
    // NSNull isn't plist-compatible and would crash NSUserDefaults; use
    // NSNumber as the non-string filter probe instead.
    [defaults setObject:@[@"Office", @"", @42, @YES, @"Home"]
                 forKey:KYAUserDefaultsKeyWatchedWiFiSSIDs];

    NSArray *result = defaults.kya_watchedWiFiSSIDs;
    XCTAssertEqualObjects(result, (@[@"Office", @"Home"]));
}

- (void)testWatchedWiFiSSIDs_returnsNilWhenEverythingFiltered
{
    Auto defaults = self.defaults;
    [defaults setObject:@[@"", @42, @YES]
                 forKey:KYAUserDefaultsKeyWatchedWiFiSSIDs];
    XCTAssertNil(defaults.kya_watchedWiFiSSIDs);
}

#pragma mark - Watched Application Bundle Identifiers sanitization

- (void)testWatchedAppBundleIDs_roundTrip
{
    Auto defaults = self.defaults;
    NSArray *input = @[@"com.apple.FinalCut", @"com.apple.Logic"];
    defaults.kya_watchedApplicationBundleIdentifiers = input;
    XCTAssertEqualObjects(defaults.kya_watchedApplicationBundleIdentifiers, input);
}

- (void)testWatchedAppBundleIDs_dropsInvalidEntries
{
    Auto defaults = self.defaults;
    [defaults setObject:@[@"com.apple.FinalCut", @"", @0, @YES, @"com.apple.Logic"]
                 forKey:KYAUserDefaultsKeyWatchedApplicationBundleIdentifiers];

    NSArray *result = defaults.kya_watchedApplicationBundleIdentifiers;
    XCTAssertEqualObjects(result, (@[@"com.apple.FinalCut", @"com.apple.Logic"]));
}

- (void)testWatchedAppBundleIDs_emptyArrayClearsKey
{
    Auto defaults = self.defaults;
    defaults.kya_watchedApplicationBundleIdentifiers = @[@"com.example"];
    defaults.kya_watchedApplicationBundleIdentifiers = @[];
    XCTAssertNil(defaults.kya_watchedApplicationBundleIdentifiers);
}

- (void)testBatteryCapacityThreshold
{
    Auto defaults = self.defaults;
    Auto key = KYAUserDefaultsKeyBatteryCapacityThreshold;
    
    defaults.kya_batteryCapacityThreshold = 90.0f;
    XCTAssertEqual([defaults kya_batteryCapacityThreshold], 90.0f);
    XCTAssertEqual([defaults floatForKey:key], 90.0f);
    
    [defaults setFloat:50.0f forKey:key];
    XCTAssertEqual([defaults kya_batteryCapacityThreshold], 50.0f);
    
    // Below 10%
    defaults.kya_batteryCapacityThreshold = 0.1f;
    XCTAssertEqual([defaults kya_batteryCapacityThreshold], 10.0f);
    XCTAssertEqual([defaults floatForKey:key], 0.1f); // TODO: Maybe the setter should catch this?
    
    [defaults setFloat:0.2f forKey:key];
    XCTAssertEqual([defaults kya_batteryCapacityThreshold], 10.0f);
    
    // Over 100%
    defaults.kya_batteryCapacityThreshold = 512.0f; // TODO: Maybe this should be invalid?
    XCTAssertEqual([defaults kya_batteryCapacityThreshold], 512.0f);
    XCTAssertEqual([defaults floatForKey:key], 512.0f);
}

#pragma mark - Switched-off Watched Items

- (void)clearWatchedItemKeys
{
    for(NSString *key in @[KYAUserDefaultsKeyWatchedWiFiSSIDs,
                           KYAUserDefaultsKeyWatchedApplicationBundleIdentifiers,
                           KYAUserDefaultsKeyDownloadDirectories,
                           KYAUserDefaultsKeyScheduleWindows,
                           KYAUserDefaultsKeyDisabledWatchedWiFiSSIDs,
                           KYAUserDefaultsKeyDisabledWatchedApplicationBundleIdentifiers,
                           KYAUserDefaultsKeyDisabledDownloadDirectories])
    {
        [self.defaults removeObjectForKey:key];
    }
}

- (void)testEnabledWatchedWiFiSSIDs_excludesSwitchedOffEntries
{
    [self clearWatchedItemKeys];
    Auto defaults = self.defaults;
    defaults.kya_watchedWiFiSSIDs = @[@"Office", @"Home", @"Cafe"];
    defaults.kya_disabledWatchedWiFiSSIDs = @[@"Home"];
    XCTAssertEqualObjects(defaults.kya_enabledWatchedWiFiSSIDs, (@[@"Office", @"Cafe"]));
    // The full list is untouched.
    XCTAssertEqualObjects(defaults.kya_watchedWiFiSSIDs, (@[@"Office", @"Home", @"Cafe"]));
}

- (void)testEnabledWatchedWiFiSSIDs_nilWhenEverythingSwitchedOff
{
    [self clearWatchedItemKeys];
    Auto defaults = self.defaults;
    defaults.kya_watchedWiFiSSIDs = @[@"Office"];
    defaults.kya_disabledWatchedWiFiSSIDs = @[@"Office"];
    XCTAssertNil(defaults.kya_enabledWatchedWiFiSSIDs);
}

- (void)testEnabledWatchedWiFiSSIDs_matchesExactly
{
    [self clearWatchedItemKeys];
    Auto defaults = self.defaults;
    defaults.kya_watchedWiFiSSIDs = @[@"Office ", @"office"];
    defaults.kya_disabledWatchedWiFiSSIDs = @[@"Office"];
    XCTAssertEqualObjects(defaults.kya_enabledWatchedWiFiSSIDs, (@[@"Office ", @"office"]));
}

- (void)testEnabledWatchedApplications_excludesSwitchedOffEntries
{
    [self clearWatchedItemKeys];
    Auto defaults = self.defaults;
    defaults.kya_watchedApplicationBundleIdentifiers = @[@"com.apple.Logic", @"com.apple.FinalCut"];
    defaults.kya_disabledWatchedApplicationBundleIdentifiers = @[@"com.apple.Logic"];
    XCTAssertEqualObjects(defaults.kya_enabledWatchedApplicationBundleIdentifiers, (@[@"com.apple.FinalCut"]));
}

- (void)testEnabledDownloadDirectories_distinguishesUnsetFromAllOff
{
    [self clearWatchedItemKeys];
    Auto defaults = self.defaults;
    // Unset: callers fall back to ~/Downloads.
    XCTAssertNil(defaults.kya_enabledDownloadDirectories);

    defaults.kya_downloadDirectories = @[@"~/Downloads", @"~/Torrents"];
    defaults.kya_disabledDownloadDirectories = @[@"~/Torrents"];
    XCTAssertEqualObjects(defaults.kya_enabledDownloadDirectories, (@[@"~/Downloads"]));

    // Every folder off: an empty list, not the fallback.
    defaults.kya_disabledDownloadDirectories = @[@"~/Downloads", @"~/Torrents"];
    XCTAssertEqualObjects(defaults.kya_enabledDownloadDirectories, (@[]));
}

- (void)testEnabledScheduleWindows_skipsWindowsSwitchedOff
{
    [self clearWatchedItemKeys];
    Auto defaults = self.defaults;
    NSDictionary *on = @{ KYAScheduleWindowKeyWeekdays: @[@2], KYAScheduleWindowKeyStartMinutes: @540, KYAScheduleWindowKeyEndMinutes: @1080 };
    NSDictionary *explicitOn = @{ KYAScheduleWindowKeyWeekdays: @[@3], KYAScheduleWindowKeyStartMinutes: @540, KYAScheduleWindowKeyEndMinutes: @1080, KYAScheduleWindowKeyEnabled: @YES };
    NSDictionary *off = @{ KYAScheduleWindowKeyWeekdays: @[@4], KYAScheduleWindowKeyStartMinutes: @540, KYAScheduleWindowKeyEndMinutes: @1080, KYAScheduleWindowKeyEnabled: @NO };
    defaults.kya_scheduleWindows = @[on, explicitOn, off];
    XCTAssertEqualObjects(defaults.kya_enabledScheduleWindows, (@[on, explicitOn]));

    defaults.kya_scheduleWindows = @[off];
    XCTAssertNil(defaults.kya_enabledScheduleWindows);
}

- (void)testDisabledLists_emptyArrayClearsKey
{
    [self clearWatchedItemKeys];
    Auto defaults = self.defaults;
    defaults.kya_disabledWatchedWiFiSSIDs = @[@"x"];
    defaults.kya_disabledWatchedWiFiSSIDs = @[];
    XCTAssertNil([defaults objectForKey:KYAUserDefaultsKeyDisabledWatchedWiFiSSIDs]);
}

@end
