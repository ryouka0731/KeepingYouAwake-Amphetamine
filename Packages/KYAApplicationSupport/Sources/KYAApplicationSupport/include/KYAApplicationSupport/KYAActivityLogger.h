//
//  KYAActivityLogger.h
//  KYAApplicationSupport
//
//  Created for KeepingYouAwake-Amphetamine fork (issue #42).
//  Records activate / deactivate events of the sleep-wake timer to a
//  capped JSONL file under Application Support, so users can audit
//  which trigger fired when.
//

#import <Foundation/Foundation.h>
#import <KYACommon/KYAExport.h>

NS_ASSUME_NONNULL_BEGIN

/// Categorical source string for an activation. Mirrors the
/// KYAActivationSource enum in KYAAppController, kept as plain strings
/// here so the logger has no compile-time dep on the controller.
KYA_EXPORT NSString * const KYAActivityLogSourceUser;
KYA_EXPORT NSString * const KYAActivityLogSourceWatchedApp;
KYA_EXPORT NSString * const KYAActivityLogSourceWatchedSSID;
KYA_EXPORT NSString * const KYAActivityLogSourceACPower;
KYA_EXPORT NSString * const KYAActivityLogSourceExternalDisplay;
KYA_EXPORT NSString * const KYAActivityLogSourceSchedule;
KYA_EXPORT NSString * const KYAActivityLogSourceDownload;
KYA_EXPORT NSString * const KYAActivityLogSourceAudioOutput;
KYA_EXPORT NSString * const KYAActivityLogSourceCPULoad;

/// Categorical reason a session ended. Lives in JSONL `endedReason`.
KYA_EXPORT NSString * const KYAActivityLogEndedReasonExpired;          // timer hit fireDate
KYA_EXPORT NSString * const KYAActivityLogEndedReasonUserCancelled;    // status-item click, menu, URL scheme
KYA_EXPORT NSString * const KYAActivityLogEndedReasonTriggerCancelled; // feature trigger ended its own session
KYA_EXPORT NSString * const KYAActivityLogEndedReasonAppTerminated;    // app quit (or crashed) while the session was open

/// One entry as decoded from the JSONL file. All values are immutable.
@interface KYAActivityLogEntry : NSObject
@property (copy, nonatomic, readonly) NSDate *startedAt;
/// nil if the entry hasn't been finalised yet (e.g. app was killed).
@property (copy, nonatomic, readonly, nullable) NSDate *endedAt;
@property (copy, nonatomic, readonly) NSString *source;
/// Requested duration in seconds; -1 if indefinite.
@property (nonatomic, readonly) NSTimeInterval requestedDuration;
/// One of the KYAActivityLogEndedReason* constants. nil while the
/// session is still open or for entries written by older builds that
/// didn't record this field.
@property (copy, nonatomic, readonly, nullable) NSString *endedReason;

- (instancetype)initWithStartedAt:(NSDate *)startedAt
                          endedAt:(nullable NSDate *)endedAt
                           source:(NSString *)source
                requestedDuration:(NSTimeInterval)requestedDuration
                      endedReason:(nullable NSString *)endedReason;
@end

/// Append-only logger with a soft cap on retained entries. Thread-safe
/// (serial dispatch queue + atomic file write).
@interface KYAActivityLogger : NSObject

/// Default singleton, writing to ~/Library/Application Support/KeepingYouAwake/activity.jsonl.
+ (instancetype)sharedLogger;

/// Designated initializer for tests; pass any URL.
- (instancetype)initWithFileURL:(NSURL *)fileURL maximumEntries:(NSUInteger)maxEntries NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;

/// File the logger writes to (read-only — for tests + diagnostics).
@property (copy, nonatomic, readonly) NSURL *fileURL;

/// Soft cap on the number of retained entries. Older entries are
/// dropped from the head when the cap is exceeded on the next write.
@property (nonatomic, readonly) NSUInteger maximumEntries;

/// Append a started-at marker. Returns immediately; persistence is async.
/// @param source One of the KYAActivityLogSource* constants. Other
///               strings are accepted but won't be displayed nicely.
/// @param requestedDuration Seconds the user requested, or -1 for indefinite.
- (void)recordActivationStartedFromSource:(NSString *)source
                        requestedDuration:(NSTimeInterval)requestedDuration;

/// Append a completion marker for the current session. No-op if no
/// session is open. Reason defaults to user-cancelled.
- (void)recordActivationEnded;

/// Append a completion marker with an explicit reason. Use one of the
/// KYAActivityLogEndedReason* constants for stable JSONL semantics.
- (void)recordActivationEndedWithReason:(NSString *)reason;

/// Like -recordActivationEndedWithReason:, but returns only after the
/// entry has been written. Use it on app termination, where an async
/// write would never run.
- (void)recordActivationEndedSynchronouslyWithReason:(NSString *)reason;

/// Closes every entry that has no `endedAt` — sessions left open by a
/// previous process that crashed or was killed. `endedAt` is set to now
/// (the real end time is unknown). Call once at launch, before the first
/// -recordActivationStartedFromSource:requestedDuration:. Synchronous.
- (void)closeDanglingEntriesWithReason:(NSString *)reason;

/// Returns the last `count` entries, newest first. Synchronous read.
- (NSArray<KYAActivityLogEntry *> *)recentEntriesWithLimit:(NSUInteger)count;

@end

NS_ASSUME_NONNULL_END
