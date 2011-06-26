//
//  DVCacheManagerTest.m
//  DropVault
//
//  Created by Brian Dewey on 3/7/11.
//  Copyright 2011 Brian Dewey. 
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//  http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//


#import "GTMSenTestCase.h"
#import <UIKit/UIKit.h>
#import "DVCacheManager.h"
#import <OCMock/OCMock.h>
#import "NSString+FileSystemHelper.h"

#define kDVCacheRootToken           @"DropBoxCache"
#define kSimpleMetadataPath         @"/StrongBox/foo.dat"

@interface DVCacheManagerTest : GTMTestCase {
  
}


@end


@implementation DVCacheManagerTest

#pragma mark -
#pragma mark Helper functions

//
//  Helper function: Loads a metadata dictionary from the application bundle.
//

- (NSDictionary *)getMetadataDictionaryForPath:(NSString *)path {
  
  //
  //  Create a metadata entry that matches |path|.
  //
  
  NSString *plistPath = [[[NSBundle mainBundle] bundlePath] stringByAppendingPathComponent:path];
  NSData *plistData = [[NSFileManager defaultManager] contentsAtPath:plistPath];
  NSPropertyListFormat format;
  NSDictionary *metadataDictionary = [NSPropertyListSerialization propertyListFromData:plistData 
                                                                      mutabilityOption:NSPropertyListImmutable 
                                                                                format:&format 
                                                                      errorDescription:NULL];
  return metadataDictionary;
}

//
//  Creates some test content at |path|.
//

- (void)createTestContentAtPath:(NSString *)path  {
  
  //
  //  Make sure the containing directory for |path| exists.
  //
  
  NSString *directory = [path stringByDeletingLastPathComponent];
  [[NSFileManager defaultManager] createDirectoryAtPath:directory 
                            withIntermediateDirectories:YES 
                                             attributes:nil 
                                                  error:NULL];
  
  //
  //  Now create the test content.
  //
  
  BOOL success = [@"This is some content" writeToFile:path 
                                           atomically:YES 
                                             encoding:NSUTF8StringEncoding 
                                                error:NULL];
  STAssertTrue(success, @"Should be able to create content at %@", path);
}

//
//  Deletes the |NSCachesDirectory|, if it exists.
//

- (void)deleteCachesDirectory {
  
  NSArray *paths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, 
                                                       NSUserDomainMask, 
                                                       YES);
  NSString *cachesDirectory = [paths objectAtIndex:0];
  BOOL isDirectory;
  if ([[NSFileManager defaultManager] fileExistsAtPath:cachesDirectory isDirectory:&isDirectory]) {
    STAssertTrue(isDirectory, @"Caches directory should be a directory, if it exists");
    BOOL success = [[NSFileManager defaultManager] removeItemAtPath:cachesDirectory 
                                                              error:NULL];
    STAssertTrue(success, @"Should be able to delete caches directory");
  }
}

#pragma mark -
#pragma mark Tests

//
//  Tests the string manipulation that should go on for mapping from DropBox
//  paths to local paths.
//

- (void)testCachePathForDropBoxPath {
  
  NSArray *paths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, 
                                                       NSUserDomainMask, 
                                                       YES);
  NSArray *cachePathComponents = [[[paths objectAtIndex:0] stringByAppendingPathComponent:kDVCacheRootToken] pathComponents];
  STAssertNotNil(cachePathComponents, @"Should get root cache path");
  _GTMDevLog(@"%s -- cache path root is %@", 
             __PRETTY_FUNCTION__, 
             [paths objectAtIndex:0]);
  STAssertEqualStrings(@"/", [cachePathComponents objectAtIndex:0], 
                       @"Should be absolute path");
  
  STAssertEqualStrings([[paths objectAtIndex:0] stringByAppendingPathComponent:kDVCacheRootToken],
                       [DVCacheManager cachePathForDropBoxPath:nil], 
                       @"Should handle nil");
  
  NSString *testPath = @"/StrongBox/foo.dat";
  NSArray *testComponents = [cachePathComponents arrayByAddingObjectsFromArray:[testPath pathComponents]];
  NSString *testCachePath = [[NSString pathWithComponents:testComponents] 
                             stringByStandardizingPath];
  STAssertEqualStrings(testCachePath, [DVCacheManager cachePathForDropBoxPath:testPath], 
                       @"Should handle absolute paths");
}

- (void)testDropBoxPathForCachePath {
  
  NSArray *testCases = [NSArray arrayWithObjects:@"/foo", @"/foo.dat", @"/StrongBox/foo", @"/StrongBox/foo.dat", nil];
  
  //
  //  This is a simple test... I just take a bunch of paths and verify that they
  //  round-trip through the two functions.
  //
  //  Need to work on interesting edge cases. What if the original DropBox path
  //  doesn't start with a "/"? What if it is only "/"?
  //
  
  for (NSString *test in testCases) {
    
    NSString *cache = [DVCacheManager cachePathForDropBoxPath:test];
    NSString *dropBox = [DVCacheManager dropBoxPathForCachePath:cache];
    STAssertEqualStrings(test, dropBox, nil);
  }
}

//
//  Test the |loadMetadata| action.
//

- (void)testLoadMetadata {
  
  DVCacheManager *cm = [[[DVCacheManager alloc] init] autorelease];
  id mockClient = [OCMockObject mockForClass:[DBRestClient class]];
  [[mockClient expect] loadMetadata:kDropVaultPath];
  cm.restClient = mockClient;
  
  STAssertNoThrow([cm loadMetadata], @"Should call loadMetadata");
  STAssertNoThrow([mockClient verify], @"Should receive all messages");
}

//
//  Tests the "load metadata succeeded" case.
//

- (void)testLoadMetadataSuccess {
  
  DVCacheManager *cm = [[[DVCacheManager alloc] init] autorelease];
  id mockDelegate = [OCMockObject mockForProtocol:@protocol(DVCacheManagerDelegate)];
  [[mockDelegate expect] cacheManagerDidLoadMetadata:cm];
  cm.delegate = mockDelegate;
  NSDictionary *metadataDictionary = [self getMetadataDictionaryForPath:@"simple-metadata.plist"];
  DBMetadata *metadata = [[[DBMetadata alloc] initWithDictionary:metadataDictionary] autorelease];
  
  [cm restClient:nil loadedMetadata:metadata];
  STAssertEquals(cm.metadata, metadata, @"Should remember metadata");
  STAssertNoThrow([mockDelegate verify], 
                  @"Should receive cacheManagerDidLoadMetadata:");
  
  //
  //  Now, create a new |DVCacheManager|. This should load the metadata that we
  //  persisted from the prior incantation.
  //
  
  DVCacheManager *reloaded = [[[DVCacheManager alloc] init] autorelease];
  STAssertNotNil(reloaded.metadata, @"Cache managers should reload metadata");
  STAssertEqualStrings(cm.metadata.hash, reloaded.metadata.hash,
                       @"Reloaded metadata should have the same hash value");
}

- (void)testLoadMetadataNoDelegate {
  
  DVCacheManager *cm = [[[DVCacheManager alloc] init] autorelease];
  id mockDelegate = [OCMockObject mockForClass:[DVCacheManagerTest class]];
  cm.delegate = mockDelegate;
  
  [cm restClient:nil loadedMetadata:nil];
  STAssertNoThrow([mockDelegate verify], 
                  @"Should not send optional messages that are not implemented");
}

- (void)testLoadMetadataFailed {
  
  DVCacheManager *cm = [[[DVCacheManager alloc] init] autorelease];
  id mockDelegate = [OCMockObject mockForProtocol:@protocol(DVCacheManagerDelegate)];
  [[mockDelegate expect] cacheManagerLoadMetadataFailed:cm];
  cm.delegate = mockDelegate;
  
  [cm restClient:nil loadMetadataFailedWithError:nil];
  STAssertNoThrow([mockDelegate verify], 
                  @"Should get cacheManagerLoadMetadataFailed: message");
}

//
//  Test caching an individual file.
//

- (void)testCacheFile {
  
  //
  //  Ensure that the caches directory doesn't exist prior to this test.
  //
  
  [self deleteCachesDirectory];
  DVCacheManager *cm = [[[DVCacheManager alloc] init] autorelease];
  id mockClient = [OCMockObject mockForClass:[DBRestClient class]];
  NSString *path = @"/StrongBox/brand-new-file.dat";
  
  //
  //  Trying to cache a file results in a loadFile:intoPath: message to the 
  //  restClient. Make sure we get that message.
  //
  
  _GTMDevLog(@"%s -- expecting loadFile:intoPath: for path '%@'",
             __PRETTY_FUNCTION__,
             [DVCacheManager cachePathForDropBoxPath:path]);
  [[mockClient expect] loadFile:path intoPath:[DVCacheManager cachePathForDropBoxPath:path]];
  cm.restClient = mockClient;
  id mockDelegate = [OCMockObject mockForProtocol:@protocol(DVCacheManagerDelegate)];
  cm.delegate = mockDelegate;
  
  [cm cacheCopyOfDropBoxPath:path];
  STAssertNoThrow([mockClient verify], @"Should get loadFile:intoPath: message");
  
  //
  //  And now the |cm.cacheRoot| directory must exist, or we won't have a place
  //  to store the downloaded file.
  //
  
  BOOL isDirectory;
  BOOL success = [[NSFileManager defaultManager] fileExistsAtPath:[DVCacheManager cacheRoot]
                                                      isDirectory:&isDirectory];
  STAssertTrue(success, @"cm.cacheRoot should exist");
  STAssertTrue(isDirectory, @"cm.cacheRoot should be a directory");
  NSString *cacheDirectory = [[DVCacheManager cachePathForDropBoxPath:path] stringByDeletingLastPathComponent];
  success = [[NSFileManager defaultManager] fileExistsAtPath:cacheDirectory 
                                                 isDirectory:&isDirectory];
  STAssertTrue(success, @"cacheDirectory should exist");
  STAssertTrue(isDirectory, @"cacheDirectory should be a directory");
}

//
//  Test caching an individual file *when the cached copy is up to date*.
//  In this case, we shouldn't go to DropBox.
//

- (void)testCacheFileUpToDate {

  DVCacheManager *cm = [[[DVCacheManager alloc] init] autorelease];
  NSString *path = [DVCacheManager cachePathForDropBoxPath:kSimpleMetadataPath];
  id mockClient = [OCMockObject mockForClass:[DBRestClient class]];
  cm.restClient = mockClient;
  id mockDelegate = [OCMockObject mockForProtocol:@protocol(DVCacheManagerDelegate)];
  [[mockDelegate expect] cacheManager:cm didCacheCopyOfFile:path];
  cm.delegate = mockDelegate;
  
  //
  //  Test setup: I need to have metadata in the |DVCacheManager| *and* set
  //  the local file to have the correct timestamp. This simulates the cache
  //  being up to date.
  //
  
  DBMetadata *metadata = [[[DBMetadata alloc] initWithDictionary:[self getMetadataDictionaryForPath:@"simple-metadata.plist"]] autorelease];
  STAssertNotNil(metadata, @"Should load metadata");
  cm.metadata = metadata;
  [self createTestContentAtPath:path];
  DBMetadata *fileMetadata = [cm metadataForPath:path];
  STAssertNotNil(fileMetadata, @"Should load fileMetadata");
  
  BOOL success = [[NSFileManager defaultManager] setAttributes:[NSDictionary dictionaryWithObject:fileMetadata.lastModifiedDate 
                                                                                           forKey:NSFileModificationDate] 
                                                  ofItemAtPath:path 
                                                         error:NULL];
  STAssertTrue(success, @"Can change NSFileModificationDate");
  STAssertEquals(DVCacheStateEquivalent, [cm cacheStateForPath:path], 
                 @"Cache should be up to date");
  
  //
  //  Setup is done. Ask the cache manager to cache |path|. As the cache is
  //  up-to-date, this result in a successful call to the delegate without any
  //  calls to |restClient|.
  //
  
  [cm cacheCopyOfDropBoxPath:@"/StrongBox/foo.dat"];
  STAssertNoThrow([mockDelegate verify], 
                  @"Should get cacheManager:didCacheCopyOfDropBoxPath: message");
}

//
//  Ensures that I can find metadata records corresponding to paths.
//

- (void)testMetadataForPath {
  
  DVCacheManager *cm = [[[DVCacheManager alloc] init] autorelease];
  
  //
  //  Create some metadata.
  //
  
  DBMetadata *metadata = [[[DBMetadata alloc] initWithDictionary:[self getMetadataDictionaryForPath:@"simple-metadata.plist"]]
                          autorelease];
  cm.metadata = metadata;
  
  NSString *path = [DVCacheManager cachePathForDropBoxPath:kSimpleMetadataPath];
  STAssertNotNil([cm metadataForPath:path], @"Should find metadata");
  STAssertNil([cm metadataForPath:kSimpleMetadataPath], 
              @"Should require path in documents folder");
  STAssertNil([cm metadataForPath:[DVCacheManager cachePathForDropBoxPath:@"fake.dat"]],
              @"Should not find non-existent files");
}

//
//  Verify the delegate gets its message if a file download succeeds.
//

- (void)testCacheFileSucceeds {
  
  DVCacheManager *cm = [[[DVCacheManager alloc] init] autorelease];
  id mockClient = [OCMockObject mockForClass:[DBRestClient class]];
  id mockDelegate = [OCMockObject mockForProtocol:@protocol(DVCacheManagerDelegate)];
  NSString *path = [DVCacheManager cachePathForDropBoxPath:kSimpleMetadataPath];
  [[mockDelegate expect] cacheManager:cm loadProgress:0.5 forFile:path];
  [[mockDelegate expect] cacheManager:cm didCacheCopyOfFile:path];
  cm.restClient = mockClient;
  cm.delegate = mockDelegate;
  
  [self createTestContentAtPath:path];

  
  NSDictionary *metadataDictionary;
  metadataDictionary = [self getMetadataDictionaryForPath:@"simple-metadata.plist"];

  _GTMDevLog(@"%s -- loaded metadata %@", __PRETTY_FUNCTION__, [metadataDictionary description]);
  
  DBMetadata *metadata = [[[DBMetadata alloc] initWithDictionary:metadataDictionary] autorelease];
  cm.metadata = metadata;
  
  //
  //  Provide a progress notification to ensure that the delegate gets it.
  //
  
  [cm restClient:mockClient loadProgress:0.5 forFile:path];
  [cm restClient:mockClient loadedFile:path];
  STAssertNoThrow([mockDelegate verify], 
                  @"Should get cacheManager:didCacheCopyOfDropBoxPath: message");
  
  NSDate *expectedDate = [[metadata.contents objectAtIndex:0] lastModifiedDate];
  NSDate *actualDate = [[[NSFileManager defaultManager] attributesOfItemAtPath:path error:NULL] fileModificationDate];
  
  _GTMDevLog(@"%s -- expected %@, got %@", __PRETTY_FUNCTION__, expectedDate, actualDate);
  
  STAssertEquals([expectedDate timeIntervalSince1970], 
                 [actualDate timeIntervalSince1970], 
                 @"Modified date should match DropBox");
}

//
//  Test that the delegate gets notified if an attempt to download a file
//  fails.
//

- (void)testCacheFileFails {
  
  DVCacheManager *cm = [[[DVCacheManager alloc] init] autorelease];
  id mockClient = [OCMockObject mockForClass:[DBRestClient class]];
  id mockDelegate = [OCMockObject mockForProtocol:@protocol(DVCacheManagerDelegate)];
  NSString *path = [DVCacheManager cachePathForDropBoxPath:kSimpleMetadataPath];
  [[mockDelegate expect] cacheManager:cm didFailCacheOfFile:path];
  cm.restClient = mockClient;
  cm.delegate = mockDelegate;
  
  NSError *error = [NSError errorWithDomain:DBErrorDomain 
                                       code:DBErrorGenericError 
                                   userInfo:[NSDictionary dictionaryWithObject:path forKey:@"sourcePath"]];
  [cm restClient:mockClient loadFileFailedWithError:error];
  STAssertNoThrow([mockDelegate verify],
                  @"Should get the cacheManager:didFailCacheOfDropBoxPath: message");
}

//
//  Tests the logic that determines cache state for paths.
//

- (void)testCacheStateForPath {
  
  DVCacheManager *cm = [[[DVCacheManager alloc] init] autorelease];
  NSDictionary *metadataDictionary = [self getMetadataDictionaryForPath:@"simple-metadata.plist"];
  cm.metadata = [[[DBMetadata alloc] initWithDictionary:metadataDictionary] autorelease];
  NSString *path = [DVCacheManager cachePathForDropBoxPath:kSimpleMetadataPath];
  NSString *newFile = [DVCacheManager cachePathForDropBoxPath:@"newfile.dat"];
  [self createTestContentAtPath:path];
  
  //
  //  Make the file at |path| have the correct timestamp.
  //
  
  DBMetadata *metadata = [cm metadataForPath:path];
  BOOL success = [[NSFileManager defaultManager] setAttributes:[NSDictionary dictionaryWithObject:metadata.lastModifiedDate 
                                                                                           forKey:NSFileModificationDate] 
                                                  ofItemAtPath:path 
                                                         error:NULL];
  STAssertTrue(success, @"Should be able to change timestamp");
  [self createTestContentAtPath:newFile];
  STAssertEquals(DVCacheStateEquivalent, [cm cacheStateForPath:path],
                 @"Should handle up-to-date content.");
  STAssertEquals(DVCacheStateDoesNotExist, [cm cacheStateForPath:@"nonexistent.dat"],
                 @"Should handle non-existent files");
  STAssertNil([cm metadataForPath:newFile], @"Should not be metadata for newFile");
  STAssertEquals(DVCacheStateOnlyLocal, [cm cacheStateForPath:newFile],
                 @"Should handle local-only files");
  
  //
  //  Set the last modified time on |path| to the distant past, then validate
  //  that isPathCurrent: returns NO.
  //
  
  success = [[NSFileManager defaultManager] setAttributes:[NSDictionary dictionaryWithObject:[NSDate distantPast] 
                                                                                      forKey:NSFileModificationDate] 
                                             ofItemAtPath:path 
                                                    error:NULL];
  STAssertTrue(success, @"Should be able to set NSFileModificationDate");
  STAssertEquals(DVCacheStateDropBoxLatest, [cm cacheStateForPath:path],
                 @"Should handle DropBox being newer");

  //
  //  Now make |path| be the the current date, which is later than what is in
  //  our fake DropBox metadata.
  //
  
  success = [[NSFileManager defaultManager] setAttributes:[NSDictionary dictionaryWithObject:[NSDate date] 
                                                                                      forKey:NSFileModificationDate] 
                                             ofItemAtPath:path 
                                                    error:NULL];
  STAssertTrue(success, @"Should be able to set NSFileModificationDate");
  STAssertEquals(DVCacheStateLocalLatest, [cm cacheStateForPath:path],
                 @"Should handle DropBox being newer");
}

//
//  Test file deletion.
//

- (void)testDeleteDropBoxPath {
  
  DVCacheManager *cm = [[[DVCacheManager alloc] init] autorelease];
  NSString *path = [DVCacheManager cachePathForDropBoxPath:kSimpleMetadataPath];
  DBMetadata *metadata = [[[DBMetadata alloc] initWithDictionary:[self getMetadataDictionaryForPath:@"simple-metadata.plist"]] 
                          autorelease];
  [cm restClient:nil loadedMetadata:metadata];
  [self createTestContentAtPath:path];
  
  //
  //  Listen to the messages sent to the restClient.
  //
  
  id mockClient = [OCMockObject mockForClass:[DBRestClient class]];
  [[mockClient expect] deletePath:kSimpleMetadataPath];
  cm.restClient = mockClient;

  STAssertTrue([[NSFileManager defaultManager] fileExistsAtPath:path],
               @"File has been created");
  STAssertEquals(DVCacheStateLocalLatest, [cm cacheStateForPath:path],
                 @"Should have correct state");
  
  [cm deleteDropBoxPath:kSimpleMetadataPath];
  STAssertFalse([[NSFileManager defaultManager] fileExistsAtPath:path],
                @"File has been created");
  STAssertEquals(DVCacheStateTombstone, [cm cacheStateForPath:path], 
                 @"Deleted files should be tombstoned");
  STAssertNoThrow([mockClient verify], 
                  @"Should send appropriate messages to restClient");
  
  //
  //  Recreate the |DVCacheManager|. Tombstone state should be preserved.
  //
  
  cm = [[[DVCacheManager alloc] init] autorelease];
  STAssertEquals(DVCacheStateTombstone, [cm cacheStateForPath:path], 
                 @"Deleted files should be tombstoned");
  
  //
  //  Now tell the cache manager that the file was really deleted.
  //
  
  cm.restClient = mockClient;
  [[mockClient expect] loadMetadata:kDropVaultPath];
  [cm restClient:nil deletedPath:kSimpleMetadataPath];
  STAssertNoThrow([mockClient verify], @"Should refresh metadata on deletion");
  [cm restClient:nil loadedMetadata:nil];
  STAssertEquals(DVCacheStateDoesNotExist, [cm cacheStateForPath:path], 
                 @"Deleted files should be tombstoned");
  cm = [[[DVCacheManager alloc] init] autorelease];
  STAssertEquals(DVCacheStateDoesNotExist, [cm cacheStateForPath:path], 
                 @"Deleted files should be tombstoned");
}

//
//  Test uploads.
//

- (void)testUpload {
  
  DVCacheManager *cm = [[[DVCacheManager alloc] init] autorelease];
  NSDictionary *metadataDictionary = [self getMetadataDictionaryForPath:@"simple-metadata.plist"];
  DBMetadata *metadata = [[[DBMetadata alloc] initWithDictionary:metadataDictionary] autorelease];
  cm.metadata = metadata;
  id mockClient = [OCMockObject mockForClass:[DBRestClient class]];
  cm.restClient = mockClient;
  id mockDelegate = [OCMockObject mockForProtocol:@protocol(DVCacheManagerDelegate)];
  cm.delegate = mockDelegate;
  
  //
  //  First, try with a nonexistent file. This should result in an error right
  //  away.
  //
  
  NSString *doesNotExist = @"/StrongBox/nonexistent.dat";
  [[mockDelegate expect] cacheManager:cm didFailUploadOfFile:doesNotExist];
  [cm uploadCacheToDropBoxPath:doesNotExist];
  STAssertNoThrow([mockDelegate verify], @"Should get error on nonexistent files");
  
  //
  //  Now, try uploading a new file.
  //
  
  NSString *newPath = @"/StrongBox/new.dat";
  NSString *newCachePath = [DVCacheManager cachePathForDropBoxPath:newPath];
  [self createTestContentAtPath:newCachePath];
  [[mockClient expect] uploadFile:[newPath lastPathComponent] 
                           toPath:[newPath stringByDeletingLastPathComponent]
                         fromPath:newCachePath];
  [cm uploadCacheToDropBoxPath:newPath];
  STAssertNoThrow([mockClient verify], @"Should try to upload files");
  
  //
  //  This means we should be in a pending upload state.
  //
  
  STAssertEquals(DVCacheStatePendingUpload, [cm cacheStateForPath:newCachePath], 
                 @"Should recognize DVCacheStatePendingUpload");
  
  //
  //  Pending upload persists to new objects.
  //
  
  DVCacheManager *cm2 = [[[DVCacheManager alloc] init] autorelease];
  STAssertEquals(DVCacheStatePendingUpload, [cm2 cacheStateForPath:newCachePath], 
                 @"New manager should remember DVCacheStatePendingUpload");
  
  //
  //  The new object should be able upload a file.
  //
  
  NSString *cm2File = @"/StrongBox/cm2file.dat";
  NSString *cm2CachePath = [DVCacheManager cachePathForDropBoxPath:cm2File];
  [self createTestContentAtPath:cm2CachePath];
  cm2.restClient = mockClient;
  [[mockClient expect] uploadFile:[cm2File lastPathComponent] 
                           toPath:[cm2File stringByDeletingLastPathComponent] 
                         fromPath:cm2CachePath];
  [cm2 uploadCacheToDropBoxPath:cm2File];
  STAssertNoThrow([mockClient verify], @"Should try to upload");
  
  //
  //  Make sure we're told about failure.
  //
  
  [[mockDelegate expect] cacheManager:cm didFailUploadOfFile:newPath];
  NSError *error = [NSError errorWithDomain:DBErrorDomain 
                                       code:DBErrorGenericError 
                                   userInfo:[NSDictionary dictionaryWithObject:newPath forKey:@"sourcePath"]];
  [cm restClient:mockClient uploadFileFailedWithError:error];
  STAssertNoThrow([mockDelegate verify], @"Should report failures");
  
  //
  //  Since we failed, we're still pending upload.
  //
  
  STAssertEquals(DVCacheStatePendingUpload, [cm cacheStateForPath:newCachePath], 
                 @"Should recognize DVCacheStatePendingUpload");

  //
  //  Finally, simulate success. The delegate should get notified and we're no
  //  longer in the pending upload state.
  //
  
  [[mockDelegate expect] cacheManager:cm didUploadFile:newPath];
  [cm restClient:nil uploadedFile:newPath from:newCachePath];
  STAssertNoThrow([mockDelegate verify], 
                  @"Delegate should get notified on upload success");
  STAssertEquals(DVCacheStateOnlyLocal, [cm cacheStateForPath:newCachePath], 
                 @"After successful upload, no longer upload pending");
  
  //
  //  Make sure the persisted upload state isn't stale.
  //
  
  DVCacheManager *cm3 = [[[DVCacheManager alloc] init] autorelease];
  STAssertEquals(DVCacheStateOnlyLocal, [cm3 cacheStateForPath:newCachePath], 
                 @"New manager should remember DVCacheStatePendingUpload");
}
@end

