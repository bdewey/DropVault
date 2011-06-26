//
//  DetailViewController.m
//  DropboxPrototype
//
//  Created by Brian Dewey on 1/12/11.
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

#import "DropboxSDK.h"
#import "DetailViewController.h"
#import "RootViewController.h"
#import "NSData+EncryptionHelpers.h"
#import "NSString+FileSystemHelper.h"
#import "PasswordController.h"
#import <CommonCrypto/CommonCryptor.h>
#import "DVTextEditController.h"
#import "KeyFileDecryptor.h"

//
//  Private declarations...
//

@interface DetailViewController ()

//
//  Our popover controller.
//

@property (nonatomic, retain) UIPopoverController *popoverController;

- (void)showPageFromBundle:(NSString *)pageFileName;
- (void)configureView;
- (void)showProgressItem:(NSString *)label;
- (void)hideProgressItem;
- (void)presentPasswordController;
@end



@implementation DetailViewController

@synthesize rootViewController = rootViewController_;
@synthesize detailItem = detailItem_;
@synthesize dbSession = dbSession_;
@synthesize cacheManager = cacheManager_;
@synthesize cacheDataPath = cacheDataPath_;
@synthesize password = password_;
@synthesize docIC = docIC_;
@synthesize errorHandler = errorHandler_;
@synthesize synchronousDecryption = synchronousDecryption_;
@synthesize toolbar = toolbar_;
@synthesize linkOrUnlinkButton = linkOrUnlinkButton_;
@synthesize webView = webView_;
@synthesize activityIndicator = activityIndicator_;
@synthesize progressBarButtonItem = progressBarButtonItem_;
@synthesize progressLabel = progressLabel_;
@synthesize progressView = progressView_;
@synthesize detailDescriptionBarButtonItem = detailDescriptionBarButtonItem_;
@synthesize detailDescriptionLabel = detailDescriptionLabel_;
@synthesize actionItem = actionItem_;
@synthesize popoverController = popoverController_;
@synthesize notesButton = notesButton_;

#pragma mark -
#pragma mark Managing the detail item

//
//  When setting the detail item, update the view and dismiss the popover 
//  controller if it's showing.
//
- (void)setDetailItem:(NSManagedObject *)managedObject {
  
  if (self.detailItem != managedObject) {
    NSString *fileName = [self.detailItem valueForKey:kDVFileName];
    if ([fileName length] > 0) {
      [[NSFileManager defaultManager] removeItemAtPath:[fileName asPathInTemporaryFolder] error:nil];
    }
    [detailItem_ release];
    detailItem_ = [managedObject retain];
    
    // Update the view.
    [self configureView];
  }
  
  if (self.popoverController != nil) {
    [self.popoverController dismissPopoverAnimated:YES];
  }		
}

//
//  Shows an HTML page that is stored in the application bundle.
//

- (void)showPageFromBundle:(NSString *)pageFileName {
  NSString *path = [[NSBundle mainBundle] pathForResource:pageFileName ofType:nil];
  NSURL *url = [NSURL fileURLWithPath:path];
  NSURLRequest *request = [NSURLRequest requestWithURL:url];
  [self.webView loadRequest:request];
}

//
//  Show HTML content appropriate for having no active document selected.
//

- (void)showFishbowlPage {
  if ([self.dbSession isLinked]) {
    [self showPageFromBundle:@"welcome.html"];
  } else {
    [self showPageFromBundle:@"unlinked.html"];
  }
  self.detailDescriptionLabel.text = kProgramName;
}

//
//  Updates the view when |detailItem_| changes.
//

- (void)configureView {
  
  //
  //  If |detailItem_| is not valid, show the fishbowl.
  //
  
  if (detailItem_ == nil || ![detailItem_ valueForKey:kDVFileName] || ([[detailItem_ valueForKey:kDVFileName] length] == 0)) {
    [self showFishbowlPage];
    return;
  }
  
  //
  //  Convert the key name into the encrypted data name
  //
  
  NSString *keyName = [self.detailItem valueForKey:kDVKeyName];
  NSString *cipherName = [[keyName stringByDeletingPathExtension] stringByAppendingPathExtension:@"dat"];
  _GTMDevLog(@"%s -- looking for cipher data in %@", __PRETTY_FUNCTION__, cipherName);

  [self showProgressItem:kDVStringDownloading];
  cacheDataPath_ = [[DVCacheManager cachePathForDropBoxPath:cipherName] retain];
  [self.cacheManager cacheCopyOfDropBoxPath:cipherName];
  
  //
  //  Now, cache the notes files.
  //
  
  [self.cacheManager cacheCopyOfDropBoxPath:[keyName stringAsSidecarPath]];
  [self.cacheManager cacheCopyOfDropBoxPath:[cipherName stringAsSidecarPath]];
}

#pragma mark -
#pragma mark Error Handling

//
//  Gets the error handler. If one has not been set, creates one.
//

- (DVErrorHandler *)errorHandler {
  if (errorHandler_ == nil) {
    errorHandler_ = [[DVErrorHandler alloc] init];
  }
  return errorHandler_;
}

#pragma mark -
#pragma mark Progress Indicators

//
//  Updates the toolbar to show a progress bar with a label. When the progress
//  bar is shown on the toolbar, you can update it by manipulating |progressView|.
//

- (void)showProgressItem:(NSString *)label {
  self.progressLabel.text = label;
  self.progressView.progress = 0.0;
  NSMutableArray *items = [NSMutableArray arrayWithArray:toolbar_.items];
  int index = [items indexOfObject:detailDescriptionBarButtonItem_];
  if (index != NSNotFound) {
    [items replaceObjectAtIndex:index withObject:progressBarButtonItem_];
  }
  [self.toolbar setItems:items animated:NO];
}

//
//  Hides the progress bar.
//

- (void)hideProgressItem {
  NSMutableArray *items = [NSMutableArray arrayWithArray:toolbar_.items];
  int index = [items indexOfObject:progressBarButtonItem_];
  if (index != NSNotFound) {
    [items replaceObjectAtIndex:index withObject:detailDescriptionBarButtonItem_];
  }
  [self.toolbar setItems:items animated:NO];
}

#pragma mark -
#pragma mark Notes

//
//  Gets a |DVTextEditController| all preconfigured for showing modally.
//

- (id)textEditor {
  DVTextEditController *textEditor = [[[DVTextEditController alloc] init] autorelease];
  textEditor.delegate = self;
  UINavigationController *nav = [[[UINavigationController alloc] initWithRootViewController:textEditor] autorelease];
  nav.modalTransitionStyle = UIModalTransitionStyleCoverVertical;
  nav.modalPresentationStyle = UIModalPresentationFormSheet;
  nav.navigationBar.barStyle = UIBarStyleBlackOpaque;
  return nav;
}

//
//  PRIVATE: Gets the decrypted content from the cached notes file, or the
//  empty string if there is no cached notes file.
//

- (NSString *)getCurrentNotes {
  
  NSString *notesData = [self.cacheDataPath stringAsSidecarPath];
  NSString *notesKey  = [[[self.cacheDataPath stringByDeletingPathExtension] stringByAppendingPathExtension:@"key"] stringAsSidecarPath];
  KeyFileDecryptor *kfd;
  NSData *keyData = [NSData dataWithContentsOfFile:notesKey];
  if (keyData != nil) {
    
    //
    //  Need to decrypt the key.
    //
    
    kfd = [KeyFileDecryptor decryptorWithData:keyData andPassword:self.password];
    
  } else {
    
    //
    //  Need to make a key for the notes file.
    //
    
    kfd = [[KeyFileDecryptor alloc] init];
    kfd.key = [NSData dataWithRandomBytes:kCCKeySizeAES128];
    kfd.iv  = [NSData dataWithRandomBytes:kCCBlockSizeAES128];
    kfd.fileName = @"notes.txt";
    kfd.password = self.password;
    [[kfd encryptedBlob] writeToFile:notesKey atomically:YES];
  }
  NSMutableData *cipherData = [NSMutableData dataWithContentsOfFile:notesData];
  [cipherData aesDecryptInPlaceWithKey:kfd.key andIV:kfd.iv];
  return [[[NSString alloc] initWithData:cipherData encoding:NSUTF8StringEncoding] autorelease];
}

//
//  PRIVATE: Encrypts notes, saves them, and sends them up to DropBox.
//

- (void)saveCurrentNotes:(NSString *)notes {
  
  NSString *notesData = [self.cacheDataPath stringAsSidecarPath];
  NSString *notesKey  = [[[self.cacheDataPath stringByDeletingPathExtension] stringByAppendingPathExtension:@"key"] stringAsSidecarPath];
  KeyFileDecryptor *kfd;
  NSData *keyData = [NSData dataWithContentsOfFile:notesKey];
  if (keyData != nil) {
    
    //
    //  Need to decrypt the key.
    //
    
    kfd = [KeyFileDecryptor decryptorWithData:keyData andPassword:self.password];
    
  } else {
    
    //
    //  Need to make a key for the notes file.
    //
    
    _GTMDevAssert(NO, @"Shouldn't get here");
    kfd = [[KeyFileDecryptor alloc] init];
    kfd.key = [NSData dataWithRandomBytes:kCCKeySizeAES128];
    kfd.iv  = [NSData dataWithRandomBytes:kCCBlockSizeAES128];
    kfd.fileName = @"notes.txt";
    kfd.password = self.password;
    [[kfd encryptedBlob] writeToFile:notesKey atomically:YES];
  }
  
  NSData *clearData = [notes dataUsingEncoding:NSUTF8StringEncoding];
  NSData *cipherData = [clearData aesEncryptWithKey:kfd.key andIV:kfd.iv];
  [cipherData writeToFile:notesData atomically:YES];
  
  //
  //  Push to DropBox.
  //
  
  _GTMDevLog(@"%s -- uploading %@ and %@",
             __PRETTY_FUNCTION__,
             notesKey,
             notesData);
  [self.cacheManager uploadCacheToDropBoxPath:[DVCacheManager dropBoxPathForCachePath:notesData]];
  [self.cacheManager uploadCacheToDropBoxPath:[DVCacheManager dropBoxPathForCachePath:notesKey]];
}


//
//  Show the notes UI.
//

- (IBAction)presentNotes:(id)sender {
  UINavigationController *editNavigator = [self textEditor];
  DVTextEditController *editor = (DVTextEditController *)editNavigator.topViewController;
  
  //
  //  The next line is just there to force the view to load.
  //  Is there a cleaner way to do this?
  //
  //  Without this, you can't override the text.
  //
  
  [editor view];
  editor.textView.text = [self getCurrentNotes];
  [self.rootViewController presentModalViewController:editNavigator animated:YES];
}

- (void)textEditControllerDidCancel:(DVTextEditController *)controller {
  [self.rootViewController dismissModalViewControllerAnimated:YES];
}

- (void)textEditControllerDidFinish:(DVTextEditController *)controller {
  UINavigationController *nav = (UINavigationController *)self.rootViewController.modalViewController;
  DVTextEditController *editor = (DVTextEditController *)[nav topViewController];
  [self saveCurrentNotes:editor.textView.text];
  [self.rootViewController dismissModalViewControllerAnimated:YES];
}

#pragma mark -
#pragma mark WebViewDelegate methods

//
//  There was an error showing the document; tell the user.
//

-(void)webView:(UIWebView *)webView didFailLoadWithError:(NSError *)error {
  [self.errorHandler displayMessage:kDVErrorShow forError:error];
}

//
//  The document is now loaded in |webView_|. Update the title bar with the
//  file name of the document.
//

-(void)webViewDidFinishLoad:(UIWebView *)webView {
  if (self.detailItem != nil && [self.detailItem valueForKey:kDVFileName] != nil) {
    NSMutableString *fileName = [NSMutableString stringWithString:[self.detailItem valueForKey:kDVFileName]];
    if ([fileName length] > 50) {
      [fileName deleteCharactersInRange:NSMakeRange(47, [fileName length]-47)];
      [fileName appendString:@"..."];
    }
    self.detailDescriptionLabel.text = fileName;
  }
}

//
//  If the user tries to load a link, don't let them. Launch Mobile Safari instead.
//

-(BOOL)webView:(UIWebView *)webView shouldStartLoadWithRequest:(NSURLRequest *)request navigationType:(UIWebViewNavigationType)navigationType {
  if (navigationType == UIWebViewNavigationTypeLinkClicked) {
    [[UIApplication sharedApplication] openURL:[request URL]];
    return NO;
  }
  return YES;
}

#pragma mark -
#pragma mark DecryptionStateMachineDelegate

//
//  Update |progressView_| to match the progress we've made decrypting the file.
//

-(void)decryptionStateMachine:(DecryptionStateMachine *)stateMachine
              didDecryptBytes:(unsigned long long)bytesDecrypted
                   outOfBytes:(unsigned long long)totalBytes {
  CGFloat progress = (CGFloat)bytesDecrypted / (CGFloat)totalBytes;
  self.progressView.progress = progress;
}


//
//  Decryption finished. Load the document into |self.webView|, hide the
//  progress indicator, and release the decryption state machine.
//

-(void)decryptionStateMachineDidFinish:(DecryptionStateMachine *)stateMachine {
  _GTMDevLog(@"%s", __PRETTY_FUNCTION__);
  NSURL *url = [NSURL fileURLWithPath:stateMachine.outputFilePath];
  NSURLRequest *request = [NSURLRequest requestWithURL:url];
  [self.webView loadRequest:request];
  [self hideProgressItem];
  [stateMachine release];
}

//
//  Decryption failed. Tell the user and release the state machine.
//

-(void)decryptionStateMachineDidFail:(DecryptionStateMachine *)stateMachine {
  _GTMDevLog(@"%s", __PRETTY_FUNCTION__);
  [self.errorHandler displayMessage:kDVErrorDecrypt forError:nil];
  [self hideProgressItem];
  [stateMachine release];
}

//
//  Either perform the action right away or queue it for later, depending
//  on the value of |self.synchronousDecryption|.
//

- (void)decryptionStateMachine:(DecryptionStateMachine *)stateMachine
               willQueueAction:(SEL)action {
  if (self.synchronousDecryption) {
    [stateMachine performSelector:action];
  } else {
    [stateMachine performSelector:action withObject:nil afterDelay:0];
  }
}


#pragma mark -
#pragma mark DropBox

- (DBSession *)dbSession {
  if (dbSession_ == nil) {
    dbSession_ = [[DBSession sharedSession] retain];
  }
  return dbSession_;
}

- (void)setDbSession:(DBSession *)dbSession {
  [dbSession_ autorelease];
  dbSession_ = [dbSession retain];
}

- (DVCacheManager *)cacheManager {
  
  if (cacheManager_ == nil) {
    cacheManager_ = [[DVCacheManager alloc] init];
    cacheManager_.delegate = self;
  }
  return cacheManager_;
}

//
//  We successfully loaded ciphertext. Initiate decryption.
//

- (void)cacheManager:(DVCacheManager *)cacheManager didCacheCopyOfFile:(NSString *)destPath {
  
  if (![cacheDataPath_ isEqualToString:destPath]) {
    return;
  }
  _GTMDevLog(@"%s -- successfully loaded %@", __PRETTY_FUNCTION__, destPath);
  NSData *key = [self.detailItem valueForKey:kDVKey];
  NSData *iv  = [self.detailItem valueForKey:kDVIV];
  _GTMDevLog(@"%s -- decrypting with key %@ and iv %@", __PRETTY_FUNCTION__, 
             [key hexString], 
             [iv hexString]);
  NSString *fileName = [[self.detailItem valueForKey:kDVFileName] asPathInTemporaryFolder];
  self.progressLabel.text = kDVStringDecrypting;
  self.progressView.progress = 0.0;
  
  //
  //  Create the decryption state machine and decrypt.
  //  Note the object is released by the delegate.
  //
  
  DecryptionStateMachine *stateMachine = [[DecryptionStateMachine alloc] init];
  stateMachine.delegate = self;
  [stateMachine decryptFile:destPath toPath:fileName withKey:key andIV:iv];
}

//
//  Show progress for downloading the file from DropBox.
//

- (void)cacheManager:(DVCacheManager *)cacheManager loadProgress:(CGFloat)progress forFile:(NSString *)destPath {

  if ([cacheDataPath_ isEqualToString:destPath]) {
    self.progressView.progress = progress;
  }
}

//
//  There was an error getting the file from DropBox. Tell the user.
//

- (void) cacheManager:(DVCacheManager *)cacheManager didFailCacheOfFile:(NSString *)path {

  if ([self.cacheDataPath isEqualToString:path]) {
    [self.errorHandler displayMessage:kDVErrorDownload forError:nil];
  }
}

#pragma mark -
#pragma mark Login interactions

//
//  Log out from the DropBox account.
//

- (void)unlinkFromDropBox {
  [self.dbSession unlink];
  linkOrUnlinkButton_.title = kDVStringLogin;
  self.detailItem = nil;
  self.password = nil;
  [self.rootViewController forgetAllDropBoxFiles];
}    

//
//  Toggles the login state... if you're currently logged in, this will log
//  you out. Otherwise, it will show the DropBox login controller.
//

- (IBAction)loginToDropBox {
  _GTMDevLog(@"%s", __PRETTY_FUNCTION__);
  if ([self.dbSession isLinked]) {
    [self unlinkFromDropBox];
  } else {
    DBLoginController *loginController = [[DBLoginController new] autorelease];
    loginController.delegate = self;
    [loginController presentFromController:self];
  }
}

//
//  The user successfully logged in to DropBox.
//

- (void)loginControllerDidLogin:(DBLoginController*)controller {
  linkOrUnlinkButton_.title = kDVStringLogout;
  [self.rootViewController lookForNewDropBoxFiles];
  [self showFishbowlPage];
  //[self performSelector:@selector(presentPasswordController) withObject:nil afterDelay:0.0];
}

//
//  The user cancelled his login.
//

- (void)loginControllerDidCancel:(DBLoginController*)controller {
  _GTMDevLog(@"%s -- login cancelled", __PRETTY_FUNCTION__);
}

//
//  The login controller went away. If the user is logged in, we now need
//  to prompt for a separate DropVault password.
//

- (void)loginControllerDidDisappear {
  if ([self.dbSession isLinked]) {
    [self presentPasswordController];
  }
}

#pragma mark -
#pragma mark PasswordControllerDelegate

-(UIViewController *)passwordController {
  PasswordController *pw = [[[PasswordController alloc] init] autorelease];
  pw.delegate = self;
  UINavigationController *nav = [[[UINavigationController alloc] initWithRootViewController:pw] autorelease];
  nav.modalTransitionStyle = UIModalTransitionStyleCoverVertical;
  nav.modalPresentationStyle = UIModalPresentationFormSheet;
  nav.navigationBar.barStyle = UIBarStyleBlackOpaque;
  return nav;
}

-(void)setPassword:(NSString *)pw {
  [password_ autorelease];
  password_ = [pw copy];
  self.rootViewController.password = password_;
}

//
//  Shows the controller for getting the user's password.
//

- (IBAction)presentPasswordController {
  if (password_ == nil && [self.dbSession isLinked] && !isShowingPasswordController_) {
    [self.rootViewController presentModalViewController:[self passwordController] animated:YES];
    isShowingPasswordController_ = YES;
  }
}

-(void)passwordController:(PasswordController *)passwordController didEnterPassword:(NSString *)newPassword {
  [self.rootViewController dismissModalViewControllerAnimated:YES];
  isShowingPasswordController_ = NO;
  self.password = newPassword;
}

-(void)passwordControllerDidCancel:(PasswordController *)passwordController {
  [self.rootViewController dismissModalViewControllerAnimated:YES];
  isShowingPasswordController_ = NO;
  [self unlinkFromDropBox];
}

#pragma mark -
#pragma mark Document options

-(IBAction)presentDocumentOptions {
  NSString *fileName = [self.detailItem valueForKey:kDVFileName];
  if (fileName != nil) {
    NSURL *url = [NSURL fileURLWithPath:[fileName asPathInTemporaryFolder]];
    self.docIC = [UIDocumentInteractionController interactionControllerWithURL:url];
    [self.docIC presentOptionsMenuFromBarButtonItem:self.actionItem animated:YES];
  }
}

#pragma mark -
#pragma mark Split view support

- (void)splitViewController: (UISplitViewController*)svc willHideViewController:(UIViewController *)aViewController withBarButtonItem:(UIBarButtonItem*)barButtonItem forPopoverController: (UIPopoverController*)pc {
  
  barButtonItem.title = kDVStringProductName;
  NSMutableArray *items = [[toolbar_ items] mutableCopy];
  [items insertObject:barButtonItem atIndex:0];
  [toolbar_ setItems:items animated:YES];
  [items release];
  self.popoverController = pc;
}


// Called when the view is shown again in the split view, invalidating the button and popover controller.
- (void)splitViewController: (UISplitViewController*)svc willShowViewController:(UIViewController *)aViewController invalidatingBarButtonItem:(UIBarButtonItem *)barButtonItem {
  
  NSMutableArray *items = [[toolbar_ items] mutableCopy];
  [items removeObjectAtIndex:0];
  [toolbar_ setItems:items animated:YES];
  [items release];
  self.popoverController = nil;
}


#pragma mark -
#pragma mark Rotation support

// Ensure that the view controller supports rotation and that the split view can therefore show in both portrait and landscape.
- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
  return YES;
}


- (void)willAnimateRotationToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation duration:(NSTimeInterval)duration {
}


#pragma mark -
#pragma mark View lifecycle

// Implement viewDidLoad to do additional setup after loading the view, typically from a nib.
- (void)viewDidLoad {
  [super viewDidLoad];
  if ([self.dbSession isLinked]) {
    linkOrUnlinkButton_.title = kDVStringLogout;
  } else {
    linkOrUnlinkButton_.title = kDVStringLogin;
  }
  NSMutableArray *toolbarItems = [NSMutableArray arrayWithArray:toolbar_.items];
  [toolbarItems removeObject:self.progressBarButtonItem];
  [toolbar_ setItems:toolbarItems animated:NO];
  [self showFishbowlPage];
  isShowingPasswordController_ = NO;
}

/*
 - (void)viewWillAppear:(BOOL)animated {
 [super viewWillAppear:animated];
 }
 */

- (void)viewDidAppear:(BOOL)animated {
  [super viewDidAppear:animated];
  _GTMDevLog(@"%s", __PRETTY_FUNCTION__);
  // [self performSelector:@selector(presentPasswordController) withObject:nil afterDelay:0.0];
}

/*
 - (void)viewWillDisappear:(BOOL)animated {
 [super viewWillDisappear:animated];
 }
 */
/*
 - (void)viewDidDisappear:(BOOL)animated {
 [super viewDidDisappear:animated];
 }
 */

- (void)viewDidUnload {
  self.toolbar = nil;
  self.linkOrUnlinkButton = nil;
  self.webView = nil;
  self.activityIndicator = nil;
  self.progressBarButtonItem = nil;
  self.progressLabel = nil;
  self.progressView = nil;
  self.actionItem = nil;
  self.detailDescriptionBarButtonItem = nil;
  self.detailDescriptionLabel = nil;
  self.popoverController = nil;
  self.notesButton = nil;
}


#pragma mark -
#pragma mark Memory management

- (void)didReceiveMemoryWarning {
  // Releases the view if it doesn't have a superview.
  [super didReceiveMemoryWarning];
  
  // Release any cached data, images, etc that aren't in use.
}

- (void)dealloc {
  
  //
  //  N.B. |rootViewController_| is set by "assign", so do not
  //  release it here.
  //
  
  [detailItem_ release];
  [dbSession_ release];
  [cacheManager_ release];
  [cacheDataPath_ release];
  [password_ release];
  [docIC_ release];
  [errorHandler_ release];
  [toolbar_ release];
  [linkOrUnlinkButton_ release];
  [webView_ release];
  [activityIndicator_ release];
  [progressBarButtonItem_ release];
  [progressLabel_ release];
  [progressView_ release];
  [detailDescriptionBarButtonItem_ release];
  [detailDescriptionLabel_ release];
  [actionItem_ release];
  [popoverController_ release];
  [notesButton_ release];
  
  [super dealloc];
}	

@end
