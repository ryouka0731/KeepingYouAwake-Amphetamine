//
//  KYAAboutSettingsViewController.m
//  KeepingYouAwake
//
//  Created by Marcel Dierkes on 18.12.15.
//  Copyright © 2015 Marcel Dierkes. All rights reserved.
//

#import "KYAAboutSettingsViewController.h"
#import <KYACommon/KYACommon.h>
#import "KYALocalizedStrings.h"

@interface KYAAboutSettingsViewController ()
@end

@implementation KYAAboutSettingsViewController

+ (NSImage *)tabViewItemImage
{
    if(@available(macOS 11.0, *))
    {
        return [NSImage imageWithSystemSymbolName:@"info.circle"
                         accessibilityDescription:nil];
    }
    else
    {
        return [NSImage imageNamed:NSImageNameInfo];
    }
}

+ (NSString *)preferredTitle
{
    return KYA_SETTINGS_L10N_ABOUT;
}

#pragma mark - Bindings

- (NSString *)versionText
{
    return [NSString localizedStringWithFormat:@"%@ %@",
            KYA_L10N_VERSION,
            NSBundle.mainBundle.kya_fullVersionString];
}

- (NSString *)copyrightText
{
    return NSBundle.mainBundle.kya_localizedCopyrightString;
}

- (id)creditsFileURL
{
    // Credits.rtf is not a localized resource; Japanese gets its own copy.
    Auto bundle = NSBundle.mainBundle;
    if([bundle.preferredLocalizations.firstObject hasPrefix:@"ja"])
    {
        Auto japanese = [bundle URLForResource:@"Credits-ja" withExtension:@"rtf"];
        if(japanese != nil) { return japanese; }
    }
    return [bundle URLForResource:@"Credits" withExtension:@"rtf"];
}

- (BOOL)isEditable
{
    return NO;
}

@end
