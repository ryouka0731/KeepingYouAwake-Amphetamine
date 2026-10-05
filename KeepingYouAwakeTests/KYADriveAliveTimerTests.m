//
//  KYADriveAliveTimerTests.m
//  KeepingYouAwakeTests
//
//  Drive Alive must keep external drives active, not only the startup
//  disk. Temporary directories stand in for volume roots via the
//  injectable volumes provider.
//

#import <XCTest/XCTest.h>
#import "KYADriveAliveTimer.h"

@interface KYADriveAliveTimerTests : XCTestCase
@property (nonatomic) NSURL *volumeA;
@property (nonatomic) NSURL *volumeB;
@end

@implementation KYADriveAliveTimerTests

- (void)setUp
{
    [super setUp];
    NSURL *base = [NSURL fileURLWithPath:NSTemporaryDirectory() isDirectory:YES];
    self.volumeA = [base URLByAppendingPathComponent:[NSString stringWithFormat:@"kya-volA-%@", NSUUID.UUID.UUIDString] isDirectory:YES];
    self.volumeB = [base URLByAppendingPathComponent:[NSString stringWithFormat:@"kya-volB-%@", NSUUID.UUID.UUIDString] isDirectory:YES];
    for(NSURL *volume in @[self.volumeA, self.volumeB])
    {
        XCTAssertTrue([NSFileManager.defaultManager createDirectoryAtURL:volume withIntermediateDirectories:YES attributes:nil error:nil]);
    }
}

- (void)tearDown
{
    for(NSURL *volume in @[self.volumeA, self.volumeB])
    {
        [NSFileManager.defaultManager setAttributes:@{NSFilePosixPermissions: @0755} ofItemAtPath:volume.path error:nil];
        [NSFileManager.defaultManager removeItemAtURL:volume error:nil];
    }
    [super tearDown];
}

- (NSURL *)pingURLInVolume:(NSURL *)volume
{
    return [volume URLByAppendingPathComponent:KYADriveAlivePingFileName isDirectory:NO];
}

- (void)waitUntilFileAtURL:(NSURL *)url exists:(BOOL)exists
{
    NSPredicate *predicate = [NSPredicate predicateWithBlock:^BOOL(id object, NSDictionary *bindings) {
        return [NSFileManager.defaultManager fileExistsAtPath:url.path] == exists;
    }];
    [self expectationForPredicate:predicate evaluatedWithObject:self handler:nil];
    [self waitForExpectationsWithTimeout:5.0 handler:nil];
}

- (void)testWritesPingFileToEveryVolumeAndRemovesItOnStop
{
    NSArray<NSURL *> *volumes = @[self.volumeA, self.volumeB];
    KYADriveAliveTimer *timer = [[KYADriveAliveTimer alloc] initWithInterval:60.0
                                                             volumesProvider:^NSArray<NSURL *> *{ return volumes; }];
    [timer start];
    [self waitUntilFileAtURL:[self pingURLInVolume:self.volumeA] exists:YES];
    [self waitUntilFileAtURL:[self pingURLInVolume:self.volumeB] exists:YES];

    [timer stop];
    [self waitUntilFileAtURL:[self pingURLInVolume:self.volumeA] exists:NO];
    [self waitUntilFileAtURL:[self pingURLInVolume:self.volumeB] exists:NO];
}

- (void)testUnwritableVolumeDoesNotStopOtherVolumes
{
    XCTAssertTrue([NSFileManager.defaultManager setAttributes:@{NSFilePosixPermissions: @0555}
                                                 ofItemAtPath:self.volumeA.path
                                                        error:nil]);
    NSArray<NSURL *> *volumes = @[self.volumeA, self.volumeB];
    KYADriveAliveTimer *timer = [[KYADriveAliveTimer alloc] initWithInterval:60.0
                                                             volumesProvider:^NSArray<NSURL *> *{ return volumes; }];
    [timer start];
    [self waitUntilFileAtURL:[self pingURLInVolume:self.volumeB] exists:YES];
    XCTAssertFalse([NSFileManager.defaultManager fileExistsAtPath:[self pingURLInVolume:self.volumeA].path]);
    [timer stop];
    [self waitUntilFileAtURL:[self pingURLInVolume:self.volumeB] exists:NO];
}

- (void)assertFileAtURL:(NSURL *)url staysPresentFor:(NSTimeInterval)seconds
{
    NSPredicate *gone = [NSPredicate predicateWithBlock:^BOOL(id object, NSDictionary *bindings) {
        return [NSFileManager.defaultManager fileExistsAtPath:url.path] == NO;
    }];
    XCTestExpectation *removed = [self expectationForPredicate:gone evaluatedWithObject:self handler:nil];
    removed.inverted = YES;
    [self waitForExpectationsWithTimeout:seconds handler:nil];
}

- (void)testExistingUserFileIsNeitherOverwrittenNorRemoved
{
    NSURL *ping = [self pingURLInVolume:self.volumeA];
    XCTAssertTrue([@"user data" writeToURL:ping atomically:YES encoding:NSUTF8StringEncoding error:nil]);
    NSArray<NSURL *> *volumes = @[self.volumeA, self.volumeB];
    KYADriveAliveTimer *timer = [[KYADriveAliveTimer alloc] initWithInterval:60.0
                                                             volumesProvider:^NSArray<NSURL *> *{ return volumes; }];
    [timer start];
    [self waitUntilFileAtURL:[self pingURLInVolume:self.volumeB] exists:YES];
    [timer stop];
    [self waitUntilFileAtURL:[self pingURLInVolume:self.volumeB] exists:NO];

    XCTAssertEqualObjects([NSString stringWithContentsOfURL:ping encoding:NSUTF8StringEncoding error:nil], @"user data");
}

- (void)testSymlinkTargetIsNotOverwritten
{
    NSURL *target = [self.volumeB URLByAppendingPathComponent:@"precious.txt"];
    XCTAssertTrue([@"precious" writeToURL:target atomically:YES encoding:NSUTF8StringEncoding error:nil]);
    XCTAssertTrue([NSFileManager.defaultManager createSymbolicLinkAtURL:[self pingURLInVolume:self.volumeA]
                                                     withDestinationURL:target
                                                                  error:nil]);
    NSArray<NSURL *> *volumes = @[self.volumeA];
    KYADriveAliveTimer *timer = [[KYADriveAliveTimer alloc] initWithInterval:60.0
                                                             volumesProvider:^NSArray<NSURL *> *{ return volumes; }];
    [timer start];
    [self assertFileAtURL:target staysPresentFor:1.0];
    [timer stop];
    [self assertFileAtURL:target staysPresentFor:1.0];

    XCTAssertEqualObjects([NSString stringWithContentsOfURL:target encoding:NSUTF8StringEncoding error:nil], @"precious");
}

- (void)testStoppingOldTimerKeepsReplacementTimersPing
{
    NSArray<NSURL *> *volumes = @[self.volumeA];
    KYADriveAliveVolumesProvider provider = ^NSArray<NSURL *> *{ return volumes; };
    KYADriveAliveTimer *old = [[KYADriveAliveTimer alloc] initWithInterval:60.0 volumesProvider:provider];
    [old start];
    [self waitUntilFileAtURL:[self pingURLInVolume:self.volumeA] exists:YES];

    NSURL *ping = [self pingURLInVolume:self.volumeA];
    NSString *oldContent = [NSString stringWithContentsOfURL:ping encoding:NSUTF8StringEncoding error:nil];
    KYADriveAliveTimer *replacement = [[KYADriveAliveTimer alloc] initWithInterval:60.0 volumesProvider:provider];
    [replacement start];
    // Wait until the replacement has rewritten the shared path (its token
    // differs) before stopping the old timer.
    NSPredicate *rewritten = [NSPredicate predicateWithBlock:^BOOL(id object, NSDictionary *bindings) {
        NSString *content = [NSString stringWithContentsOfURL:ping encoding:NSUTF8StringEncoding error:nil];
        return content.length > 0 && ![content isEqualToString:oldContent];
    }];
    [self expectationForPredicate:rewritten evaluatedWithObject:self handler:nil];
    [self waitForExpectationsWithTimeout:5.0 handler:nil];
    [old stop];
    [self assertFileAtURL:[self pingURLInVolume:self.volumeA] staysPresentFor:1.0];

    [replacement stop];
    [self waitUntilFileAtURL:[self pingURLInVolume:self.volumeA] exists:NO];
}

- (void)testEmptyLeftoverFileIsReclaimed
{
    // What an interrupted write of ours leaves behind must not block the
    // volume forever.
    NSURL *ping = [self pingURLInVolume:self.volumeA];
    XCTAssertTrue([NSData.data writeToURL:ping atomically:NO]);
    NSArray<NSURL *> *volumes = @[self.volumeA];
    KYADriveAliveTimer *timer = [[KYADriveAliveTimer alloc] initWithInterval:60.0
                                                             volumesProvider:^NSArray<NSURL *> *{ return volumes; }];
    [timer start];
    NSPredicate *written = [NSPredicate predicateWithBlock:^BOOL(id object, NSDictionary *bindings) {
        return [[NSString stringWithContentsOfURL:ping encoding:NSUTF8StringEncoding error:nil] hasPrefix:@"keepingyouawake "];
    }];
    [self expectationForPredicate:written evaluatedWithObject:self handler:nil];
    [self waitForExpectationsWithTimeout:5.0 handler:nil];
    [timer stop];
    [self waitUntilFileAtURL:ping exists:NO];
}

- (void)testVolumeEligibility
{
    NSDictionary<NSURLResourceKey, id> *external = @{
        NSURLVolumeIsInternalKey: @NO,
        NSURLVolumeIsLocalKey: @YES,
        NSURLVolumeIsReadOnlyKey: @NO,
        NSURLVolumeIsRootFileSystemKey: @NO,
    };
    XCTAssertTrue([KYADriveAliveTimer isEligibleVolumeWithResourceValues:external]);

    NSDictionary<NSURLResourceKey, id> *(^with)(NSURLResourceKey, id) = ^(NSURLResourceKey key, id value) {
        NSMutableDictionary *values = [external mutableCopy];
        if(value == nil) { [values removeObjectForKey:key]; } else { values[key] = value; }
        return [values copy];
    };
    XCTAssertFalse([KYADriveAliveTimer isEligibleVolumeWithResourceValues:with(NSURLVolumeIsInternalKey, @YES)]);
    XCTAssertFalse([KYADriveAliveTimer isEligibleVolumeWithResourceValues:with(NSURLVolumeIsInternalKey, nil)],
                   @"unknown counts as internal");
    XCTAssertFalse([KYADriveAliveTimer isEligibleVolumeWithResourceValues:with(NSURLVolumeIsLocalKey, @NO)],
                   @"network share");
    XCTAssertFalse([KYADriveAliveTimer isEligibleVolumeWithResourceValues:with(NSURLVolumeIsReadOnlyKey, @YES)]);
    XCTAssertFalse([KYADriveAliveTimer isEligibleVolumeWithResourceValues:with(NSURLVolumeIsRootFileSystemKey, @YES)]);
}

- (void)testDefaultVolumesExcludeTheRootFileSystem
{
    for(NSURL *volume in [KYADriveAliveTimer externalWritableVolumeURLs])
    {
        XCTAssertNotEqualObjects(volume.path.stringByStandardizingPath, @"/");
    }
}

@end
