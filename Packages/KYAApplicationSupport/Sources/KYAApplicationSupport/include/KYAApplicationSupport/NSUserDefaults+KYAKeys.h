//
//  NSUserDefaults+KYAKeys.h
//  KYAApplicationSupport
//
//  Created by Marcel Dierkes on 25.10.15.
//  Copyright © 2015 Marcel Dierkes. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <KYACommon/KYAExport.h>

NS_ASSUME_NONNULL_BEGIN

// User Default Keys
KYA_EXPORT NSString * const KYAUserDefaultsKeyActivateOnLaunch;
KYA_EXPORT NSString * const KYAUserDefaultsKeyAllowDisplaySleep;
KYA_EXPORT NSString * const KYAUserDefaultsKeyPreventDiskSleepEnabled;
KYA_EXPORT NSString * const KYAUserDefaultsKeyActivateOnExternalDisplayConnectedEnabled;
KYA_EXPORT NSString * const KYAUserDefaultsKeyDeactivateOnUserSwitchEnabled;
KYA_EXPORT NSString * const KYAUserDefaultsKeyMenuBarIconHighlightDisabled;
KYA_EXPORT NSString * const KYAUserDefaultsKeyMenuBarCountdownDisabled;
KYA_EXPORT NSString * const KYAUserDefaultsKeyIsQuitOnTimerExpirationEnabled;
KYA_EXPORT NSString * const KYAUserDefaultsKeyBatteryCapacityThresholdEnabled;
KYA_EXPORT NSString * const KYAUserDefaultsKeyBatteryCapacityThreshold;
KYA_EXPORT NSString * const KYAUserDefaultsKeyLowPowerModeMonitoringEnabled;
KYA_EXPORT NSString * const KYAUserDefaultsKeyDeactivateOnFullChargeEnabled;
KYA_EXPORT NSString * const KYAUserDefaultsKeyActivateOnACPowerEnabled;
KYA_EXPORT NSString * const KYAUserDefaultsKeyPreReleaseUpdatesEnabled;
KYA_EXPORT NSString * const KYAUserDefaultsKeyDriveAliveEnabled;
KYA_EXPORT NSString * const KYAUserDefaultsKeyWatchedWiFiSSIDs;
KYA_EXPORT NSString * const KYAUserDefaultsKeyWatchedApplicationBundleIdentifiers;
KYA_EXPORT NSString * const KYAUserDefaultsKeyScheduleEnabled;
KYA_EXPORT NSString * const KYAUserDefaultsKeyScheduleWindows;
KYA_EXPORT NSString * const KYAUserDefaultsKeyDownloadInProgressActivationEnabled;
KYA_EXPORT NSString * const KYAUserDefaultsKeyDownloadDirectories;
KYA_EXPORT NSString * const KYAUserDefaultsKeyDisabledWatchedWiFiSSIDs;
KYA_EXPORT NSString * const KYAUserDefaultsKeyDisabledWatchedApplicationBundleIdentifiers;
KYA_EXPORT NSString * const KYAUserDefaultsKeyDisabledDownloadDirectories;
KYA_EXPORT NSString * const KYAUserDefaultsKeyMouseJigglerEnabled;
KYA_EXPORT NSString * const KYAUserDefaultsKeyActivateOnExternalAudioOutputEnabled;
KYA_EXPORT NSString * const KYAUserDefaultsKeyActivateOnCPULoadEnabled;
KYA_EXPORT NSString * const KYAUserDefaultsKeyCPULoadActivationThreshold;

@interface NSUserDefaults (KYAKeys)

/// Returns YES if the sleep wake timer should be activated on app launch.
@property (nonatomic, getter = kya_isActivatedOnLaunch) BOOL kya_activateOnLaunch;

/// Returns YES if the app should allow the display to sleep while still keeping
/// the system awake. This exposes the `caffeinate -i` command.
@property (nonatomic, getter = kya_shouldAllowDisplaySleep) BOOL kya_allowDisplaySleep;

/// Returns YES if the app should prevent the disk from idling while a session
/// is active. This exposes the `caffeinate -m` command.
@property (nonatomic, getter = kya_isPreventDiskSleepEnabled) BOOL kya_preventDiskSleepEnabled;

/// Returns YES if the menu bar icon should not be highlighted on left and right click.
@property (nonatomic, getter = kya_isMenuBarIconHighlightDisabled) BOOL kya_menuBarIconHighlightDisabled;

/// Returns YES if the remaining-time countdown next to the menu bar icon
/// should be hidden. The countdown is shown by default (key absent / NO);
/// setting this to YES restores the upstream icon-only look.
///
/// Until a settings UI lands, configure via:
///     defaults write info.marcel-dierkes.KeepingYouAwake \
///         info.marcel-dierkes.KeepingYouAwake.MenuBarCountdownDisabled \
///         -bool YES
@property (nonatomic, getter = kya_isMenuBarCountdownDisabled) BOOL kya_menuBarCountdownDisabled;

/// Returns YES if the sleep wake timer should deactivate below a defined battery capacity threshold.
@property (nonatomic, getter = kya_isBatteryCapacityThresholdEnabled) BOOL kya_batteryCapacityThresholdEnabled;

/// A battery capacity threshold.
///
/// If the user defaults value is below 10.0, 10.0 will be returned.
@property (nonatomic) CGFloat kya_batteryCapacityThreshold;

/// Returns YES if the sleep wake timer should deactivate when Low Power Mode is enabled.
@property (nonatomic, getter=kya_isLowPowerModeMonitoringEnabled) BOOL kya_lowPowerModeMonitoringEnabled;

/// Returns YES if the sleep wake timer should deactivate when the battery
/// reaches a fully charged state.
@property (nonatomic, getter=kya_isDeactivateOnFullChargeEnabled) BOOL kya_deactivateOnFullChargeEnabled;
/// Returns YES if the sleep wake timer should activate while the Mac is
/// connected to external power, and deactivate when running on battery.
/// On desktop Macs without a battery the option is a no-op (the state
/// is reported as `KYADeviceBatteryStateUnknown`).
@property (nonatomic, getter=kya_isActivateOnACPowerEnabled) BOOL kya_activateOnACPowerEnabled;

/// Returns YES if Sparkle should check for pre-release updates.
@property (nonatomic, getter = kya_arePreReleaseUpdatesEnabled) BOOL kya_preReleaseUpdatesEnabled;

/// Returns YES if the app should quit when the sleep wake timer expires.
@property (nonatomic, getter=kya_isQuitOnTimerExpirationEnabled) BOOL kya_quitOnTimerExpirationEnabled;

/// Returns YES if the app should activate when external display is connected.
@property (nonatomic, getter=kya_isActivateOnExternalDisplayConnectedEnabled) BOOL kya_activateOnExternalDisplayConnectedEnabled;

/// Returns YES if the app should deactivate when the user account is switched.
@property (nonatomic, getter=kya_isDeactivateOnUserSwitchEnabled) BOOL kya_deactivateOnUserSwitchEnabled;

/// Returns YES if the app should periodically touch a small temporary
/// file while the sleep wake timer is active, to keep external storage
/// devices spinning. Equivalent to Amphetamine's "Drive Alive".
@property (nonatomic, getter=kya_isDriveAliveEnabled) BOOL kya_driveAliveEnabled;

/// Wi-Fi SSIDs that should drive activation. While the joined network's
/// SSID matches one of these (case-insensitive) the sleep wake timer is
/// activated indefinitely; activation ends when the Mac switches away
/// from all of them.
///
/// Reading the SSID on macOS 14+ requires Location authorization for
/// the host app; without it the feature is inactive.
///
/// Until a settings UI lands, configure via:
///     defaults write info.marcel-dierkes.KeepingYouAwake \
///         info.marcel-dierkes.KeepingYouAwake.WatchedWiFiSSIDs \
///         -array Office-WiFi Home-5G
@property (copy, nonatomic, nullable) NSArray<NSString *> *kya_watchedWiFiSSIDs;

/// The bundle identifiers of applications whose run state should drive
/// activation. The sleep wake timer is activated indefinitely while any
/// of the listed apps is running and deactivated when the last one
/// terminates. Empty array or nil disables the feature.
///
/// Stored as a plain array of strings so it can be edited with
/// `defaults write …` or via a future settings UI without a custom
/// value transformer.
///
/// Until a settings UI lands, configure via:
///     defaults write info.marcel-dierkes.KeepingYouAwake \
///         info.marcel-dierkes.KeepingYouAwake.WatchedApplicationBundleIdentifiers \
///         -array com.apple.FinalCut com.apple.Logic
@property (copy, nonatomic, nullable) NSArray<NSString *> *kya_watchedApplicationBundleIdentifiers;

/// Returns YES if the schedule trigger is enabled. The schedule still
/// requires `kya_scheduleWindows` to be non-empty to do anything.
@property (nonatomic, getter=kya_isScheduleEnabled) BOOL kya_scheduleEnabled;

/// Time-of-day windows during which the sleep wake timer should be
/// active. Each window is a dictionary with three keys:
/// - `weekdays`: array of NSNumber 1..7 (1 = Sunday, per NSCalendar).
/// - `startMinutes`: minutes since local midnight, 0..1439.
/// - `endMinutes`: minutes since local midnight, 0..1439. May be less
///   than `startMinutes`, in which case the window wraps past midnight
///   into the next day.
///
/// Until a settings UI lands, configure via:
///     defaults write info.marcel-dierkes.KeepingYouAwake \
///         info.marcel-dierkes.KeepingYouAwake.ScheduleWindows \
///         -array '<dict><key>weekdays</key><array>...</array>...</dict>'
///
/// or via PlistBuddy for clarity.
@property (copy, nonatomic, nullable) NSArray<NSDictionary<NSString *, id> *> *kya_scheduleWindows;

/// Returns YES if KYA should auto-activate while a download is in
/// progress (browser writes to a suffixed temporary file).
@property (nonatomic, getter=kya_isDownloadInProgressActivationEnabled) BOOL kya_downloadInProgressActivationEnabled;

/// Directories scanned for in-progress download files. Each entry is a
/// path string (`~` is expanded). Defaults to `["~/Downloads"]` when
/// the key is absent.
@property (copy, nonatomic, nullable) NSArray<NSString *> *kya_downloadDirectories;

/// Entries of `kya_watchedWiFiSSIDs`, `kya_watchedApplicationBundleIdentifiers`
/// and `kya_downloadDirectories` that stay in the list but are switched off
/// (Watched Items checkboxes). Matched the way each trigger compares
/// entries: SSIDs and bundle identifiers ignoring case (whitespace still
/// counts), folder paths exactly. A schedule window
/// is switched off with `KYAScheduleWindowKeyEnabled` = NO instead.
@property (copy, nonatomic, nullable) NSArray<NSString *> *kya_disabledWatchedWiFiSSIDs;
@property (copy, nonatomic, nullable) NSArray<NSString *> *kya_disabledWatchedApplicationBundleIdentifiers;
@property (copy, nonatomic, nullable) NSArray<NSString *> *kya_disabledDownloadDirectories;

/// The switched-on entries, which are what the triggers act on. `nil`
/// when none are on.
@property (nonatomic, readonly, nullable) NSArray<NSString *> *kya_enabledWatchedWiFiSSIDs;
@property (nonatomic, readonly, nullable) NSArray<NSString *> *kya_enabledWatchedApplicationBundleIdentifiers;
@property (nonatomic, readonly, nullable) NSArray<NSDictionary<NSString *, id> *> *kya_enabledScheduleWindows;
/// `nil` only while `kya_downloadDirectories` is unset (callers fall back
/// to ~/Downloads); an empty array when every configured folder is off.
@property (nonatomic, readonly, nullable) NSArray<NSString *> *kya_enabledDownloadDirectories;

/// Returns YES if KYA should periodically nudge the cursor by 1px while
/// a session is active. Useful for keeping IM apps that key off system
/// idle time (rather than caffeinate's assertions) from marking the
/// user as "Away".
///
/// Off by default. Requires Accessibility permission for KYA;
/// without it, `CGEventPost` silently no-ops.
@property (nonatomic, getter=kya_isMouseJigglerEnabled) BOOL kya_mouseJigglerEnabled;

/// Returns YES if the sleep wake timer should auto-activate while the
/// system's default audio output is anything other than the built-in
/// speakers (Bluetooth headphones, USB DAC, HDMI display, AirPods, …).
/// Useful for "don't sleep while I'm listening to music".
@property (nonatomic, getter=kya_isActivateOnExternalAudioOutputEnabled) BOOL kya_activateOnExternalAudioOutputEnabled;

/// Returns YES if the sleep wake timer should auto-activate while
/// CPU load stays sustained above `kya_cpuLoadActivationThreshold`.
/// Useful for long builds, video encodes, scientific computations
/// where the user walked away but doesn't want the box to sleep
/// mid-job.
@property (nonatomic, getter=kya_isActivateOnCPULoadEnabled) BOOL kya_activateOnCPULoadEnabled;

/// CPU load percentage above which the trigger fires (0..100).
/// Defaults to 50 when the key is absent. Anything below 1 is clamped
/// to 1; anything above 99 is clamped to 99.
@property (nonatomic) double kya_cpuLoadActivationThreshold;

@end

NS_ASSUME_NONNULL_END
