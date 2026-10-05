//
//  KYAAppController.m
//  KeepingYouAwake
//
//  Created by Marcel Dierkes on 17.10.14.
//  Copyright (c) 2014 Marcel Dierkes. All rights reserved.
//

#import "KYAAppController.h"
#import "KYAActivationSource.h"
#import "KYAActivationOwnership.h"
#import "KYAWatchedApplications.h"
#import <KYACommon/KYACommon.h>
#import "KYALocalizedStrings.h"
#import "KYAMainMenu.h"
#import "KYABatteryCapacityThreshold.h"
#import "KYAActivationDurationsMenuController.h"
#import "KYAActivationUserNotification.h"
#import "KYADriveAliveTimer.h"
@import CoreLocation;

// Deprecated!
#define KYA_MINUTES(m) (m * 60.0f)
#define KYA_HOURS(h) (h * 3600.0f)

@interface KYAAppController () <KYAStatusItemControllerDataSource, KYAStatusItemControllerDelegate, KYAActivationDurationsMenuControllerDelegate, KYASleepWakeTimerDelegate, KYAScheduleMonitorDelegate, KYADownloadActivityMonitorDelegate, KYAAudioOutputMonitorDelegate, KYACPULoadMonitorDelegate, CLLocationManagerDelegate>
@property (nonatomic, readwrite) KYASleepWakeTimer *sleepWakeTimer;
@property (nonatomic, readwrite) KYAStatusItemController *statusItemController;
@property (nonatomic) KYAActivationDurationsMenuController *menuController;

@property (nonatomic) NSTimeInterval workspaceScheduledTimeInterval;
// Source of the session suspended on fast user switching, so a trigger
// session resumes as a trigger session (and its trigger can still end it).
@property (nonatomic) KYAActivationSource workspaceScheduledSource;

// Battery Status
@property (nonatomic, direct, getter=isBatteryOverrideEnabled) BOOL batteryOverrideEnabled;

// Drive Alive
@property (nonatomic, nullable) KYADriveAliveTimer *driveAliveTimer;
// Continuous AC power observer (separate from activation-lifecycle monitoring)
@property (nonatomic, nullable) id acPowerObserver;
// Last observed AC state, used to gate the activate-on-AC trigger on
// transitions (unplugged → AC) instead of every battery notification.
@property (nonatomic) BOOL acTriggerWasOnAC;

// Incremented on every activation. A session's completion block captures
// its value, so the asynchronous end of a replaced session can tell it is
// no longer the current one — even if the replacement already ended too.
@property (nonatomic) NSUInteger sessionGeneration;

// Who started the active session. Holds the activation source for the
// running timer and naturally encodes the invariant "a feature trigger
// never deactivates a user-initiated session" via
// -terminateIfOwnedBySource:. See KYAActivationOwnership.h.
@property (nonatomic) KYAActivationOwnership *ownership;

// Schedule trigger monitor — driven by ScheduleEnabled / ScheduleWindows
// defaults keys. nil while the trigger is disabled.
@property (nonatomic, nullable) KYAScheduleMonitor *scheduleMonitor;

// Download-in-progress activity monitor — driven by the
// DownloadInProgressActivationEnabled / DownloadDirectories defaults.
@property (nonatomic, nullable) KYADownloadActivityMonitor *downloadActivityMonitor;

// Mouse jiggler — periodically nudges the cursor while a session is
// active so external systems that key off system idle time stay
// "awake" too. Off by default.
@property (nonatomic, nullable) KYAMouseJiggler *mouseJiggler;
// External-audio-output trigger — driven by ActivateOnExternalAudioOutputEnabled.
@property (nonatomic, nullable) KYAAudioOutputMonitor *audioOutputMonitor;

// CPU load trigger.
@property (nonatomic, nullable) KYACPULoadMonitor *cpuLoadMonitor;

// Watched Wi-Fi SSID / application lists as last reconciled, so a
// defaults change only re-evaluates the trigger when its list changed.
@property (copy, nonatomic, nullable) NSArray<NSString *> *reconciledWatchedSSIDs;
@property (copy, nonatomic, nullable) NSArray<NSString *> *reconciledWatchedBundleIdentifiers;
@property (nonatomic) BOOL hasReconciledWatchedSSIDs;
@property (nonatomic) BOOL hasReconciledWatchedBundleIdentifiers;
// Requests the Location authorization macOS requires to read the SSID.
@property (nonatomic, nullable) CLLocationManager *locationManager;

// Menu
@property (nonatomic) NSMenu *menu;
@end

@implementation KYAAppController

#pragma mark - Life Cycle

- (instancetype)init
{
    self = [super init];
    if(self)
    {
        _ownership = [[KYAActivationOwnership alloc] init];

        // Sessions left open by a crashed or killed previous process would
        // otherwise read as active to the CLI / MCP server. Must run before
        // the first activation below (activate-on-launch).
        [KYAActivityLogger.sharedLogger closeDanglingEntriesWithReason:KYAActivityLogEndedReasonAppTerminated];

        [self configureStatusItemController];
        [self configureSleepWakeTimer];
        [self configureEventHandler];
        [self configureUserNotificationCenter];
        [self configureMainMenu];

        Auto center = NSNotificationCenter.defaultCenter;
        [center addObserver:self
                   selector:@selector(applicationWillFinishLaunching:)
                       name:NSApplicationWillFinishLaunchingNotification
                     object:nil];
        [center addObserver:self
                   selector:@selector(applicationDidChangeScreenParameters:)
                       name:NSApplicationDidChangeScreenParametersNotification
                     object:nil];
        [center addObserver:self
                   selector:@selector(batteryCapacityThresholdDidChange:)
                       name:kKYABatteryCapacityThresholdDidChangeNotification
                     object:nil];
        [center addObserver:self
                   selector:@selector(applicationWillTerminate:)
                       name:NSApplicationWillTerminateNotification
                     object:nil];
        
        [self registerForWorkspaceSessionNotifications];
        [self registerForWiFiSSIDNotifications];
        [self reconcileWatchedWiFiSSIDTrigger];
        [self configureACPowerTrigger];
        [self registerForWatchedApplicationNotifications];
        [self reconcileWatchedApplicationTrigger];

        [self reconcileScheduleTrigger];
        [self reconcileDownloadActivityTrigger];
        [self reconcileAudioOutputTrigger];
        [self reconcileCPULoadTrigger];

        // Reconcile the AC-power trigger when the user toggles the
        // setting at runtime — without this the trigger only honours
        // the value that was set at app launch.
        [center addObserver:self
                   selector:@selector(userDefaultsDidChange:)
                       name:NSUserDefaultsDidChangeNotification
                     object:NSUserDefaults.standardUserDefaults];
    }
    return self;
}

- (void)dealloc
{
    Auto center = NSNotificationCenter.defaultCenter;
    [center removeObserver:self name:NSApplicationDidFinishLaunchingNotification object:nil];
    [center removeObserver:self name:NSApplicationDidChangeScreenParametersNotification object:nil];
    [center removeObserver:self name:kKYABatteryCapacityThresholdDidChangeNotification object:nil];
    [center removeObserver:self name:NSApplicationWillTerminateNotification object:nil];
    [center removeObserver:self name:NSUserDefaultsDidChangeNotification object:NSUserDefaults.standardUserDefaults];

    [self unregisterFromWorkspaceSessionNotifications];
    [self unregisterFromWiFiSSIDNotifications];
    [self unregisterFromWatchedApplicationNotifications];
    [self teardownACPowerTrigger];
}

- (void)applicationWillTerminate:(NSNotification *)notification
{
    // The sleep-wake timer's completion runs asynchronously and never on
    // quit, so close the open activity-log entry here — synchronously,
    // since the process exits right after this notification. No-op when
    // no session is open.
    [KYAActivityLogger.sharedLogger recordActivationEndedSynchronouslyWithReason:KYAActivityLogEndedReasonAppTerminated];
}

- (void)userDefaultsDidChange:(NSNotification *)notification
{
    [self reconcileWatchedWiFiSSIDTrigger];
    [self reconcileWatchedApplicationTrigger];
    [self reconcileACPowerTrigger];
    [self reconcileScheduleTrigger];
    [self reconcileDownloadActivityTrigger];
    [self reconcileAudioOutputTrigger];
    [self reconcileCPULoadTrigger];
}

#pragma mark - CPU Load Trigger

- (void)reconcileCPULoadTrigger
{
    Auto defaults = NSUserDefaults.standardUserDefaults;
    BOOL enabled = [defaults kya_isActivateOnCPULoadEnabled];

    if(!enabled)
    {
        [self.cpuLoadMonitor stop];
        self.cpuLoadMonitor = nil;
        // Nothing can end a CPU-load session once the monitor is gone.
        [self terminateTimerIfOwnedBySource:KYAActivationSourceCPULoad];
        return;
    }

    if(self.cpuLoadMonitor == nil)
    {
        Auto monitor = [KYACPULoadMonitor new];
        monitor.delegate = self;
        self.cpuLoadMonitor = monitor;
    }
    self.cpuLoadMonitor.thresholdPercent = defaults.kya_cpuLoadActivationThreshold;
    if(![self.cpuLoadMonitor isRunning])
    {
        [self.cpuLoadMonitor start];
    }
}

#pragma mark - KYACPULoadMonitorDelegate

- (void)cpuLoadMonitorDidCrossAboveThreshold:(KYACPULoadMonitor *)monitor
{
    if([self.sleepWakeTimer isScheduled]) { return; }
    [self activateTimerWithTimeInterval:KYASleepWakeTimeIntervalIndefinite
                                 source:KYAActivationSourceCPULoad];
}

- (void)cpuLoadMonitorDidFallBelowThreshold:(KYACPULoadMonitor *)monitor
{
    [self terminateTimerIfOwnedBySource:KYAActivationSourceCPULoad];
}

#pragma mark - External Audio Output Trigger

- (void)reconcileAudioOutputTrigger
{
    BOOL enabled = [NSUserDefaults.standardUserDefaults kya_isActivateOnExternalAudioOutputEnabled];

    if(!enabled)
    {
        [self.audioOutputMonitor stop];
        self.audioOutputMonitor = nil;
        [self terminateTimerIfOwnedBySource:KYAActivationSourceAudioOutput];
        return;
    }

    if(self.audioOutputMonitor == nil)
    {
        Auto monitor = [KYAAudioOutputMonitor new];
        monitor.delegate = self;
        self.audioOutputMonitor = monitor;
    }
    if(![self.audioOutputMonitor isRunning])
    {
        [self.audioOutputMonitor start];
    }
}

#pragma mark - KYAAudioOutputMonitorDelegate

- (void)audioOutputMonitorDidStartUsingExternalDevice:(KYAAudioOutputMonitor *)monitor
{
    if([self.sleepWakeTimer isScheduled]) { return; }
    [self activateTimerWithTimeInterval:KYASleepWakeTimeIntervalIndefinite
                                 source:KYAActivationSourceAudioOutput];
}

- (void)audioOutputMonitorDidReturnToBuiltInDevice:(KYAAudioOutputMonitor *)monitor
{
    [self terminateTimerIfOwnedBySource:KYAActivationSourceAudioOutput];
}

#pragma mark - Schedule Trigger

- (void)reconcileScheduleTrigger
{
    Auto defaults = NSUserDefaults.standardUserDefaults;
    BOOL enabled = [defaults kya_isScheduleEnabled];
    NSArray *windows = defaults.kya_scheduleWindows;

    if(!enabled || windows.count == 0)
    {
        [self.scheduleMonitor stop];
        self.scheduleMonitor = nil;
        [self terminateTimerIfOwnedBySource:KYAActivationSourceSchedule];
        return;
    }

    if(self.scheduleMonitor == nil)
    {
        Auto monitor = [KYAScheduleMonitor new];
        monitor.delegate = self;
        self.scheduleMonitor = monitor;
    }
    [self.scheduleMonitor setWindows:windows];
    if(![self.scheduleMonitor isRunning])
    {
        [self.scheduleMonitor start];
    }
}

#pragma mark - KYAScheduleMonitorDelegate

- (void)scheduleMonitorDidEnterWindow:(KYAScheduleMonitor *)monitor
{
    if([self.sleepWakeTimer isScheduled]) { return; }
    [self activateTimerWithTimeInterval:KYASleepWakeTimeIntervalIndefinite
                                 source:KYAActivationSourceSchedule];
}

- (void)scheduleMonitorDidLeaveWindow:(KYAScheduleMonitor *)monitor
{
    [self terminateTimerIfOwnedBySource:KYAActivationSourceSchedule];
}

#pragma mark - Download Activity Trigger

- (void)reconcileDownloadActivityTrigger
{
    Auto defaults = NSUserDefaults.standardUserDefaults;
    BOOL enabled = [defaults kya_isDownloadInProgressActivationEnabled];

    if(!enabled)
    {
        [self.downloadActivityMonitor stop];
        self.downloadActivityMonitor = nil;
        [self terminateTimerIfOwnedBySource:KYAActivationSourceDownload];
        return;
    }

    if(self.downloadActivityMonitor == nil)
    {
        Auto monitor = [KYADownloadActivityMonitor new];
        monitor.delegate = self;
        self.downloadActivityMonitor = monitor;
    }
    NSArray<NSString *> *dirs = defaults.kya_downloadDirectories ?: @[@"~/Downloads"];
    [self.downloadActivityMonitor setDirectories:dirs];
    if(![self.downloadActivityMonitor isRunning])
    {
        [self.downloadActivityMonitor start];
    }
}

#pragma mark - KYADownloadActivityMonitorDelegate

- (void)downloadActivityMonitorDidStartDownloads:(KYADownloadActivityMonitor *)monitor
{
    if([self.sleepWakeTimer isScheduled]) { return; }
    [self activateTimerWithTimeInterval:KYASleepWakeTimeIntervalIndefinite
                                 source:KYAActivationSourceDownload];
}

- (void)downloadActivityMonitorDidFinishDownloads:(KYADownloadActivityMonitor *)monitor
{
    [self terminateTimerIfOwnedBySource:KYAActivationSourceDownload];
}

- (void)reconcileACPowerTrigger
{
    BOOL enabled = [NSUserDefaults.standardUserDefaults kya_isActivateOnACPowerEnabled];
    BOOL active = (self.acPowerObserver != nil);
    if(enabled && !active)
    {
        [self configureACPowerTrigger];
    }
    else if(!enabled && active)
    {
        [self teardownACPowerTrigger];
        [self terminateTimerIfOwnedBySource:KYAActivationSourceACPower];
    }
}

#pragma mark - Main Menu

- (void)configureMainMenu
{
    Auto menuController = [KYAActivationDurationsMenuController new];
    menuController.delegate = self;
    self.menuController = menuController;
    
    self.menu = KYACreateMainMenuWithActivationDurationsSubMenu(menuController.menu);
}

#pragma mark - Status Item Controller

- (void)configureStatusItemController
{
    Auto statusItemController = [KYAStatusItemController new];
    statusItemController.dataSource = self;
    statusItemController.delegate = self;
    self.statusItemController = statusItemController;
}

#pragma mark - Sleep Wake Timer

- (void)configureSleepWakeTimer
{
    Auto sleepWakeTimer = [KYASleepWakeTimer new];
    sleepWakeTimer.delegate = self;
    self.sleepWakeTimer = sleepWakeTimer;
    
    // Activate on launch if needed
    if([NSUserDefaults.standardUserDefaults kya_isActivatedOnLaunch])
    {
        [self activateTimer];
    }
}

- (void)activateTimer
{
    [self activateTimerWithTimeInterval:self.defaultTimeInterval];
}

- (void)activateTimerWithTimeInterval:(NSTimeInterval)timeInterval
{
    [self activateTimerWithTimeInterval:timeInterval source:KYAActivationSourceUser];
}

- (void)activateTimerWithTimeInterval:(NSTimeInterval)timeInterval
                               source:(KYAActivationSource)source
{
    // Do not allow negative time intervals
    if(timeInterval < 0)
    {
        return;
    }

    // Replacing a running session: end it properly first. Scheduling over
    // it would orphan its caffeinate task and leave its log entry open.
    if([self.sleepWakeTimer isScheduled])
    {
        [self.ownership terminate];
        [self terminateTimerWithReason:KYAActivityLogEndedReasonUserCancelled];
    }

    Auto defaults = NSUserDefaults.standardUserDefaults;

    self.sessionGeneration += 1;
    NSUInteger generation = self.sessionGeneration;
    AutoWeak weakSelf = self;
    Auto timerCompletion = ^(BOOL cancelled) {
        Auto strongSelf = weakSelf;
        // Runs asynchronously on the main queue. When this session was
        // replaced (URL scheme, AppleScript, CLI, MCP or Shortcuts
        // "activate" while active), a newer session has started since:
        // ending this one must not tear down the newer one's side effects,
        // post "deactivated", log an expiry or quit the app.
        if(strongSelf == nil || generation != strongSelf.sessionGeneration) { return; }

        [strongSelf tearDownSessionSideEffects];

        // Post deactivation notification
        if(@available(macOS 11.0, *))
        {
            Auto notification = [[KYAActivationUserNotification alloc] initWithFireDate:nil
                                                                             activating:NO];
            [KYAUserNotificationCenter.sharedCenter postNotification:notification];
        }

        // Close the activity-log entry on natural expiration. The
        // cancelled-by-user/trigger path is already covered by
        // -terminateTimer; this branch handles the case where the
        // caffeinate child exited at its scheduled fireDate.
        if(cancelled == NO)
        {
            [[KYAActivityLogger sharedLogger] recordActivationEndedWithReason:KYAActivityLogEndedReasonExpired];
        }

        // Quit on timer expiration
        if(cancelled == NO && [defaults kya_isQuitOnTimerExpirationEnabled])
        {
            [NSApplication.sharedApplication terminate:nil];
        }
    };
    [self.ownership startWithSource:source];
    [self.sleepWakeTimer scheduleWithTimeInterval:timeInterval completion:timerCompletion];

    [[KYAActivityLogger sharedLogger] recordActivationStartedFromSource:KYAActivityLogStringForSource(source)
                                                      requestedDuration:(timeInterval == KYASleepWakeTimeIntervalIndefinite ? -1 : timeInterval)];

    // Post activation notification
    if(@available(macOS 11.0, *))
    {
        Auto fireDate = self.sleepWakeTimer.fireDate;
        Auto notification = [[KYAActivationUserNotification alloc] initWithFireDate:fireDate
                                                                         activating:YES];
        [KYAUserNotificationCenter.sharedCenter postNotification:notification];
    }
}

- (void)terminateTimer
{
    // Unconditional user/internal path. Clear ownership at the entry
    // point so -terminateTimerWithReason: stays purely about the
    // caffeinate-side teardown and activity-log write.
    [self.ownership terminate];
    [self terminateTimerWithReason:KYAActivityLogEndedReasonUserCancelled];
}

/// Caffeinate-side teardown + activity-log write. Does NOT touch
/// ownership state — every caller is required to clear ownership
/// itself before invoking this method, so ownership is cleared
/// exactly once at the entry point of each teardown path.
- (void)terminateTimerWithReason:(NSString *)reason
{
    [self disableBatteryOverride];

    BOOL wasScheduled = [self.sleepWakeTimer isScheduled];
    if(wasScheduled)
    {
        [self.sleepWakeTimer invalidate];
    }

    if(wasScheduled)
    {
        [[KYAActivityLogger sharedLogger] recordActivationEndedWithReason:reason];
    }
}

/// Terminate the timer only if the running session was started by the
/// given source. Used by feature triggers (watched-app, watched-SSID,
/// AC power) so that a feature signal can't kill a user-initiated
/// session that happened to be running at the same time.
- (void)terminateTimerIfOwnedBySource:(KYAActivationSource)source
{
    if([self.sleepWakeTimer isScheduled] == NO) { return; }
    // -terminateIfOwnedBySource: atomically checks the invariant and
    // clears ownership when it matches. -terminateTimerWithReason:
    // then performs the caffeinate-side teardown without re-touching
    // ownership state.
    if([self.ownership terminateIfOwnedBySource:source] == NO) { return; }
    [self terminateTimerWithReason:KYAActivityLogEndedReasonTriggerCancelled];
}

#pragma mark - Default Time Interval

- (NSTimeInterval)defaultTimeInterval
{
    return NSUserDefaults.standardUserDefaults.kya_defaultTimeInterval;
}

#pragma mark - Activate on Launch

- (IBAction)toggleActivateOnLaunch:(id)sender
{
    Auto defaults = NSUserDefaults.standardUserDefaults;
    defaults.kya_activateOnLaunch = ![defaults kya_isActivatedOnLaunch];
    [defaults synchronize];
}

#pragma mark - User Notification Center

- (void)configureUserNotificationCenter
{
    if(@available(macOS 11.0, *))
    {
        Auto center = KYAUserNotificationCenter.sharedCenter;
        [center requestAuthorizationIfUndetermined];
        [center clearAllDeliveredNotifications];
    }
}

#pragma mark - Device Power Monitoring

- (void)checkAndEnableBatteryOverride
{
    Auto batteryMonitor = KYADevice.currentDevice.batteryMonitor;
    CGFloat currentCapacity = batteryMonitor.currentCapacity;
    CGFloat threshold = NSUserDefaults.standardUserDefaults.kya_batteryCapacityThreshold;

    self.batteryOverrideEnabled = (currentCapacity <= threshold);
}

- (void)disableBatteryOverride
{
    self.batteryOverrideEnabled = NO;
}

- (void)deviceParameterDidChange:(NSNotification *)notification
{
    NSParameterAssert(notification);
    
    Auto device = (KYADevice *)notification.object;
    Auto defaults = NSUserDefaults.standardUserDefaults;
    
    Auto userInfo = notification.userInfo;
    Auto deviceParameter = (KYADeviceParameter)userInfo[KYADeviceParameterKey];
    if([deviceParameter isEqualToString:KYADeviceParameterBattery])
    {
        if([self.sleepWakeTimer isScheduled] == NO) { return; }

        if([defaults kya_isDeactivateOnFullChargeEnabled]
           && device.batteryMonitor.state == KYADeviceBatteryStateFull)
        {
            [self terminateTimer];
            return;
        }

        if([defaults kya_isBatteryCapacityThresholdEnabled] == NO) { return; }

        CGFloat threshold = defaults.kya_batteryCapacityThreshold;
        Auto capacity = device.batteryMonitor.currentCapacity;
        if((capacity <= threshold) && ![self isBatteryOverrideEnabled])
        {
            [self terminateTimer];
        }
    }
    else if([deviceParameter isEqualToString:KYADeviceParameterLowPowerMode])
    {
        if([defaults kya_isLowPowerModeMonitoringEnabled] == NO) { return; }
        
        if([device.lowPowerModeMonitor isLowPowerModeEnabled] && [self.sleepWakeTimer isScheduled])
        {
            [self terminateTimer];
        }
    }
}

- (void)enableDevicePowerMonitoring
{
    Auto device = KYADevice.currentDevice;
    Auto center = NSNotificationCenter.defaultCenter;
    Auto defaults = NSUserDefaults.standardUserDefaults;
    
    // Check battery overrides and register for capacity changes.
    [self checkAndEnableBatteryOverride];
    
    [center addObserver:self
               selector:@selector(deviceParameterDidChange:)
                   name:KYADeviceParameterDidChangeNotification
                 object:device];
    
    if([defaults kya_isBatteryCapacityThresholdEnabled]
       || [defaults kya_isDeactivateOnFullChargeEnabled]
       || [defaults kya_isActivateOnACPowerEnabled])
    {
        device.batteryMonitoringEnabled = YES;
    }
    if([defaults kya_isLowPowerModeMonitoringEnabled])
    {
        device.lowPowerModeMonitoringEnabled = YES;
    }
}

- (void)disableDevicePowerMonitoring
{
    Auto device = KYADevice.currentDevice;
    Auto center = NSNotificationCenter.defaultCenter;
    Auto defaults = NSUserDefaults.standardUserDefaults;

    [center removeObserver:self
                      name:KYADeviceParameterDidChangeNotification
                    object:device];

    // The AC-power trigger uses a block-based observer (unaffected by the
    // selector-based removal above) and needs the battery monitor to keep
    // emitting notifications, so leave the flag on while it is engaged.
    if([defaults kya_isActivateOnACPowerEnabled] == NO)
    {
        device.batteryMonitoringEnabled = NO;
    }
    device.lowPowerModeMonitoringEnabled = NO;
}

#pragma mark - AC Power Trigger

- (void)configureACPowerTrigger
{
    if([NSUserDefaults.standardUserDefaults kya_isActivateOnACPowerEnabled] == NO) { return; }

    Auto device = KYADevice.currentDevice;
    device.batteryMonitoringEnabled = YES;

    AutoWeak weakSelf = self;
    self.acPowerObserver = [NSNotificationCenter.defaultCenter
        addObserverForName:KYADeviceParameterDidChangeNotification
                    object:device
                     queue:NSOperationQueue.mainQueue
                usingBlock:^(NSNotification *note) {
        Auto userInfo = note.userInfo;
        Auto param = (KYADeviceParameter)userInfo[KYADeviceParameterKey];
        if(![param isEqualToString:KYADeviceParameterBattery]) { return; }
        [weakSelf evaluateACPowerState];
    }];

    [self evaluateACPowerState];
}

- (void)teardownACPowerTrigger
{
    if(self.acPowerObserver != nil)
    {
        [NSNotificationCenter.defaultCenter removeObserver:self.acPowerObserver];
        self.acPowerObserver = nil;
    }
    // Drop the cached state so the next configure starts fresh and
    // treats the first observation as a transition.
    self.acTriggerWasOnAC = NO;

    // We turned battery monitoring on for this feature in
    // configureACPowerTrigger; turn it off again unless another
    // feature still needs it. Both battery-capacity-threshold and
    // deactivate-on-full-charge are also consumers.
    Auto defaults = NSUserDefaults.standardUserDefaults;
    if([defaults kya_isBatteryCapacityThresholdEnabled] == NO
       && [defaults kya_isDeactivateOnFullChargeEnabled] == NO)
    {
        KYADevice.currentDevice.batteryMonitoringEnabled = NO;
    }
}

- (void)evaluateACPowerState
{
    if([NSUserDefaults.standardUserDefaults kya_isActivateOnACPowerEnabled] == NO) { return; }

    Auto state = KYADevice.currentDevice.batteryMonitor.state;
    // Desktop Macs / battery-less hosts: no signal to act on.
    if(state == KYADeviceBatteryStateUnknown) { return; }

    BOOL onAC = (state == KYADeviceBatteryStateCharging
                 || state == KYADeviceBatteryStateFull);
    BOOL wasOnAC = self.acTriggerWasOnAC;
    self.acTriggerWasOnAC = onAC;

    BOOL scheduled = [self.sleepWakeTimer isScheduled];

    // Act only on AC transitions, not every battery notification.
    // Without this, the trigger would re-activate the timer after a
    // user manually deactivated it while still on AC.
    if(onAC && !wasOnAC && !scheduled)
    {
        [self activateTimerWithTimeInterval:KYASleepWakeTimeIntervalIndefinite
                                     source:KYAActivationSourceACPower];
    }
    else if(!onAC && wasOnAC)
    {
        // Only end the session we started for the AC trigger; a
        // user-initiated timer running on AC keeps running when the
        // user unplugs.
        [self terminateTimerIfOwnedBySource:KYAActivationSourceACPower];
    }
}

#pragma mark - Battery Capacity Threshold Changes

- (void)batteryCapacityThresholdDidChange:(NSNotification *)notification
{
    if([self.sleepWakeTimer isScheduled])
    {
        [self terminateTimer];
    }
}

#pragma mark - Workspace Session Handling

- (void)registerForWorkspaceSessionNotifications
{
    Auto workspaceCenter = NSWorkspace.sharedWorkspace.notificationCenter;
    [workspaceCenter addObserver:self
                        selector:@selector(workspaceSessionDidBecomeActive:)
                            name:NSWorkspaceSessionDidBecomeActiveNotification
                          object:nil];
    [workspaceCenter addObserver:self
                        selector:@selector(workspaceSessionDidResignActive:)
                            name:NSWorkspaceSessionDidResignActiveNotification
                          object:nil];
}

- (void)unregisterFromWorkspaceSessionNotifications
{
    Auto workspaceCenter = NSWorkspace.sharedWorkspace.notificationCenter;
    [workspaceCenter removeObserver:self
                               name:NSWorkspaceSessionDidBecomeActiveNotification
                             object:nil];
    [workspaceCenter removeObserver:self
                               name:NSWorkspaceSessionDidResignActiveNotification
                             object:nil];
}

- (void)workspaceSessionDidBecomeActive:(NSNotification *)notification
{
    Auto defaults = NSUserDefaults.standardUserDefaults;
    if([defaults kya_isDeactivateOnUserSwitchEnabled] && self.workspaceScheduledTimeInterval >= 0)
    {
        [self activateTimerWithTimeInterval:self.workspaceScheduledTimeInterval
                                     source:self.workspaceScheduledSource];
        self.workspaceScheduledTimeInterval = -1;
        self.workspaceScheduledSource = KYAActivationSourceUser;
    }
}

- (void)workspaceSessionDidResignActive:(NSNotification *)notification
{
    Auto defaults = NSUserDefaults.standardUserDefaults;
    if([defaults kya_isDeactivateOnUserSwitchEnabled] && [self.sleepWakeTimer isScheduled])
    {
        self.workspaceScheduledTimeInterval = self.sleepWakeTimer.scheduledTimeInterval;
        self.workspaceScheduledSource = self.ownership.isActive ? self.ownership.source : KYAActivationSourceUser;
        [self terminateTimer];
    }
}

#pragma mark - Watched Wi-Fi SSID

- (void)registerForWiFiSSIDNotifications
{
    // Monitoring itself is started / stopped by
    // -reconcileWatchedWiFiSSIDTrigger as the watched list changes.
    Auto monitor = KYAWiFiMonitor.sharedMonitor;
    Auto center = NSNotificationCenter.defaultCenter;
    [center addObserver:self
               selector:@selector(watchedWiFiSSIDDidChange:)
                   name:KYAWiFiMonitorSSIDDidChangeNotification
                 object:monitor];
}

- (void)unregisterFromWiFiSSIDNotifications
{
    Auto center = NSNotificationCenter.defaultCenter;
    [center removeObserver:self
                      name:KYAWiFiMonitorSSIDDidChangeNotification
                    object:KYAWiFiMonitor.sharedMonitor];
    [KYAWiFiMonitor.sharedMonitor stopMonitoring];
}

/// Starts / stops Wi-Fi monitoring for the watched-SSID list and
/// re-evaluates the trigger, at launch and whenever the list changes
/// (Watched Items settings). Unrelated defaults changes are ignored so
/// they can't restart a session the user just ended.
- (void)reconcileWatchedWiFiSSIDTrigger
{
    Auto ssids = NSUserDefaults.standardUserDefaults.kya_watchedWiFiSSIDs;
    Auto previous = self.reconciledWatchedSSIDs;
    if(self.hasReconciledWatchedSSIDs && (ssids == previous || [ssids isEqualToArray:previous]))
    {
        return;
    }
    self.hasReconciledWatchedSSIDs = YES;
    self.reconciledWatchedSSIDs = ssids;

    Auto monitor = KYAWiFiMonitor.sharedMonitor;
    if(ssids.count == 0)
    {
        [monitor stopMonitoring];
        [self terminateTimerIfOwnedBySource:KYAActivationSourceWatchedSSID];
        return;
    }

    [self requestLocationAuthorizationIfNeeded];
    [monitor startMonitoring];
    [self watchedWiFiSSIDDidChange:nil];
}

/// macOS 14+ only exposes the SSID to apps with Location authorization.
- (void)requestLocationAuthorizationIfNeeded
{
    if(@available(macOS 10.15, *))
    {
        if(self.locationManager == nil)
        {
            // The delegate is told the current status right after
            // creation and on every change; see -locationManagerDidChangeAuthorization:.
            Auto manager = [CLLocationManager new];
            manager.delegate = self;
            self.locationManager = manager;
        }
        CLAuthorizationStatus status;
        if(@available(macOS 11.0, *))
        {
            status = self.locationManager.authorizationStatus;
        }
        else
        {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
            status = [CLLocationManager authorizationStatus];
#pragma clang diagnostic pop
        }
        if(status == kCLAuthorizationStatusNotDetermined)
        {
            [self.locationManager requestWhenInUseAuthorization];
        }
    }
}

#pragma mark - CLLocationManagerDelegate

- (void)locationManagerDidChangeAuthorization:(CLLocationManager *)manager
{
    // The SSID may have just become readable.
    [self watchedWiFiSSIDDidChange:nil];
}

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-implementations"
- (void)locationManager:(CLLocationManager *)manager didChangeAuthorizationStatus:(CLAuthorizationStatus)status
{
    // macOS 10.15: -locationManagerDidChangeAuthorization: is macOS 11+.
    if(@available(macOS 11.0, *)) { return; }
    [self watchedWiFiSSIDDidChange:nil];
}
#pragma clang diagnostic pop

- (void)watchedWiFiSSIDDidChange:(nullable NSNotification *)notification
{
    Auto ssids = NSUserDefaults.standardUserDefaults.kya_watchedWiFiSSIDs;
    if(ssids.count == 0) { return; }
    BOOL onWatchedNetwork = [KYAWiFiMonitor.sharedMonitor isJoinedNetworkAmongSSIDs:ssids];

    if(onWatchedNetwork)
    {
        // Joining a watched network only starts a new indefinite session
        // if no other session is running. Existing sessions (user manual
        // duration, watched-app trigger, etc.) are left alone — promoting
        // them to indefinite would silently override the user's intent
        // and orphan the original session's source.
        if([self.sleepWakeTimer isScheduled]) { return; }
        [self activateTimerWithTimeInterval:KYASleepWakeTimeIntervalIndefinite
                                     source:KYAActivationSourceWatchedSSID];
    }
    else
    {
        // Leaving the watched network only ends sessions we started for
        // this feature. A user-initiated timer (or another feature's)
        // keeps running.
        [self terminateTimerIfOwnedBySource:KYAActivationSourceWatchedSSID];
    }
}

#pragma mark - Watched Application

- (void)registerForWatchedApplicationNotifications
{
    Auto workspaceCenter = NSWorkspace.sharedWorkspace.notificationCenter;
    [workspaceCenter addObserver:self
                        selector:@selector(watchedApplicationDidLaunch:)
                            name:NSWorkspaceDidLaunchApplicationNotification
                          object:nil];
    [workspaceCenter addObserver:self
                        selector:@selector(watchedApplicationDidTerminate:)
                            name:NSWorkspaceDidTerminateApplicationNotification
                          object:nil];
}

- (void)unregisterFromWatchedApplicationNotifications
{
    Auto workspaceCenter = NSWorkspace.sharedWorkspace.notificationCenter;
    [workspaceCenter removeObserver:self
                               name:NSWorkspaceDidLaunchApplicationNotification
                             object:nil];
    [workspaceCenter removeObserver:self
                               name:NSWorkspaceDidTerminateApplicationNotification
                             object:nil];
}

- (BOOL)isWatchedBundleIdentifier:(NSString *)bundleIdentifier
{
    return KYAWatchedBundleIdentifiers_Contains(
        NSUserDefaults.standardUserDefaults.kya_watchedApplicationBundleIdentifiers,
        bundleIdentifier);
}

- (BOOL)isAnyWatchedApplicationRunning
{
    Auto watched = NSUserDefaults.standardUserDefaults.kya_watchedApplicationBundleIdentifiers;
    // Early-out before enumerating every running process — iterating
    // `NSWorkspace.sharedWorkspace.runningApplications` is not free.
    if(watched.count == 0) { return NO; }
    for(NSRunningApplication *runningApp in NSWorkspace.sharedWorkspace.runningApplications)
    {
        if(KYAWatchedBundleIdentifiers_Contains(watched, runningApp.bundleIdentifier))
        {
            return YES;
        }
    }
    return NO;
}

/// Re-evaluates the watched-app trigger at launch and whenever the
/// watched list changes: adding an app that is already running starts a
/// session, removing the last running one ends the session it started.
/// Unrelated defaults changes are ignored so they can't restart a session
/// the user just ended.
- (void)reconcileWatchedApplicationTrigger
{
    Auto watched = NSUserDefaults.standardUserDefaults.kya_watchedApplicationBundleIdentifiers;
    Auto previous = self.reconciledWatchedBundleIdentifiers;
    if(self.hasReconciledWatchedBundleIdentifiers && (watched == previous || [watched isEqualToArray:previous]))
    {
        return;
    }
    self.hasReconciledWatchedBundleIdentifiers = YES;
    self.reconciledWatchedBundleIdentifiers = watched;

    if([self isAnyWatchedApplicationRunning] == NO)
    {
        [self terminateTimerIfOwnedBySource:KYAActivationSourceWatchedApp];
        return;
    }
    if([self.sleepWakeTimer isScheduled]) { return; }
    [self activateTimerWithTimeInterval:KYASleepWakeTimeIntervalIndefinite
                                 source:KYAActivationSourceWatchedApp];
}

- (void)watchedApplicationDidLaunch:(NSNotification *)notification
{
    Auto launched = (NSRunningApplication *)notification.userInfo[NSWorkspaceApplicationKey];
    if(![self isWatchedBundleIdentifier:launched.bundleIdentifier]) { return; }
    if([self.sleepWakeTimer isScheduled]) { return; }
    [self activateTimerWithTimeInterval:KYASleepWakeTimeIntervalIndefinite
                                 source:KYAActivationSourceWatchedApp];
}

- (void)watchedApplicationDidTerminate:(NSNotification *)notification
{
    Auto terminated = (NSRunningApplication *)notification.userInfo[NSWorkspaceApplicationKey];
    if(![self isWatchedBundleIdentifier:terminated.bundleIdentifier]) { return; }
    if([self.sleepWakeTimer isScheduled] == NO) { return; }
    // Only deactivate when the LAST watched app terminates. The
    // notification fires before the running-applications list updates,
    // so re-check membership while excluding the just-terminated
    // process.
    for(NSRunningApplication *runningApp in NSWorkspace.sharedWorkspace.runningApplications)
    {
        if([runningApp isEqual:terminated]) { continue; }
        if([self isWatchedBundleIdentifier:runningApp.bundleIdentifier])
        {
            return; // another watched app is still running
        }
    }
    // Only end the session we started for the watched-app feature —
    // a user-initiated timer that happened to be running stays.
    [self terminateTimerIfOwnedBySource:KYAActivationSourceWatchedApp];
}

#pragma mark - Event Handling

- (void)applicationWillFinishLaunching:(NSNotification *)notification
{
    [KYAEventHandler.defaultHandler registerAsDefaultEventHandler];
}

- (void)configureEventHandler
{
    Auto eventHandler = KYAEventHandler.defaultHandler;
    
    AutoWeak weakSelf = self;
    [eventHandler registerActionNamed:@"activate" block:^(KYAEvent *event) {
        [weakSelf handleActivateActionForEvent:event];
    }];
    
    [eventHandler registerActionNamed:@"deactivate" block:^(KYAEvent *event) {
        Auto strongSelf = weakSelf;
        [strongSelf terminateTimer];
        strongSelf.statusItemController.appearance = KYAStatusItemAppearanceInactive;
    }];
    
    [eventHandler registerActionNamed:@"toggle" block:^(KYAEvent *event) {
        Auto strongSelf = weakSelf;
        [strongSelf statusItemControllerShouldPerformPrimaryAction:strongSelf.statusItemController];
    }];
}

- (void)handleActivateActionForEvent:(KYAEvent *)event
{
    Auto parameters = event.arguments;
    NSString *seconds = parameters[@"seconds"];
    NSString *minutes = parameters[@"minutes"];
    NSString *hours = parameters[@"hours"];

    [self terminateTimer];
    
    Auto statusItemController = self.statusItemController;

    // Activate indefinitely if there are no parameters
    if(parameters == nil || parameters.count == 0)
    {
        [self activateTimer];
        statusItemController.appearance = KYAStatusItemAppearanceActive;
    }
    else if(seconds != nil)
    {
        [self activateTimerWithTimeInterval:(NSTimeInterval)ceil(seconds.doubleValue)];
        statusItemController.appearance = KYAStatusItemAppearanceActive;
    }
    else if(minutes != nil)
    {
        [self activateTimerWithTimeInterval:(NSTimeInterval)KYA_MINUTES(ceil(minutes.doubleValue))];
        statusItemController.appearance = KYAStatusItemAppearanceActive;
    }
    else if(hours != nil)
    {
        [self activateTimerWithTimeInterval:(NSTimeInterval)KYA_HOURS(ceil(hours.doubleValue))];
        statusItemController.appearance = KYAStatusItemAppearanceActive;
    }
    else
    {
        statusItemController.appearance = KYAStatusItemAppearanceInactive;
    }
}

#pragma mark - Internal / External Screen Parameter Changes

- (void)applicationDidChangeScreenParameters:(NSNotification *)notification
{
    if([NSUserDefaults.standardUserDefaults kya_isActivateOnExternalDisplayConnectedEnabled] == NO)
    {
        return;
    }

    NSUInteger numberOfExternalScreens = KYADisplayParametersGetNumberOfExternalDisplays();
    Auto sleepWakeTimer = self.sleepWakeTimer;

    if(numberOfExternalScreens == 0)
    {
        // Only the built-in screen is connected. Tear down only if this
        // very session was started by the external-display trigger; never
        // touch a user-initiated session.
        [self terminateTimerIfOwnedBySource:KYAActivationSourceExternalDisplay];
    }
    else
    {
        // The main screen plus at least one external screen.
        // Don't override an existing session (user or any other trigger).
        if([sleepWakeTimer isScheduled] == NO)
        {
            [self activateTimerWithTimeInterval:KYASleepWakeTimeIntervalIndefinite
                                         source:KYAActivationSourceExternalDisplay];
        }
    }
}

#pragma mark - KYAStatusItemControllerDataSource

- (NSMenu *)menuForStatusItemController:(KYAStatusItemController *)controller
{
    return self.menu;
}

#pragma mark - KYAStatusItemControllerDelegate

- (void)statusItemControllerShouldPerformPrimaryAction:(KYAStatusItemController *)controller
{
    if([self.sleepWakeTimer isScheduled])
    {
        [self terminateTimer];
    }
    else
    {
        [self activateTimer];
    }
}

#pragma mark - KYAActivationDurationsMenuControllerDelegate

- (KYAActivationDuration *)currentActivationDuration
{
    Auto sleepWakeTimer = self.sleepWakeTimer;
    if(![sleepWakeTimer isScheduled])
    {
        return nil;
    }

    NSTimeInterval seconds = sleepWakeTimer.scheduledTimeInterval;
    return [[KYAActivationDuration alloc] initWithSeconds:seconds];
}

- (void)activationDurationsMenuController:(KYAActivationDurationsMenuController *)controller didSelectActivationDuration:(KYAActivationDuration *)activationDuration
{
    [self terminateTimer];

    AutoWeak weakSelf = self;
    dispatch_async(dispatch_get_main_queue(), ^{
        NSTimeInterval seconds = activationDuration.seconds;
        [weakSelf activateTimerWithTimeInterval:seconds];
    });
}

- (NSDate *)fireDateForMenuController:(KYAActivationDurationsMenuController *)controller
{
    return self.sleepWakeTimer.fireDate;
}

#pragma mark - KYASleepWakeTimerDelegate

- (void)sleepWakeTimer:(KYASleepWakeTimer *)sleepWakeTimer willActivateWithTimeInterval:(NSTimeInterval)timeInterval
{
    // Update the status item
    self.statusItemController.appearance = KYAStatusItemAppearanceActive;

    Auto fireDate = sleepWakeTimer.fireDate;
    if(fireDate != nil)
    {
        [self.statusItemController startCountdownWithFireDate:fireDate];
    }
    else
    {
        // Indefinite session — make sure no stale countdown lingers.
        [self.statusItemController stopCountdown];
    }

    [self enableDevicePowerMonitoring];
    [self startDriveAliveIfEnabled];
    [self startMouseJigglerIfEnabled];
}

// Session teardown lives in the per-session completion block (see
// -activateTimerWithTimeInterval:source:) rather than in
// -sleepWakeTimerDidDeactivate:, which is delivered asynchronously without
// saying which session ended — after a replacement it would tear down the
// newer session.
- (void)tearDownSessionSideEffects
{
    // Update the status item
    self.statusItemController.appearance = KYAStatusItemAppearanceInactive;

    [self disableDevicePowerMonitoring];
    [self stopDriveAlive];
    [self stopMouseJiggler];
}

#pragma mark - Mouse Jiggler

- (void)startMouseJigglerIfEnabled
{
    if([NSUserDefaults.standardUserDefaults kya_isMouseJigglerEnabled] == NO) { return; }
    if(self.mouseJiggler.isRunning) { return; }

    self.mouseJiggler = [KYAMouseJiggler new];
    [self.mouseJiggler start];
}

- (void)stopMouseJiggler
{
    [self.mouseJiggler stop];
    self.mouseJiggler = nil;
}

#pragma mark - Drive Alive

- (void)startDriveAliveIfEnabled
{
    if([NSUserDefaults.standardUserDefaults kya_isDriveAliveEnabled] == NO) { return; }
    if(self.driveAliveTimer.isRunning) { return; }

    self.driveAliveTimer = [[KYADriveAliveTimer alloc] initWithInterval:30.0];
    [self.driveAliveTimer start];
}

- (void)stopDriveAlive
{
    [self.driveAliveTimer stop];
    self.driveAliveTimer = nil;
}

@end
