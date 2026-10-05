//
//  KYADriveAliveTimer.h
//  KeepingYouAwake
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// Returns the volume root URLs Drive Alive should keep active.
typedef NSArray<NSURL *> * _Nonnull (^KYADriveAliveVolumesProvider)(void);

/// Name of the hidden file Drive Alive rewrites at the root of each
/// external volume.
FOUNDATION_EXPORT NSString * const KYADriveAlivePingFileName;

/// Keeps drives from spinning down while a session is active: rewrites a
/// tiny ping file under `NSTemporaryDirectory()` (the startup disk) and a
/// hidden `KYADriveAlivePingFileName` file at the root of every mounted
/// external, local, writable volume. This is the local equivalent of
/// Amphetamine's "Drive Alive".
///
/// Volumes are re-enumerated on every tick, so drives attached during a
/// session are picked up. A volume that can't be written (e.g. a sandboxed
/// build without access to it) is skipped, and so is a path that already
/// holds anything other than a Drive Alive ping (a user's file, a
/// directory or a symlink). `start` is a no-op if already running. `stop`
/// removes the ping files this timer wrote, and only those. Instances are
/// intentionally cheap: schedule once per active session, release on
/// session end.
@interface KYADriveAliveTimer : NSObject

/// How frequently the files are rewritten. Defaults to 30 seconds, which
/// is below the spin-down timeout of every external HDD I have seen.
@property (nonatomic, readonly) NSTimeInterval interval;

@property (nonatomic, readonly, getter=isRunning) BOOL running;

/// Mounted volumes that are external (not internal), local (not network
/// shares), writable and not the root file system.
+ (NSArray<NSURL *> *)externalWritableVolumeURLs;

/// The filter behind +externalWritableVolumeURLs, for the resource values
/// of one volume (`NSURLVolumeIsInternalKey`, `…IsLocalKey`,
/// `…IsReadOnlyKey`, `…IsRootFileSystemKey`). Unknown "internal" counts
/// as internal.
+ (BOOL)isEligibleVolumeWithResourceValues:(NSDictionary<NSURLResourceKey, id> *)values;

- (instancetype)init NS_UNAVAILABLE;
- (instancetype)initWithInterval:(NSTimeInterval)interval;
/// Designated initializer. `volumesProvider` defaults to
/// `+externalWritableVolumeURLs`; tests pass their own.
- (instancetype)initWithInterval:(NSTimeInterval)interval
                 volumesProvider:(nullable KYADriveAliveVolumesProvider)volumesProvider NS_DESIGNATED_INITIALIZER;

- (void)start;
- (void)stop;

@end

NS_ASSUME_NONNULL_END
