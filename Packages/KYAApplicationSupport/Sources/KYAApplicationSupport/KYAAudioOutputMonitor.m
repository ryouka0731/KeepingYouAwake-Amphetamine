//
//  KYAAudioOutputMonitor.m
//  KYAApplicationSupport
//

#import <KYAApplicationSupport/KYAAudioOutputMonitor.h>
#import <KYACommon/KYACommon.h>
#import <CoreAudio/CoreAudio.h>

@interface KYAAudioOutputMonitor ()
@property (nonatomic, readwrite, getter=isRunning) BOOL running;
@property (nonatomic, readwrite) BOOL hasExternalAudioOutput;
/// The registered listener; removing it needs the same block.
@property (nonatomic, nullable) AudioObjectPropertyListenerBlock listenerBlock;
@end

static const AudioObjectPropertyAddress KYADefaultOutputDeviceAddress = {
    .mSelector = kAudioHardwarePropertyDefaultOutputDevice,
    .mScope    = kAudioObjectPropertyScopeGlobal,
    .mElement  = kAudioObjectPropertyElementMain,
};

@implementation KYAAudioOutputMonitor

#pragma mark - Lifecycle

- (void)dealloc
{
    [self stop];
}

- (void)start
{
    if(self.running) { return; }
    self.running = YES;

    // A listener whose removal failed is still registered and still calls
    // -refresh; reuse it rather than adding a second one.
    if(self.listenerBlock != nil)
    {
        [self refresh];
        return;
    }

    // Delivered on the main queue (delegate calls drive AppKit code). The
    // block holds the monitor weakly: a change that arrives while the
    // monitor is being released can't reach freed memory, which the old
    // C callback with an unretained clientData pointer could.
    AutoWeak weakSelf = self;
    AudioObjectPropertyListenerBlock listener = ^(UInt32 inNumberAddresses,
                                                  const AudioObjectPropertyAddress *inAddresses) {
        [weakSelf refresh];
    };
    OSStatus status = AudioObjectAddPropertyListenerBlock(kAudioObjectSystemObject,
                                                          &KYADefaultOutputDeviceAddress,
                                                          dispatch_get_main_queue(),
                                                          listener);
    if(status != noErr)
    {
        // Listener registration failed — fall back to "running" but
        // never auto-fire. Refresh-on-demand still works.
        return;
    }
    self.listenerBlock = listener;
    [self refresh];
}

- (void)stop
{
    self.running = NO;

    AudioObjectPropertyListenerBlock listener = self.listenerBlock;
    if(listener == nil) { return; }
    // Keep the block if removal fails, so a later -stop can retry and
    // -start doesn't register a second listener next to it.
    if(AudioObjectRemovePropertyListenerBlock(kAudioObjectSystemObject,
                                              &KYADefaultOutputDeviceAddress,
                                              dispatch_get_main_queue(),
                                              listener) == noErr)
    {
        self.listenerBlock = nil;
    }
}

#pragma mark - Public API

- (void)refresh
{
    // Honour the documented "no-op when stopped" contract. The Core
    // Audio listener callback hops to the main queue before invoking
    // -refresh, so a stop() racing with an in-flight callback could
    // otherwise still flip activation state after the trigger was
    // disabled.
    if(!self.running) { return; }

    BOOL isExternal = [self currentDefaultOutputIsExternal];
    if(isExternal == self.hasExternalAudioOutput) { return; }
    self.hasExternalAudioOutput = isExternal;

    Auto delegate = self.delegate;
    if(isExternal)
    {
        if([delegate respondsToSelector:@selector(audioOutputMonitorDidStartUsingExternalDevice:)])
        {
            [delegate audioOutputMonitorDidStartUsingExternalDevice:self];
        }
    }
    else
    {
        if([delegate respondsToSelector:@selector(audioOutputMonitorDidReturnToBuiltInDevice:)])
        {
            [delegate audioOutputMonitorDidReturnToBuiltInDevice:self];
        }
    }
}

#pragma mark - Internal

- (BOOL)currentDefaultOutputIsExternal
{
    AudioDeviceID deviceID = 0;
    UInt32 size = sizeof(deviceID);
    AudioObjectPropertyAddress defaultAddr = {
        .mSelector = kAudioHardwarePropertyDefaultOutputDevice,
        .mScope    = kAudioObjectPropertyScopeGlobal,
        .mElement  = kAudioObjectPropertyElementMain,
    };
    OSStatus status = AudioObjectGetPropertyData(kAudioObjectSystemObject,
                                                 &defaultAddr,
                                                 0, NULL,
                                                 &size, &deviceID);
    if(status != noErr || deviceID == 0) { return NO; }

    UInt32 transportType = 0;
    UInt32 transportSize = sizeof(transportType);
    AudioObjectPropertyAddress transportAddr = {
        .mSelector = kAudioDevicePropertyTransportType,
        .mScope    = kAudioObjectPropertyScopeGlobal,
        .mElement  = kAudioObjectPropertyElementMain,
    };
    status = AudioObjectGetPropertyData(deviceID,
                                        &transportAddr,
                                        0, NULL,
                                        &transportSize, &transportType);
    if(status != noErr) { return NO; }

    // Built-in is the only "internal" transport. Everything else
    // (Bluetooth, USB, HDMI, AirPlay, virtual, FireWire, Thunderbolt,
    // unknown, …) counts as external. `Continuity` (Mac-as-mic via
    // iPhone) is also reasonably treated as external.
    return (transportType != kAudioDeviceTransportTypeBuiltIn);
}

@end
