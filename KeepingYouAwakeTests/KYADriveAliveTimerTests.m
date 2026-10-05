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

- (void)testDefaultVolumesExcludeTheRootFileSystem
{
    for(NSURL *volume in [KYADriveAliveTimer externalWritableVolumeURLs])
    {
        XCTAssertNotEqualObjects(volume.path.stringByStandardizingPath, @"/");
    }
}

@end
