//
//  RootViewControllerTest.m
//  DropVault
//
//  Created by Brian Dewey on 1/25/11.
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
#import "RootViewController.h"
#import "NSManagedObjectModel+UnitTests.h"
#import <OCMock/OCMock.h>
#import "NSString+SBJSON.h"
#import "NSString+FileSystemHelper.h"
#import "DVCacheManager.h"

#define kDVTestPassword         @"Orwell."

@interface RootViewControllerTest : GTMTestCase {
}

@end


@implementation RootViewControllerTest

//
//  Create a root view controller, all ready to test, with specific 
//  dbSession and restClient objects wired up. If you pass nil for any of the
//  test objects, then the |RootViewController| will get mock objects that fail
//  on any message.
//

- (RootViewController *)rootControllerWithSession:(id)dbSession
                                  andCacheManager:(id)cacheManager {

  RootViewController *controller = [[[RootViewController alloc] init] autorelease];
  
  //
  //  Assign mock objects, creating them if necessary.
  //
  
  if (dbSession == nil) {
    dbSession = [OCMockObject mockForClass:[DBSession class]];
  }
  controller.dbSession = dbSession;
  if (cacheManager == nil) {
    cacheManager = [OCMockObject mockForClass:[DVCacheManager class]];
  }
  controller.cacheManager = cacheManager;
  
  //
  //  Need to initialize Core Data...
  //
  
  controller.managedObjectContext = [NSManagedObjectModel inMemoryMOCFromBundle:[NSBundle mainBundle]];
  
  
  return controller;
}

//
//  Loads a JSON-encoded file and converts it to a |DBMetadata| object. On error,
//  returns |nil|.
//

- (DBMetadata *)loadMetadataFromJsonFile:(NSString *)fileName {
  
  //
  //  The test metadata is in JSON format in the main bundle
  //  (DropBoxMetadata.json). Load it and turn it into a DBMetadata object.
  //
  
  NSStringEncoding encoding;
  NSError *error;
  NSString *metadataString = [NSString stringWithContentsOfFile:fileName
                                                   usedEncoding:&encoding
                                                          error:&error];
  if (metadataString == nil) {
    return nil;
  }
  NSDictionary *metadataDictionary = [metadataString JSONValue];
  DBMetadata *metadata = [[[DBMetadata alloc] initWithDictionary:metadataDictionary] autorelease];
  return metadata;
}

//
//  Validates that the view properly loaded.
//

- (void)testViewLoad {
  RootViewController *controller = [[[RootViewController alloc] init] autorelease];
  
  [controller loadView];
  STAssertNil(controller.nibName, @"RootViewController should not have a nib");
}

//
//  When the view loads, it should call |loadMetadata| on its restClient
//  object.
//

- (void)testLoadMetadata {
  
  //
  //  Set up a mock object for the |dbSession|. It should return |true| for
  //  |isLinked|, which should cause the controller to query for metadata.
  //
  
  BOOL isLinked = YES;
  id mockSession = [OCMockObject mockForClass:[DBSession class]];
  [[[mockSession stub] andReturnValue:OCMOCK_VALUE(isLinked)] isLinked];
  
  //
  //  Mock object for the rest client. Note ugly cast... it's to avoid
  //  a "multiple methods found" warning.
  //
  
  id mockManager = [OCMockObject mockForClass:[DVCacheManager class]];
  [[mockManager expect] loadMetadata];
  
  RootViewController *controller = [self rootControllerWithSession:mockSession 
                                                   andCacheManager:mockManager];
  
  //
  //  Finally, load the controller views and verify we got the loadMetadata
  //  call.
  //
  
  [controller loadView];
  [controller viewDidLoad];
  [mockManager verify];
}

//
//  Verify that if loadMetadataFailedWithError gets invoked, nothing happens.
//

- (void)testLoadMetadataFailed {
  
  id mockErrorHandler = [OCMockObject mockForClass:[DVErrorHandler class]];
  RootViewController *controller = [self rootControllerWithSession:nil 
                                                   andCacheManager:nil];
  controller.errorHandler = mockErrorHandler;
  [controller cacheManagerLoadMetadataFailed:nil];
  STAssertNoThrow([mockErrorHandler verify], @"Root Controller should not report errors");
}

//
//  When the view loads but it does not think that it's linked to DropBox,
//  then it SHOULD NOT call |loadMetadata|.
//

- (void)testViewLoadNoDropBoxLink {
  
  //
  //  DBSession mock object.
  //
  
  BOOL isLinked = NO;
  id mockSession = [OCMockObject mockForClass:[DBSession class]];
  [[[mockSession stub] andReturnValue:OCMOCK_VALUE(isLinked)] isLinked];
  
  RootViewController *controller = [self rootControllerWithSession:mockSession 
                                                   andCacheManager:nil];
  
  [controller loadView];
  [controller viewDidLoad];
}

//
//  Tests restClient:loadedMetadata. The root controller should create an 
//  managed data object for each metadata item.
//

- (void)testLoadedMetadata {
  
  //
  //  The test metadata is in JSON format in the main bundle
  //  (DropBoxMetadata.json). Load it and turn it into a DBMetadata object.
  //
  
  DBMetadata *metadata = [self loadMetadataFromJsonFile:[[[NSBundle mainBundle] bundlePath] stringByAppendingPathComponent:@"DropBoxMetadata.json"]];
  STAssertNotNil(metadata, @"Should be able to load metadata");
  
  //
  //  Create a mock object rest client that expects to get loadFile:intoPath:
  //  called.
  //
  
  id mockManager = [OCMockObject mockForClass:[DVCacheManager class]];
  [[mockManager expect] cacheCopyOfDropBoxPath:OCMOCK_ANY];
  [[[mockManager stub] andReturn:metadata] metadata];
  [[[mockManager stub] andReturn:nil] metadataForPath:OCMOCK_ANY];
  
  RootViewController *controller = [self rootControllerWithSession:nil 
                                                   andCacheManager:mockManager];
  
  //
  //  Finally, invoke the controller.
  //
  
  [controller cacheManagerDidLoadMetadata:mockManager];
  
  //
  //  Make sure we got our loadFile:intoPath: message.
  //
  
  [mockManager verify];
  
  //
  //  Validate the objects in our in-memory object context.
  //
  
  NSArray *objects = [controller fetchObjectsForPredicate:nil error:nil];
  STAssertNotNil(objects, @"Should find results");
  STAssertEquals((NSUInteger)1, [objects count], @"Should find one object");
  NSManagedObject *object = [objects objectAtIndex:0];
  NSString *keyName = [object valueForKey:kDVKeyName];
  STAssertEqualStrings(@"/StrongBox/foo.key",
                       keyName,
                       @"Should properly persist key name");
}

//
//  Calls [controller restClient:loadMetadata] and then validates that there
//  are the expected number of objects in the root view controller.
//

- (void)verifyLoadMetadataObjectsForController:(RootViewController *)controller
                                   andMetadata:(DBMetadata *)metadata
                                newObjectCount:(NSUInteger)newObjectCount
                              totalObjectCount:(NSUInteger)objectCount  {

  id cacheManager = [OCMockObject mockForClass:[DVCacheManager class]];
  [[[cacheManager stub] andReturn:nil] metadataForPath:OCMOCK_ANY];
  controller.cacheManager = cacheManager;
  
  //
  //  Our mock object should get called once for each new object.
  //
  
  for (int i = 0; i < newObjectCount; i++) {
    [[cacheManager expect] cacheCopyOfDropBoxPath:OCMOCK_ANY];
  }
  [[[cacheManager stub] andReturn:metadata] metadata];
  [controller cacheManagerDidLoadMetadata:cacheManager];
  STAssertNoThrow([cacheManager verify], 
                  @"Should get the expected cacheCopyOfDropBoxPath: messages");
  NSArray *objects = [controller fetchObjectsForPredicate:nil error:nil];
  STAssertNotNil(objects, @"Should find results in the controller");
  STAssertEquals(objectCount, [objects count], 
                 @"Should find the correct number of objects");
}

//
//  When metadata gets loaded multiple times, |RootViewController| must forget
//  about any keys that existed in prior metadata calls but no longer exist
//  (the deleted file problem). Any files that currently exist must not be
//  double-counted.
//

- (void)testReloadMetadata {
  NSString *bundlePath = [[NSBundle mainBundle] bundlePath];
  id mockSession = [OCMockObject mockForClass:[DBSession class]];
  id mockErrorHandler = [OCMockObject mockForClass:[DVErrorHandler class]];
  BOOL isLinkedValue = NO;
  [[[mockSession stub] andReturnValue:OCMOCK_VALUE(isLinkedValue)] isLinked];
  RootViewController *controller = [self rootControllerWithSession:mockSession
                                                   andCacheManager:nil];
  controller.errorHandler = mockErrorHandler;
  DBMetadata *metadata;
  
  metadata = [self loadMetadataFromJsonFile:[bundlePath stringByAppendingPathComponent:@"DropBoxMetadata.json"]];
  [self verifyLoadMetadataObjectsForController:controller 
                                   andMetadata:metadata 
                                newObjectCount:1
                              totalObjectCount:1];
  
  //
  //  In this case, we've added two |.key| files to the metadata listing, and there
  //  is one |.key| file that was in the last call. We should have 3 objects
  //  in the controller at the end (not 4, which would happen if we didn't detect
  //  that one |.key| file was already there).
  //
  
  metadata = [self loadMetadataFromJsonFile:[bundlePath stringByAppendingPathComponent:@"MetadataAddFiles.json"]];
  [self verifyLoadMetadataObjectsForController:controller 
                                   andMetadata:metadata 
                                newObjectCount:2
                              totalObjectCount:3];
  
  //
  //  If I do this again, I should find no new objects.
  //
  
  [self verifyLoadMetadataObjectsForController:controller 
                                   andMetadata:metadata 
                                newObjectCount:0
                              totalObjectCount:3];
  
  
  //
  //  Now... One file has been removed. We should get no new objects and wind
  //  up with a total object count of 2.
  //
  
  metadata = [self loadMetadataFromJsonFile:[bundlePath stringByAppendingPathComponent:@"MetadataRemoveFiles.json"]];
  [self verifyLoadMetadataObjectsForController:controller
                                   andMetadata:metadata
                                newObjectCount:0
                              totalObjectCount:2];
  
  //
  //  Next, load a metadata that has two sidecar files added. This should 
  //  generate no new objects.
  //
  
  metadata = [self loadMetadataFromJsonFile:[bundlePath stringByAppendingPathComponent:@"MetadataSidecarFiles.json"]];
  [self verifyLoadMetadataObjectsForController:controller 
                                   andMetadata:metadata 
                                newObjectCount:0 
                              totalObjectCount:2];
  
  //
  //  Now, for grins, see if I can delete one of the objects.
  //
  
  [controller.fetchedResultsController performFetch:nil];
  NSArray *objects = [controller.fetchedResultsController fetchedObjects];
  _GTMDevAssert([objects count] == 2, @"Should have objects");
  NSUInteger indexes[] = { 0, 0 };
  NSIndexPath *indexPath = [NSIndexPath indexPathWithIndexes:indexes 
                                                      length:sizeof(indexes) / sizeof(NSUInteger)];
  NSManagedObject *victim = [controller.fetchedResultsController objectAtIndexPath:indexPath];
  STAssertNotNil(victim, @"Should have a victim");
  
  //
  //  We will get 2 calls to deletePath, one for the key and one for the dat
  //
  
  id mockManager = [OCMockObject mockForClass:[DVCacheManager class]];
  controller.cacheManager = mockManager;
  [[mockManager expect] deleteDropBoxPath:OCMOCK_ANY];
  [[mockManager expect] deleteDropBoxPath:OCMOCK_ANY];
  
  //
  //  For some reason, I can't save the deletes. It's probably something I'm
  //  doing wrong with Core Data in this test environment. So for now let's
  //  just expect and ignore the error.
  //
  
  [[mockErrorHandler expect] displayMessage:OCMOCK_ANY forError:OCMOCK_ANY];
  
  [controller tableView:nil 
     commitEditingStyle:UITableViewCellEditingStyleDelete 
      forRowAtIndexPath:indexPath];
  STAssertEquals((NSUInteger)1, 
                 [[controller fetchObjectsForPredicate:nil error:nil] count],
                 @"Should have deleted victim");
  STAssertNoThrow([mockManager verify], @"Should have received 2 deletePath: messages");
  STAssertNoThrow([mockErrorHandler verify], @"Should have received spurious error");
}

//
//  Copies a file from the bundle path to the documents path. Fails the test
//  if there is an error.
//

- (void)copyFileFromBundleToCache:(NSString *)keyFile {
  NSError *error;
  NSString *keyFileInBundle = [[[NSBundle mainBundle] bundlePath] stringByAppendingPathComponent:[keyFile lastPathComponent]];
  NSString *keyFileInDocuments = [DVCacheManager cachePathForDropBoxPath:keyFile];
  _GTMDevLog(@"%s -- copying %@ to %@", 
             __PRETTY_FUNCTION__,
             keyFileInBundle,
             keyFileInDocuments);
  
  //
  //  Make sure we have the containing directory.
  //
  
  [[NSFileManager defaultManager] createDirectoryAtPath:[keyFileInDocuments stringByDeletingLastPathComponent]
                            withIntermediateDirectories:YES 
                                             attributes:nil 
                                                  error:NULL];

  
  //
  //  Make sure the documents file isn't there.
  //
  
  [[NSFileManager defaultManager] removeItemAtPath:keyFileInDocuments error:nil];
  if (![[NSFileManager defaultManager] copyItemAtPath:keyFileInBundle 
                                               toPath:keyFileInDocuments 
                                                error:&error]) {
    _GTMDevLog(@"%s -- unexpected error copying files: %@",
               __PRETTY_FUNCTION__,
               error);
    STFail(@"Could not copy key file %@ to %@", 
           keyFileInBundle, 
           keyFileInDocuments);
  }
}

//
//  Test behavior for restClient:loadedFile: message.
//  This should cause the corresponding key to get decrypted. The most important
//  observable thing that happens with a decrypted key is the |kDVFileName|
//  attribute will be set.
//

- (void)testLoadFileIntoPath {
  NSString *bundlePath = [[NSBundle mainBundle] bundlePath];
  
  //
  //  We need a mockSession to respond to the isLinked message.
  //
  
  id mockSession = [OCMockObject mockForClass:[DBSession class]];
  BOOL isLinked = NO;
  [[[mockSession stub] andReturnValue:OCMOCK_VALUE(isLinked)] isLinked];
  id mockManager = [OCMockObject mockForClass:[DVCacheManager class]];
  RootViewController *controller = [self rootControllerWithSession:mockSession
                                                   andCacheManager:mockManager];
  DBMetadata *metadata;
  
  metadata = [self loadMetadataFromJsonFile:[bundlePath stringByAppendingPathComponent:@"MetadataAddFiles.json"]];
  [self verifyLoadMetadataObjectsForController:controller 
                                   andMetadata:metadata 
                                newObjectCount:3
                              totalObjectCount:3];
  
  //
  //  Mapping of key file names to decrypted file names.
  //
  
  
  NSString *keyFile = @"/StrongBox/20110124210018-26185D7F.key";
  NSString *keyFile2 = @"/StrongBox/20110124210018-1B2F353C.key";
  
  //
  //  Make sure these files aren't there.
  //
  
  [[NSFileManager defaultManager] removeItemAtPath:[DVCacheManager cachePathForDropBoxPath:keyFile] 
                                             error:nil];
  [[NSFileManager defaultManager] removeItemAtPath:[DVCacheManager cachePathForDropBoxPath:keyFile2] 
                                             error:nil];
  NSDictionary *keyToClearNames = [NSDictionary dictionaryWithObjectsAndKeys:
                                   @"E9AFCB203225CBB36012C61D79365070940243A0.txt", keyFile,
                                   @"9DC33CF5BE145733F003CBD5F86EC979E3FF60AB.txt", keyFile2,
                                   nil];
  
  //
  //  Tell the controller that the file was copied.
  //
  
  [DVCacheManager createCacheRootDirectory];
  [self copyFileFromBundleToCache:keyFile];
  [controller cacheManager:mockManager didCacheCopyOfFile:[DVCacheManager cachePathForDropBoxPath:keyFile]];
  
  for (NSManagedObject *object in [controller fetchObjectsForPredicate:nil error:nil]) {
    
    //
    //  We couldn't decrypt anything because we don't have a password.
    //
    
    STAssertNil([object valueForKey:kDVFileName],
                @"RootController should not decrypt keys without a password.");
  }
  
  controller.password = kDVTestPassword;
  
  //
  //  Now, find the corresponding Core Data object and validate that the
  //  key had been decrypted.
  //
  
  for (NSManagedObject *object in [controller fetchObjectsForPredicate:nil error:nil]) {
    NSString *keyName = [object valueForKey:kDVKeyName];
    if ([keyName isEqual:keyFile]) {
      
      //
      //  This is the object that should have been decrypted.
      //
      
      STAssertEqualStrings([keyToClearNames valueForKey:keyFile],
                           [object valueForKey:kDVFileName],
                           @"RootController should decrypt key name");
      
    } else {
      
      //
      //  We didn't/couldn't decrypt this key, so the file name should
      //  not be set.
      //
      
      STAssertNil([object valueForKey:kDVFileName],
                  @"RootController should not decrypt keys that have not been downloaded");
    }
  }
  
  //
  //  For completeness, call restClient:loadedFile: when the password is
  //  already set. Verify that it's decrypted right away.
  //
  
  [self copyFileFromBundleToCache:keyFile2];
  STAssertNoThrow([controller cacheManager:mockManager didCacheCopyOfFile:[DVCacheManager cachePathForDropBoxPath:keyFile2]],
                  nil);
  for (NSManagedObject *object in [controller fetchObjectsForPredicate:nil error:nil]) {
    NSString *keyName = [object valueForKey:kDVKeyName];
    STAssertEqualStrings([keyToClearNames valueForKey:keyName],
                         [object valueForKey:kDVFileName],
                         @"RootController should have decrypted all keys");
  }
  
  //
  //  Finally, clear the password. The controller should throw away all
  //  decrypted text.
  //
  
  controller.password = nil;
  for (NSManagedObject *object in [controller fetchObjectsForPredicate:nil error:nil]) {
    STAssertNotNil([object valueForKey:kDVKeyName], @"RootViewController should remember key name");
    STAssertNil([object valueForKey:kDVFileName], @"RootViewController should forget cleartext file name");
    STAssertNil([object valueForKey:kDVKey], @"RootViewController should forget file decryption key");
    STAssertNil([object valueForKey:kDVIV], @"RootViewController should forget file IV");
  }
}

@end
