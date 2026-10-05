//
//  KYAScripting.h
//  KeepingYouAwake
//
//  AppleScript / sdef glue (#46). Three NSScriptCommand subclasses
//  for activate / deactivate / toggle, plus a KYAScriptingProxy
//  vended as the singleton `kya` object so callers can read
//  `active`, `remaining seconds`, and `source`.
//

#import <Cocoa/Cocoa.h>

@class KYAActivityLogger;

NS_ASSUME_NONNULL_BEGIN

@interface KYAActivateScriptCommand : NSScriptCommand
@end

@interface KYADeactivateScriptCommand : NSScriptCommand
@end

@interface KYAToggleScriptCommand : NSScriptCommand
@end

/// Read-only proxy exposed as the singleton `kya` object. Reads its
/// state from the activity log (same path as the CLI / MCP server).
@interface KYAScriptingProxy : NSObject
+ (instancetype)sharedProxy;
@property (readonly, nonatomic, getter=isActive) BOOL active;
@property (readonly, nonatomic) NSInteger remainingSeconds;   // -1 if indefinite or inactive
@property (readonly, copy, nonatomic) NSString *source;       // "" if inactive
@end

/// Block signature for the testable URL-dispatch seam. The activate /
/// deactivate / toggle script commands route their URL emission through
/// a single dispatcher block so tests can capture the URL without
/// triggering Launch Services.
typedef void (^KYAScriptingURLDispatcher)(NSURL *url);

@interface KYAScriptingProxy (Testing)
/// Override the URL dispatch used by the AppleScript command classes.
/// Pass `nil` to restore the default (which routes through
/// `-[KYAEventHandler handleEventForURL:]` in this process). Tests
/// MUST reset this in `tearDown` to avoid leaking state across tests.
+ (void)kya_setURLDispatcherForTesting:(KYAScriptingURLDispatcher _Nullable)dispatcher;

/// Stale-entry guard used by the `kya` property accessors: YES if an
/// open activity-log entry started during the current process launch.
/// `startedAt` has whole-second precision (ISO 8601 in the JSONL), so
/// the comparison is done at that precision. A nil `launchDate` trusts
/// every entry.
+ (BOOL)kya_isEntryStartedAt:(NSDate *)startedAt fromLaunchAt:(nullable NSDate *)launchDate;

/// Read state from `logger` instead of the shared activity logger.
/// Pass nil to restore the default.
- (void)kya_setActivityLoggerForTesting:(nullable KYAActivityLogger *)logger;

/// Use `launchDate` for the stale-entry guard instead of this process's
/// launch date. Pass nil to restore the default.
- (void)kya_setLaunchDateForTesting:(nullable NSDate *)launchDate;

/// Clear test overrides and the open-entry cache. Tests MUST call this
/// in `tearDown` since the proxy is a singleton.
- (void)kya_resetForTesting;
@end

NS_ASSUME_NONNULL_END
