//
//  DetailViewController.h
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

#import <UIKit/UIKit.h>
#import <CoreData/CoreData.h>
#import "DropboxSDK.h"
#import "PasswordController.h"
#import "DecryptionStateMachine.h"
#import "DVErrorHandler.h"
#import "DVTextEditController.h"
#import "DVCacheManager.h"

@class RootViewController;

@interface DetailViewController : UIViewController <UIPopoverControllerDelegate, 
UISplitViewControllerDelegate, 
UIWebViewDelegate,
DBLoginControllerDelegate, 
PasswordControllerDelegate,
UIDocumentInteractionControllerDelegate,
DecryptionStateMachineDelegate,
DVTextEditDelegate,
DVCacheManagerDelegate> {
  
@private
  BOOL isShowingPasswordController_;
  RootViewController *rootViewController_;
  NSManagedObject *detailItem_;
  DBSession *dbSession_;
  DVCacheManager *cacheManager_;
  NSString *cacheDataPath_;
  NSString *password_;
  UIDocumentInteractionController *docIC_;
  DVErrorHandler *errorHandler_;
  BOOL synchronousDecryption_;
  
  UIToolbar *toolbar_;
  UIBarButtonItem *linkOrUnlinkButton_;
  UIWebView *webView_;
  UIActivityIndicatorView *activityIndicator_;
  UIBarButtonItem *progressBarButtonItem_;
  UILabel *progressLabel_;
  UIProgressView *progressView_;
  UIBarButtonItem *detailDescriptionBarButtonItem_;
  UILabel *detailDescriptionLabel_;
  UIBarButtonItem *actionItem_;
  
  UIPopoverController *popoverController_;
  UIBarButtonItem *notesButton_;
}

//
//  This is a pointer back to the root view controller that is driving
//  this detail view controller.
//

@property (nonatomic, assign) IBOutlet RootViewController *rootViewController;

//
//  This is the file that we are supposed to display.
//

@property (nonatomic, retain) NSManagedObject *detailItem;

//
//  This is the |DBSession| we use when working with DropBox. If you do
//  not set it, it defaults to [DBSession sharedSession], which is the correct
//  thing to do most times. You can override it for unit testing.
//

@property (nonatomic, retain) DBSession *dbSession;

//
//  Our cache manager for interacting with DropBox.
//

@property (nonatomic, retain) DVCacheManager *cacheManager;

//
//  This is the cache data file we expect to interact with. Normally you
//  should not set this from the outside.
//

@property (nonatomic, copy) NSString *cacheDataPath;

//
//  The DropVault password, used to decrypt keys.
//

@property (nonatomic, copy) NSString *password;

//
//  The Document Interaction Controller used to send DropVault files to 
//  other applications.
//

@property (nonatomic, retain) UIDocumentInteractionController *docIC;

//
//  Handles display of errors to the user.
//

@property (nonatomic, retain) DVErrorHandler *errorHandler;

//
//  If YES, then decryption is performed synchronously on the thread
//  that handles restClient:loadedFile:. If NO, then messages to the
//  |DecryptionStateMachine| are queued for later delivery.
//
//  Defaults to NO.
//

@property (nonatomic, assign) BOOL synchronousDecryption;

//
//  Interface Builder outlets.
//

@property (nonatomic, retain) IBOutlet UIToolbar *toolbar;
@property (nonatomic, retain) IBOutlet UIBarButtonItem *linkOrUnlinkButton;
@property (nonatomic, retain) IBOutlet UIWebView *webView;
@property (nonatomic, retain) IBOutlet UIActivityIndicatorView *activityIndicator;
@property (nonatomic, retain) IBOutlet UIBarButtonItem *progressBarButtonItem;
@property (nonatomic, retain) IBOutlet UILabel *progressLabel;
@property (nonatomic, retain) IBOutlet UIProgressView *progressView;
@property (nonatomic, retain) IBOutlet UIBarButtonItem *actionItem;
@property (nonatomic, retain) IBOutlet UIBarButtonItem *detailDescriptionBarButtonItem;
@property (nonatomic, retain) IBOutlet UILabel *detailDescriptionLabel;
@property (nonatomic, retain) IBOutlet UIBarButtonItem *notesButton;


//
//  Initiates login to DropBox.
//

- (IBAction)loginToDropBox;

//
//  Presents the menu of options for opening the document in another program.
//

- (IBAction)presentDocumentOptions;

//
//  Prompts the user for his password.
//

- (IBAction)presentPasswordController;

//
//  Updates the toolbar to show a progress bar with a label. When the progress
//  bar is shown on the toolbar, you can update it by manipulating |progressView|.
//

- (void)showProgressItem:(NSString *)label;

//
//  Hides the progress bar.
//

- (void)hideProgressItem;

//
//  Show the Notes UI.
//

- (IBAction)presentNotes:(id)sender;

@end
