//
//  RootViewController.h
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
#import "DVErrorHandler.h"
#import "DVCacheManager.h"


@class DetailViewController;

//
//  Lists all files in the DropVault directory. The user can select a file,
//  which will cause the |detailViewController| to display the resulting
//  decrypted file.
//

@interface RootViewController : UITableViewController 
<NSFetchedResultsControllerDelegate,
DVCacheManagerDelegate> {
  
@private
  DetailViewController *detailViewController_;
  NSFetchedResultsController *fetchedResultsController_;
  NSManagedObjectContext *managedObjectContext_;
  DBSession *dbSession_;
  NSString *password_;
  DVErrorHandler *errorHandler_;
  DVCacheManager *cacheManager_;
}

#pragma mark -
#pragma mark Properties

//
//  This object receives notifications when the user selects new files to
//  view.
//

@property (nonatomic, retain) IBOutlet DetailViewController *detailViewController;

//
//  The |NSFetchedResultsController| that controls the list of files to show
//  to the user.
//

@property (nonatomic, retain) NSFetchedResultsController *fetchedResultsController;

//
//  The connection to Core Data.
//

@property (nonatomic, retain) NSManagedObjectContext *managedObjectContext;

//
//  This is the DBSession used for interacting with DropBox. If you do not
//  set it, it defaults to [DBSession sharedSession], which is normally the right
//  thing. You can override this for unit testing.
//

@property (nonatomic, retain) DBSession *dbSession;

//
//  The password to decrypt key files.
//

@property (nonatomic, copy) NSString *password;

//
//  The error handler for this object. If you don't set it, one will be created.
//  This is probably what you want; setting it is primarily useful for 
//  testing.
//

@property (nonatomic, retain) DVErrorHandler *errorHandler;

//
//  The cache manager. This is responsible for all interactions with DropBox.
//

@property (nonatomic, retain) DVCacheManager *cacheManager;

#pragma mark -
#pragma mark Methods

//
//  Looks for new key files in DropBox.
//

-(IBAction)lookForNewDropBoxFiles;

//
//  Forgets all files currently in DropBox.
//

-(IBAction)forgetAllDropBoxFiles;

//
//  Get all of the |kDVKeyEntity| objects that match an predicate.
//  If there is an error, returns |nil| and sets |error|.
//
//  You can pass in |nil| for |predicate| to get all objects.
//

- (NSArray *)fetchObjectsForPredicate:(NSPredicate *)predicate 
                                error:(NSError **)error;

@end
