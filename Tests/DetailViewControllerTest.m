//
//  DetailViewControllerTest.m
//  DropVault
//
//  Created by Brian Dewey on 1/31/11.
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
#import <OCMock/OCMock.h>
#import <UIKit/UIKit.h>
#import <CommonCrypto/CommonDigest.h>
#import "DetailViewController.h"
#import "RootViewController.h"
#import "NSManagedObjectModel+UnitTests.h"
#import "NSData+EncryptionHelpers.h"
#import "NSString+FileSystemHelper.h"

#define kDVTestPassword @"Orwell."
#define kBarItemCount     ((NSUInteger)6)

@interface DetailViewControllerTest : GTMTestCase {
  
}

@end

//
//  Creates a test |kDVKeyEntity| object that can be used to test the 
//  |DetailViewController|.
//

NSManagedObject * 
createObjectFixture(void) {
  
  //
  //  Set up in-memory core data.
  //
  
  NSManagedObjectContext *context = [NSManagedObjectModel inMemoryMOCFromBundle:[NSBundle mainBundle]];
  NSEntityDescription *entity = [NSEntityDescription entityForName:kDVKeyEntity 
                                            inManagedObjectContext:context];
  NSManagedObject *newManagedObject = [NSEntityDescription insertNewObjectForEntityForName:[entity name] 
                                                                    inManagedObjectContext:context];
  
  //
  //  Create a fake object with decrypted |key|, |iv|, |fileName| attributes.
  //
  
  NSString *keyName = @"20110124210018-1B2F353C.key";
  NSString *clearName = @"9DC33CF5BE145733F003CBD5F86EC979E3FF60AB.txt";
  [newManagedObject setValue:keyName forKey:kDVKeyName];
  [newManagedObject setValue:clearName
                      forKey:kDVFileName];
  [newManagedObject setValue:[NSData dataWithHexString:@"7F1B5F19AA935154FC9F04C7CE41F6B5"]
                      forKey:kDVKey];
  [newManagedObject setValue:[NSData dataWithHexString:@"356624F105CB9C29B507C5F9933913CA"]
                      forKey:kDVIV];
  return newManagedObject;
}

@implementation DetailViewControllerTest

//
//  Creates a |DetailViewController| with various mocks set up.
//

- (DetailViewController *)createControllerWithErrorHandler:(id)mockError 
                                              andDBSession:(id)mockDBSession
                                           andCacheManager:(id)mockManager
                                                andWebView:(id)mockWebView  {
  
  DetailViewController *controller = [[[DetailViewController alloc] init] autorelease];
  controller.errorHandler = mockError;
  controller.dbSession = mockDBSession;
  controller.cacheManager = mockManager;
  
  //
  //  For testing, we have to do all of the decryption on this thread.
  //
  
  controller.synchronousDecryption = YES;
  
  //
  //  Replace the WebView.
  //
  
  controller.webView = mockWebView;
  return controller;
}



//
//  Asserts non-nil bindings for |controller|.
//

- (void)assertNonNilBindingsForController:(DetailViewController *)controller {
  STAssertNotNil(controller.toolbar, @"Toolbar binding should exist");
  STAssertNotNil(controller.linkOrUnlinkButton, @"linkOrUnlinkButton binding should exist");
  STAssertNotNil(controller.webView, @"webView binding should exist");
  STAssertNotNil(controller.activityIndicator, @"activityIndicator binding should exist");
  STAssertNotNil(controller.progressBarButtonItem, @"progressBarButtonItem binding should exist");
  STAssertNotNil(controller.progressLabel, @"progressLabel binding should exist");
  STAssertNotNil(controller.progressView, @"progressView binding should exist");
  STAssertNotNil(controller.actionItem, @"actionItem binding should exist");
  STAssertNotNil(controller.detailDescriptionBarButtonItem, @"detailDescriptionBarButtonItem binding should exist");
  STAssertNotNil(controller.detailDescriptionLabel, @"detailDescriptionLabel binding should exist");
}

//
//  Asserts nil bindings for the controller.
//

- (void)assertNilBindingsForController:(DetailViewController *)controller {
  STAssertNil(controller.toolbar, @"Toolbar binding should not exist");
  STAssertNil(controller.linkOrUnlinkButton, @"linkOrUnlinkButton binding should not exist");
  STAssertNil(controller.webView, @"webView binding should not exist");
  STAssertNil(controller.activityIndicator, @"activityIndicator binding should not exist");
  STAssertNil(controller.progressBarButtonItem, @"progressBarButtonItem binding should not exist");
  STAssertNil(controller.progressLabel, @"progressLabel binding should not exist");
  STAssertNil(controller.progressView, @"progressView binding should not exist");
  STAssertNil(controller.actionItem, @"actionItem binding should not exist");
  STAssertNil(controller.detailDescriptionBarButtonItem, @"detailDescriptionBarButtonItem binding should not exist");
  STAssertNil(controller.detailDescriptionLabel, @"detailDescriptionLabel binding should not exist");
}

//
//  Makes sure all of the outlets are properly configured.
//

- (void)testBinding {
  DetailViewController *controller = [[[DetailViewController alloc] init] autorelease];
  [controller loadView];
  [controller viewDidLoad];
  
  STAssertEqualStrings(@"DetailView", 
                       controller.nibName, 
                       @"DetailViewController should know its nib name");
  [self assertNonNilBindingsForController:controller];
  STAssertFalse(controller.synchronousDecryption,
                @"DetailViewController should not default to synchronous decryption");
  STAssertEquals(kBarItemCount, [controller.toolbar.items count],
                 @"DetailViewController should have the right item count in the toolbar");
  
  [controller didReceiveMemoryWarning];
  [self assertNilBindingsForController:controller];
  
  [controller loadView];
  [self assertNonNilBindingsForController:controller];
  
  STAssertEqualStrings(@"Login", controller.linkOrUnlinkButton.title,
                       @"Login button defaults to 'Login'");
}

//
//  Verifies that I put the right toolbar items in place as I manipulate
//  progress indicators, etc. on the toolbar.
//

- (void)testToolbarItemSwaps {
  NSUInteger expectedToolbarItems = kBarItemCount;
  NSUInteger expectedLabelIndex = 1;
  DetailViewController *controller = [[[DetailViewController alloc] init] autorelease];
  [controller loadView];
  [controller viewDidLoad];
  STAssertEquals(expectedToolbarItems, [controller.toolbar.items count], 
                 @"The toolbar should have the right number of items.");
  STAssertEquals(expectedLabelIndex, 
                 [controller.toolbar.items indexOfObject:controller.detailDescriptionBarButtonItem],
                 @"The detail description label should be in the right place.");
  STAssertEquals((NSUInteger)NSNotFound,
                 [controller.toolbar.items indexOfObject:controller.progressBarButtonItem],
                 @"The progress view should not be found");
  
  [controller showProgressItem:@"Testing"];
  STAssertEquals(expectedToolbarItems, [controller.toolbar.items count], 
                 @"The toolbar has the right number of items.");
  STAssertEquals((NSUInteger)NSNotFound, 
                 [controller.toolbar.items indexOfObject:controller.detailDescriptionBarButtonItem],
                 @"The detail description label should NOT found");
  STAssertEquals(expectedLabelIndex,
                 [controller.toolbar.items indexOfObject:controller.progressBarButtonItem],
                 @"The progress view should found");
  
  [controller hideProgressItem];
  STAssertEquals(expectedToolbarItems, [controller.toolbar.items count], 
                 @"The toolbar should have the right number of items.");
  STAssertEquals(expectedLabelIndex, 
                 [controller.toolbar.items indexOfObject:controller.detailDescriptionBarButtonItem],
                 @"The detail description label should be in the right place.");
  STAssertEquals((NSUInteger)NSNotFound,
                 [controller.toolbar.items indexOfObject:controller.progressBarButtonItem],
                 @"The progress view should not be found");
}

//
//  Test the initial value of the login button text when the user is already
//  logged in to DropBox.
//

- (void)testLoginButtonWhenLoggedIn {
  DetailViewController *controller = [[[DetailViewController alloc] init] autorelease];
  id mockSession = [OCMockObject mockForClass:[DBSession class]];
  BOOL isLinked = YES;
  [[[mockSession stub] andReturnValue:OCMOCK_VALUE(isLinked)] isLinked];
  controller.dbSession = mockSession;
  [controller loadView];
  [controller viewDidLoad];
  STAssertEqualStrings(@"Logout", controller.linkOrUnlinkButton.title,
                       @"Link/unlink button is 'Logout' if already logged in");
}

//
//  Computes the SHA-1 hash for a file. Returns it as a |hexString|.
//

- (NSString *)hashForFile:(NSString *)outputFileName {
  NSData *clearData = [NSData dataWithContentsOfFile:outputFileName];
  NSMutableData *clearDigest = [NSMutableData dataWithLength:CC_SHA1_DIGEST_LENGTH];
  CC_SHA1([clearData bytes], [clearData length], [clearDigest mutableBytes]);
  return [clearDigest hexString];
}

//
//  Test that successfully downloaded files get decrypted and displayed in the 
//  webView.
//

- (void)testSuccessfulDownload {
  id mockError = [OCMockObject mockForClass:[DVErrorHandler class]];
  id mockManager = [OCMockObject mockForClass:[DVCacheManager class]];

  //
  //  We get one message for the main file, then two messages for the notes files.
  //
  
  [[mockManager expect] cacheCopyOfDropBoxPath:OCMOCK_ANY];
  [[mockManager expect] cacheCopyOfDropBoxPath:OCMOCK_ANY];
  [[mockManager expect] cacheCopyOfDropBoxPath:OCMOCK_ANY];
  
  //
  //  Create a mock UIWebView to ensure we get a loadRequest: message at the
  //  end of successful decryption.
  //
  
  id mockWebView = [OCMockObject mockForClass:[UIWebView class]];
  [[mockWebView expect] loadRequest:OCMOCK_ANY];
  DetailViewController *controller = [self createControllerWithErrorHandler:mockError 
                                                               andDBSession:nil
                                                            andCacheManager:mockManager
                                                                 andWebView:mockWebView];
  
  
  NSManagedObject *newManagedObject = createObjectFixture();
  
  //
  //  Set this as the selected item. It should cause decode.
  //
  
  controller.detailItem = newManagedObject;
  
  //
  //  We should have gotten a loadFile:intoPath: message.
  //
  
  [mockManager verify];
  
  //
  //  OK, now feed it a file and make sure it decrypts.
  //
  
  NSString *clearName2 = [newManagedObject valueForKey:kDVFileName];
  NSString *cipherName = [[[newManagedObject valueForKey:kDVKeyName] stringByDeletingPathExtension] 
                          stringByAppendingPathExtension:@"dat"];
  
  [[NSFileManager defaultManager] copyItemAtPath:[[[NSBundle mainBundle] bundlePath] stringByAppendingPathComponent:cipherName] 
                                          toPath:[cipherName asPathInDocumentsFolder]
                                           error:nil];
  controller.cacheDataPath = [cipherName asPathInDocumentsFolder];
  [controller cacheManager:mockManager didCacheCopyOfFile:[cipherName asPathInDocumentsFolder]];
  
  STAssertTrue([[NSFileManager defaultManager] fileExistsAtPath:[clearName2 asPathInTemporaryFolder]],
               @"DetailViewController should decrypt file");
  STAssertEqualStrings([clearName2 stringByDeletingPathExtension],
                       [self hashForFile:[clearName2 asPathInTemporaryFolder]],
                       @"DetailViewController should *properly* decrypt file");
  
  //
  //  This verifies that we received a loadRequest: message.
  //
  
  [mockWebView verify];
  
  //
  //  I should now be able to clear the detail item. This must remove
  //  the cleartext file both from the display and the file system.
  //
  
  NSURL *url = [NSURL fileURLWithPath:[[[NSBundle mainBundle] bundlePath] 
                                       stringByAppendingPathComponent:@"unlinked.html"]];
  NSURLRequest *request = [NSURLRequest requestWithURL:url];
  [[mockWebView expect] loadRequest:request];
  controller.detailItem = nil;
  STAssertFalse([[NSFileManager defaultManager] fileExistsAtPath:[clearName2 asPathInTemporaryFolder]],
                @"DetailViewController should clean up files");
  STAssertNoThrow([mockWebView verify], @"DetailViewController should send loadRequest: to web view");
}

//
//  Test failed download.
//

- (void)testFailedDownload {
  
  id mockError = [OCMockObject mockForClass:[DVErrorHandler class]];
  DetailViewController *controller = [self createControllerWithErrorHandler:mockError 
                                                             andDBSession:nil 
                                                          andCacheManager:nil 
                                                               andWebView:nil];
  controller.errorHandler = mockError;
  
  //
  //  If the passed in file name doesn't match cacheDataPath, then no error
  //
  
  [controller cacheManager:nil didFailCacheOfFile:@"foo.dat"];
  
  //
  //  But if the passed in file name matches, then I should get an error.
  //
  
  controller.cacheDataPath = @"foo.dat";
  [[mockError expect] displayMessage:OCMOCK_ANY forError:OCMOCK_ANY];
  [controller cacheManager:nil didFailCacheOfFile:@"foo.dat"];
  STAssertNoThrow([mockError verify], @"Should report error");
}

//
//  Tests the |loginToDropBox| message.
//

- (void)testLoginToDropBox {
  BOOL isLinked = YES;
  id mockDbSession = [OCMockObject mockForClass:[DBSession class]];
  [[[mockDbSession stub] andReturnValue:OCMOCK_VALUE(isLinked)] isLinked];

  id mockManager = [OCMockObject mockForClass:[DVCacheManager class]];
  DetailViewController *controller = [self createControllerWithErrorHandler:nil 
                                                               andDBSession:mockDbSession
                                                            andCacheManager:mockManager
                                                                 andWebView:nil];
  
  //
  //  First: Send |loginToDropBox|, expect |unlink| on the |dbSession|.
  //
  
  [[mockDbSession expect] unlink];
  [controller loginToDropBox];
  STAssertNoThrow([mockDbSession verify], 
                  @"loginToDropBox should send expected messages");
  
  //
  //  Second: Set up a |rootViewController|. It should get |forgetAllDropBoxFiles|
  //  and the dbSession should still get |unlink|.
  //
  
  id mockRootViewController = [OCMockObject mockForClass:[RootViewController class]];
  controller.rootViewController = mockRootViewController;
  
  [[mockRootViewController expect] forgetAllDropBoxFiles];
  [[mockRootViewController expect] setPassword:nil];
  [[mockDbSession expect] unlink];
  [controller loginToDropBox];
  STAssertNoThrow([mockRootViewController verify], 
                  @"loginToDropBox should send expected messages");
  STAssertNoThrow([mockDbSession verify], 
                  @"loginToDropBox should send expected messages");
  
  //
  //  Third, set the detail item. Note this will trigger a cacheCopyOfDropBoxPath:
  //  message for both the main item AND the notes files. Thus the three |expect|.
  //
  
  [[mockManager expect] cacheCopyOfDropBoxPath:OCMOCK_ANY];
  [[mockManager expect] cacheCopyOfDropBoxPath:OCMOCK_ANY];
  [[mockManager expect] cacheCopyOfDropBoxPath:OCMOCK_ANY];
  
  NSManagedObject *detailItem = createObjectFixture();
  controller.detailItem = detailItem;
  STAssertNoThrow([mockManager verify], @"Should get loadFile:intoPath:");
  
  [[mockRootViewController expect] forgetAllDropBoxFiles];
  [[mockRootViewController expect] setPassword:nil];
  [[mockDbSession expect] unlink];
  [controller loginToDropBox];
  STAssertNoThrow([mockRootViewController verify], 
                  @"loginToDropBox should send expected messages");
  STAssertNoThrow([mockDbSession verify], 
                  @"loginToDropBox should send expected messages");
  STAssertNil(controller.detailItem, @"detailItem should be nil after logout");
}

//
//  If you send the presentPasswordController message more than once, you 
//  should still only show one password dialog.
//

- (void)testMultiplePresentPasswordController {
  
  //
  //  I need a mock |DBSession| that says that we're linked with DropBox.
  //
  
  BOOL isLinked = YES;
  id mockSession = [OCMockObject mockForClass:[DBSession class]];
  [[[mockSession stub] andReturnValue:OCMOCK_VALUE(isLinked)] isLinked];
  
  //
  //  The mockRoot will expect exactly one presentModalViewController:animated:
  //  message.
  //
  
  id mockRoot = [OCMockObject mockForClass:[RootViewController class]];
  [[mockRoot expect] presentModalViewController:OCMOCK_ANY animated:YES];
  
  DetailViewController *controller = [[[DetailViewController alloc] init] autorelease];
  controller.dbSession = mockSession;
  controller.rootViewController = mockRoot;
  
  [controller presentPasswordController];
  STAssertNoThrow([mockRoot verify], 
                  @"DetailViewController should send proper messages to rootViewController on presentPasswordController");
  
  //
  //  Invoke again. We should get no more messages. 
  //  (Note I don't have another [mockRoot expect].)
  //
  
  [controller presentPasswordController];
  STAssertNoThrow([mockRoot verify], 
                  @"DetailViewController should send proper messages to rootViewController on presentPasswordController");
  
}

@end
