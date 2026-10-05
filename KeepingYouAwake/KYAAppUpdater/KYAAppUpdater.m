//
//  KYAAppUpdater.m
//  KeepingYouAwake
//
//  Created by Marcel Dierkes on 26.09.21.
//  Copyright © 2021 Marcel Dierkes. All rights reserved.
//

#import "KYAAppUpdater.h"
#import <KYACommon/KYACommon.h>

#if KYA_APP_UPDATER_ENABLED

#import <KYAApplicationSupport/KYAApplicationSupport.h>
#import <Sparkle/Sparkle.h>

// Fork-controlled appcast URLs, published to gh-pages by appcast.yml after
// each release (#54). Only the release feed is generated; the pre-release
// feed URL isn't published yet, so a pre-release update check fails to
// fetch a feed (and installs nothing).
// Pointing back at upstream's `newmarcel.github.io/KeepingYouAwake/...`
// feeds instead would pull upstream's binary into a fork bundle and
// violate the upstream maintainer's "don't redistribute under same name
// and icon" request.
static NSString * const KYAAppUpdaterReleaseFeedURLString = @"https://ryouka0731.github.io/KeepingYouAwake-Amphetamine/appcast.xml";
static NSString * const KYAAppUpdaterPreReleaseFeedURLString = @"https://ryouka0731.github.io/KeepingYouAwake-Amphetamine/prerelease-appcast.xml";

@interface KYAAppUpdater () <SPUUpdaterDelegate>
@property (nonatomic) SPUStandardUpdaterController *updaterController;
@end

@implementation KYAAppUpdater

+ (KYAAppUpdater *)defaultAppUpdater
{
    static dispatch_once_t once;
    static KYAAppUpdater *sharedInstance;
    dispatch_once(&once, ^{
        sharedInstance = [[self alloc] init];
    });
    return sharedInstance;
}

- (instancetype)init
{
    self = [super init];
    if(self)
    {
        self.updaterController = [[SPUStandardUpdaterController alloc] initWithUpdaterDelegate:self
                                                                            userDriverDelegate:nil];
    }
    return self;
}

- (SPUUpdater *)updater
{
    return self.updaterController.updater;
}

- (void)checkForUpdates:(id)sender
{
    [self.updaterController checkForUpdates:sender];
}

#pragma mark - SPUUpdaterDelegate

- (NSString *)feedURLStringForUpdater:(SPUUpdater *)updater
{
    Auto defaults = NSUserDefaults.standardUserDefaults;
    if([defaults kya_arePreReleaseUpdatesEnabled])
    {
        return KYAAppUpdaterPreReleaseFeedURLString;
    }
    else
    {
        return KYAAppUpdaterReleaseFeedURLString;
    }
}

@end

#endif
