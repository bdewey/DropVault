//
//  RootViewController.m
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

#import "RootViewController.h"
#import "DetailViewController.h"
#import "NSData+EncryptionHelpers.h"
#import "Rfc2898DeriveBytes.h"
#import "NSString+FileSystemHelper.h"
#import "KeyFileDecryptor.h"

/*
 This template does not ensure user interface consistency during editing 
 operations in the table view. You must implement appropriate methods to provide 
 the user experience you require.
 */

//
//  Private mapping of file extensions to icon names.
//

#define kWordIcon     @"word48.gif"
#define kPowerpointIcon @"powerpoint48.gif"
#define kExcelIcon    @"excel48.gif"
#define kPdfIcon      @"page_white_acrobat48.gif"
static NSDictionary *extensionToIcon_;

//
//  Private category on NSString for testing if a path is a key file.
//

@interface NSString (RootViewController)
- (BOOL)isKeyFile;
@end

@implementation NSString (RootViewController)

//
//  Determines if a path is a key file. Key files end in |.key|, but NOT
//  |-sidecar.key|. In the latter case, it's a key file for a sidecar -- this
//  will be an encrypted text file that's *about* something else.
//

- (BOOL)isKeyFile {

  NSPredicate *matcher = [NSPredicate predicateWithFormat:@"(SELF like '*.key') AND NOT (SELF like '*-sidecar.key')"];
  return [matcher evaluateWithObject:self];
}

@end

//
//  Private methods. Method comments below.
//

@interface RootViewController ()
- (void)configureCell:(UITableViewCell *)cell 
          atIndexPath:(NSIndexPath *)indexPath;
- (void)decryptKeyData:(NSData *)keyData 
        selectedObject:(NSManagedObject *)selectedObject;
@end



@implementation RootViewController

@synthesize detailViewController = detailViewController_;
@synthesize fetchedResultsController = fetchedResultsController_;
@synthesize managedObjectContext = managedObjectContext_;
@synthesize password = password_;
@synthesize errorHandler = errorHandler_;
@synthesize cacheManager = cacheManager_;


#pragma mark -
#pragma mark View lifecycle

- (void)viewDidLoad {
  
  [super viewDidLoad];
  self.clearsSelectionOnViewWillAppear = NO;
  self.contentSizeForViewInPopover = CGSizeMake(320.0, 600.0);
  self.tableView.rowHeight = 55;
  
  NSError *error = nil;
  if (![self.fetchedResultsController performFetch:&error]) {
    
    [self.errorHandler displayMessage:kDVErrorCoreDataUnexpected forError:error];
  }
  if ([self.dbSession isLinked]) {
    
    [self lookForNewDropBoxFiles];
  }
}


- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
  return YES;
}

//
//  PRIVATE: Get the file extension to icon mapping.
//

- (NSDictionary *)extensionToIcon {
  
  if (extensionToIcon_ == nil) {
    
    extensionToIcon_ = [[NSDictionary dictionaryWithObjectsAndKeys:kWordIcon, @"docx", 
                         kWordIcon, @"docm",
                         kWordIcon, @"doc",
                         kPowerpointIcon, @"pptx",
                         kPowerpointIcon, @"ppt",
                         kExcelIcon, @"xlsx",
                         kExcelIcon, @"xls",
                         kPdfIcon, @"pdf",
                         nil] retain];
  }
  return extensionToIcon_;
}

//
//  PRIVATE: Get an icon file name based upon a file.
//

- (NSString *)iconNameForFileName:(NSString *)fileName {
  
  NSString *iconName = [[self extensionToIcon] objectForKey:[fileName pathExtension]];
  if (iconName != nil) {
    return iconName;
  }
  return @"page_white48.gif";
}

//
//  Configures the table cell for an individual DropBox file.
//

- (void)configureCell:(UITableViewCell *)cell atIndexPath:(NSIndexPath *)indexPath {
  
  NSManagedObject *managedObject = [self.fetchedResultsController objectAtIndexPath:indexPath];
  NSString *fileName = [managedObject valueForKey:kDVFileName];
  if ([fileName length] == 0 && [self.password length] > 0) {
    
    //
    //  We don't have the filename yet, but we do have the password. Decrypt and
    //  try again.
    //
    
    NSString *keyName = [DVCacheManager cachePathForDropBoxPath:[managedObject valueForKey:kDVKeyName]];
    _GTMDevLog(@"%s -- looking for key data in %@", __PRETTY_FUNCTION__, keyName);
    NSData *keyData = [[[NSData alloc] initWithContentsOfFile:keyName] autorelease];
    if (keyData && [keyData length] > 0) {
      [self decryptKeyData:keyData selectedObject:managedObject];
    }
    fileName = [managedObject valueForKey:kDVFileName];
  }
  
  if ([fileName length] > 0) {
    
    cell.textLabel.text = fileName;
    NSString *detail = [NSString stringWithFormat:@"%@ %@",
                        [NSDateFormatter localizedStringFromDate:[managedObject valueForKey:kDVLastModifiedDate] 
                                                       dateStyle:NSDateFormatterShortStyle 
                                                       timeStyle:NSDateFormatterNoStyle],
                        [managedObject valueForKey:kDVHumanReadableSize]
                        ];
    cell.detailTextLabel.text = detail;
    NSString *iconName = [self iconNameForFileName:fileName];
    cell.imageView.image = [UIImage imageNamed:iconName];
    
  } else {
    
    cell.textLabel.text = @"Loading...";
    cell.detailTextLabel.text = @"";
    cell.imageView.image = [UIImage imageNamed:@"54-lock.png"];
  }
}

#pragma mark Error Handler

- (DVErrorHandler *)errorHandler {
  if (!errorHandler_) {
    errorHandler_ = [[DVErrorHandler alloc] init];
  }
  return errorHandler_;
}

#pragma mark DropBox

//
//  Gets the DBSession object that we are supposed to use for interacting with
//  DropBox. If it is not set, uses [DBSession sharedSession] to get a
//  |DBSession| object.
//

- (DBSession *)dbSession {
  if (dbSession_) {
    return dbSession_;
  }
  return [DBSession sharedSession];
}

//
//  Sets the DBSession object for interacting with DropBox.
//

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

-(IBAction)lookForNewDropBoxFiles {
  [self.cacheManager loadMetadata];
}

//
//  Removes a single DropBox file.
//

- (IBAction)removeDropBoxObject:(NSManagedObject *)object 
                    fromContext:(NSManagedObjectContext *) context {
  
  NSString *fileName = [DVCacheManager cachePathForDropBoxPath:[object valueForKey:kDVKeyName]];
  [[NSFileManager defaultManager] removeItemAtPath:fileName error:nil];
  [[NSFileManager defaultManager] removeItemAtPath:[[fileName stringByDeletingPathExtension] stringByAppendingPathExtension:@"dat"]
                                             error:nil];
  [context deleteObject:object];
}

//
//  Erases all strongbox file entries. Useful when unlinking
//  from a DropBox account.
//

-(IBAction)forgetAllDropBoxFiles {
  NSManagedObjectContext *context = [self.fetchedResultsController managedObjectContext];
  for (NSManagedObject *object in [self.fetchedResultsController fetchedObjects]) {
    [self removeDropBoxObject:object fromContext:context];
  }
  NSError *error = nil;
  if (![context save:&error]) {
    
    [self.errorHandler displayMessage:kDVErrorCoreDataUnexpected forError:error];
  }
}

//
//  Gets all |kDVKeyEntity| objects that match a predicate. If you pass in |nil|
//  for |predicate|, then it will return all objects. Returns |nil| on error and
//  sets |error|.
//

- (NSArray *)fetchObjectsForPredicate:(NSPredicate *)predicate 
                                error:(NSError **)error {
  
  // Create a new instance of the entity managed by the fetched results controller.
  NSManagedObjectContext *context = [self.fetchedResultsController managedObjectContext];
  NSEntityDescription *entity = [[self.fetchedResultsController fetchRequest] entity];
  
  //
  //  See if there is already an object with this KeyName property.
  //
  
  NSFetchRequest *fetchRequest = [[[NSFetchRequest alloc] init] autorelease];
  [fetchRequest setEntity:entity];
  [fetchRequest setPredicate:predicate];
  NSArray *objects = [context executeFetchRequest:fetchRequest error:error];
  return objects;
}

//
//  Create a new |kDVKeyEntity| object.
//

- (NSManagedObject *)createNewKeyObject {
  NSManagedObjectContext *context = [self.fetchedResultsController managedObjectContext];
  NSEntityDescription *entity = [[self.fetchedResultsController fetchRequest] entity];
  NSManagedObject *newManagedObject = [NSEntityDescription insertNewObjectForEntityForName:[entity name] 
                                                                    inManagedObjectContext:context];
  return newManagedObject;
}

//
//  Create a |kDVKeyEntity| object for the corresponding DropBox metadata.
//

- (void)createEntryForStrongBoxKey:(DBMetadata *)keyMetadata {
  
  NSError *error;
  NSPredicate *predicate = [NSPredicate predicateWithFormat:@"(KeyName = %@)", keyMetadata.path];
  NSArray *objects = [self fetchObjectsForPredicate:predicate error:&error];
  if (objects == nil) {
    
    [self.errorHandler displayMessage:kDVErrorCoreDataUnexpected forError:error];
    return;
  }
  if ([objects count] > 0) {
    return;
  }
  NSManagedObject *newManagedObject = [self createNewKeyObject];
  
  // If appropriate, configure the new managed object.
  [newManagedObject setValue:keyMetadata.path forKey:kDVKeyName];
  NSString *dataPath = [[keyMetadata.path stringByDeletingPathExtension] 
                        stringByAppendingPathExtension:@"dat"];
  DBMetadata *dataMetadata = [self.cacheManager metadataForPath:[DVCacheManager cachePathForDropBoxPath:dataPath]];
  if (dataMetadata != nil) {
    [newManagedObject setValue:dataMetadata.humanReadableSize forKey:kDVHumanReadableSize];
    [newManagedObject setValue:dataMetadata.lastModifiedDate forKey:kDVLastModifiedDate];
  }
  
  // Save the context.
  if (![self.fetchedResultsController.managedObjectContext save:&error]) {
    /*
     Replace this implementation with code to handle the error appropriately.
     
     abort() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development. If it is not possible to recover from the error, display an alert panel that instructs the user to quit the application by pressing the Home button.
     */
    _GTMDevLog(@"Unresolved error %@, %@", error, [error userInfo]);
    abort();
  }
  
  //
  //  And then get the key data.
  //
  
  [self.cacheManager cacheCopyOfDropBoxPath:keyMetadata.path];
}

//
//  We've received metadata from DropBox. We need to bring our internal state 
//  into sync with what's on DropBox. That means adding objects for any new
//  DropBox |.key| files and removing objects for any files that no longer
//  exist on DropBox.
//

- (void)cacheManagerDidLoadMetadata:(DVCacheManager *)cacheManager {
  
  //
  //  This is the add path. we add an object for any |.key| file and remember
  //  all of the names.
  //
  
  NSMutableSet *keyNames = [[[NSMutableSet alloc] init] autorelease];
  for (DBMetadata *child in cacheManager.metadata.contents) {
    if ([child.path isKeyFile]) {
      [self createEntryForStrongBoxKey:child];
      [keyNames addObject:child.path];
    }
  }
  
  //
  //  Now, pass through each object and delete any objects that do not have
  //  matching names in |keyNames|.
  //
  
  NSManagedObjectContext *context = [self.fetchedResultsController managedObjectContext];
  NSArray *objects = [self fetchObjectsForPredicate:nil error:nil];
  for (NSManagedObject *object in objects) {
    NSString *keyName = [object valueForKey:kDVKeyName];
    _GTMDevLog(@"%s -- looking for %@ in %@", __PRETTY_FUNCTION__,
               keyName, keyNames);
    if (![keyNames containsObject:keyName]) {
      [self removeDropBoxObject:object fromContext:context];
    }
  }
  NSError *error;
  [context save:&error];
}

- (void)cacheManagerLoadMetadataFailed:(DVCacheManager *)cacheManager {
  
  //
  //  NOTHING. If we're unable to refresh the list of files, it probably means we're off
  //  the network. Do nothing (other than log).
  //
  
  _GTMDevLog(@"%s -- cacheManagerLoadMetadataFailed:", __PRETTY_FUNCTION__);
}

//
//  We've downloaded a key file from DropBox. Decrypt it and find the matching
//  managed object to store the file decryption key, IV, and file name.
//

- (void)cacheManager:(DVCacheManager *)cacheManager didCacheCopyOfFile:(NSString *)destPath {

  _GTMDevLog(@"%s -- successfully loaded %@", __PRETTY_FUNCTION__, destPath);
  NSData *keyData = [[NSFileManager defaultManager] contentsAtPath:destPath];
  for (NSManagedObject *managedObject in [self fetchObjectsForPredicate:nil error:nil]) {
    NSString *keyName = [managedObject valueForKey:kDVKeyName];
    if ([[[keyName lowercaseString] lastPathComponent] isEqual:[[destPath lowercaseString] lastPathComponent]]) {
      [self decryptKeyData:keyData selectedObject:managedObject];
      [self.fetchedResultsController.managedObjectContext save:nil];
    }
  }
}

- (void)cacheManager:(DVCacheManager *)cacheManager didFailCacheOfFile:(NSString *)path {

  [self.errorHandler displayMessage:kDVErrorLoadMetadataFailed forError:nil];
}


#pragma mark -
#pragma mark Crypto helpers

//
//  Sets the decryption password. Importantly, if we have already loaded |.key|
//  files from DropBox, then we go and decrypt the key information for every
//  key we know about and then refresh our table view.
//

-(void)setPassword:(NSString *)pw {
  [password_ autorelease];
  password_ = [pw copy];
  
  for (NSManagedObject *object in [self fetchObjectsForPredicate:nil error:nil]) {
    if (password_ && [password_ length] > 0) {
      
      //
      //  We were just given a password, so try to decrypt keys.
      //
      
      NSString *keyName = [DVCacheManager cachePathForDropBoxPath:[object valueForKey:kDVKeyName]];
      _GTMDevLog(@"%s -- looking for key data in %@", __PRETTY_FUNCTION__, keyName);
      NSData *keyData = [[[NSData alloc] initWithContentsOfFile:keyName] autorelease];
      if (keyData && [keyData length] > 0) {
        [self decryptKeyData:keyData selectedObject:object];
      }
      
    } else {
      
      //
      //  We just lost our password. Throw away decrypted information.
      //
      
      [object setValue:nil forKey:kDVFileName];
      [object setValue:nil forKey:kDVKey];
      [object setValue:nil forKey:kDVIV];
    }
  }
  [self.tableView reloadData];
}

//
//  Decrypts the ciphertext |keyData| that was in one of the |.key| files stored
//  in DropBox. Stores the decrypted |key|, |iv|, and |fileName| as attributes
//  of |selectedObject| for use later in the application.
//
//  If |password_| is not set prior to receiving this message, then the routine
//  does nothing.
//

- (void)decryptKeyData:(NSData *)keyData selectedObject:(NSManagedObject *)selectedObject  {
  if (!password_) {
    return;
  }
  KeyFileDecryptor *decryptor = [KeyFileDecryptor decryptorWithData:keyData 
                                                        andPassword:password_];
  if (decryptor == nil) {
    return;
  }
  [selectedObject setValue:decryptor.key forKey:@"Key"];
  [selectedObject setValue:decryptor.iv forKey:@"InitializationVector"];
  [selectedObject setValue:decryptor.fileName forKey:kDVFileName];
  
  NSManagedObjectContext *context = [self.fetchedResultsController managedObjectContext];
  NSError *error;
  @try {
    
    if (![context save:&error]) {
      [self.errorHandler displayMessage:kDVErrorCoreDataUnexpected forError:error];
    }
    
  }
  @catch (NSException * e) {
    _GTMDevLog(@"%s -- unexpected exception %@ (%@)", 
               __PRETTY_FUNCTION__, 
               e,
               [[e callStackSymbols] description]);
  }
}

#pragma mark -
#pragma mark Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
  return [[self.fetchedResultsController sections] count];
}


- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
  
  _GTMDevLog(@"%s -- getting number of rows in section %d. Sections = %@",
             __PRETTY_FUNCTION__,
             section,
             [self.fetchedResultsController sections]);
  id <NSFetchedResultsSectionInfo> sectionInfo = [[self.fetchedResultsController sections] objectAtIndex:section];
  return [sectionInfo numberOfObjects];
}


- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
  
  static NSString *CellIdentifier = @"Cell";
  
  UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
  if (cell == nil) {
    cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:CellIdentifier] autorelease];
  }
  
  // Configure the cell.
  [self configureCell:cell atIndexPath:indexPath];
  
  return cell;
}


- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
  
  if (editingStyle == UITableViewCellEditingStyleDelete) {
    
    //
    // Delete the managed object and DropBox files.
    //
    
    NSManagedObject *objectToDelete = [self.fetchedResultsController objectAtIndexPath:indexPath];
    NSString *keyPath = [objectToDelete valueForKey:kDVKeyName];
    NSString *datPath = [[keyPath stringByDeletingPathExtension] stringByAppendingPathExtension:@"dat"];
    [self.cacheManager deleteDropBoxPath:keyPath];
    [self.cacheManager deleteDropBoxPath:datPath];

    if (self.detailViewController.detailItem == objectToDelete) {
      self.detailViewController.detailItem = nil;
    }
    
    NSManagedObjectContext *context = [self.fetchedResultsController managedObjectContext];
    [context deleteObject:objectToDelete];
    
    NSError *error;
    @try {
      
      if (![context save:&error]) {
        [self.errorHandler displayMessage:kDVErrorDelete forError:error];
      }
      
    }
    @catch (NSException * e) {
      [self.errorHandler displayMessage:kDVErrorDelete forError:nil];
    }
  }   
}


- (BOOL)tableView:(UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)indexPath {
  // The table view should not be re-orderable.
  return NO;
}


#pragma mark -
#pragma mark Table view delegate

- (void)tableView:(UITableView *)aTableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
  
  // Set the detail item in the detail view controller.
  NSManagedObject *selectedObject = [self.fetchedResultsController objectAtIndexPath:indexPath];
  NSString *destPath = [[selectedObject valueForKey:kDVKeyName] lastPathComponent];
  _GTMDevLog(@"%s -- looking for %@", __PRETTY_FUNCTION__, destPath);
  NSData *keyData = [[NSFileManager defaultManager] contentsAtPath:destPath];
  if (keyData) {
    
    [self decryptKeyData:keyData selectedObject: selectedObject];
    
  } else {
    
    _GTMDevLog(@"%s -- unable to load data", __PRETTY_FUNCTION__);
  }
  
  self.detailViewController.detailItem = selectedObject;    
}


#pragma mark -
#pragma mark Fetched results controller

- (NSFetchedResultsController *)fetchedResultsController {
  
  if (fetchedResultsController_ != nil) {
    return fetchedResultsController_;
  }
  
  /*
   Set up the fetched results controller.
   */
  // Create the fetch request for the entity.
  NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
  // Edit the entity name as appropriate.
  NSEntityDescription *entity = [NSEntityDescription entityForName:kDVKeyEntity 
                                            inManagedObjectContext:managedObjectContext_];
  [fetchRequest setEntity:entity];
  
  // Set the batch size to a suitable number.
  [fetchRequest setFetchBatchSize:20];
  
  // Edit the sort key as appropriate.
  NSSortDescriptor *sortDescriptor = [[NSSortDescriptor alloc] initWithKey:kDVKeyName 
                                                                 ascending:NO];
  NSArray *sortDescriptors = [[NSArray alloc] initWithObjects:sortDescriptor, nil];
  
  [fetchRequest setSortDescriptors:sortDescriptors];
  
  // Edit the section name key path and cache name if appropriate.
  // nil for section name key path means "no sections".
  NSFetchedResultsController *aFetchedResultsController = [[NSFetchedResultsController alloc] initWithFetchRequest:fetchRequest 
                                                                                              managedObjectContext:managedObjectContext_ 
                                                                                                sectionNameKeyPath:nil 
                                                                                                         cacheName:@"Root"];
  aFetchedResultsController.delegate = self;
  self.fetchedResultsController = aFetchedResultsController;
  
  [aFetchedResultsController release];
  [fetchRequest release];
  [sortDescriptor release];
  [sortDescriptors release];
  
  return fetchedResultsController_;
}    


#pragma mark -
#pragma mark Fetched results controller delegate

- (void)controllerWillChangeContent:(NSFetchedResultsController *)controller {
  [self.tableView beginUpdates];
}


- (void)controller:(NSFetchedResultsController *)controller didChangeSection:(id <NSFetchedResultsSectionInfo>)sectionInfo
           atIndex:(NSUInteger)sectionIndex forChangeType:(NSFetchedResultsChangeType)type {
  
  switch(type) {
    case NSFetchedResultsChangeInsert:
      [self.tableView insertSections:[NSIndexSet indexSetWithIndex:sectionIndex] withRowAnimation:UITableViewRowAnimationFade];
      break;
      
    case NSFetchedResultsChangeDelete:
      [self.tableView deleteSections:[NSIndexSet indexSetWithIndex:sectionIndex] withRowAnimation:UITableViewRowAnimationFade];
      break;
  }
}


- (void)controller:(NSFetchedResultsController *)controller didChangeObject:(id)anObject
       atIndexPath:(NSIndexPath *)indexPath forChangeType:(NSFetchedResultsChangeType)type
      newIndexPath:(NSIndexPath *)newIndexPath {
  
  UITableView *tableView = self.tableView;
  
  switch(type) {
      
    case NSFetchedResultsChangeInsert:
      if (newIndexPath != nil) {
        
        [tableView insertRowsAtIndexPaths:[NSArray arrayWithObject:newIndexPath] withRowAnimation:UITableViewRowAnimationFade];
      }
      break;
      
    case NSFetchedResultsChangeDelete:
      if (indexPath != nil) {

        [tableView deleteRowsAtIndexPaths:[NSArray arrayWithObject:indexPath] withRowAnimation:UITableViewRowAnimationFade];
      }
      break;
      
    case NSFetchedResultsChangeUpdate:
      if (indexPath != nil) {
        
        [self configureCell:[tableView cellForRowAtIndexPath:indexPath] atIndexPath:indexPath];
      }
      break;
      
    case NSFetchedResultsChangeMove:
      if ((indexPath != nil) && (newIndexPath != nil)) {
        
        [tableView deleteRowsAtIndexPaths:[NSArray arrayWithObject:indexPath] withRowAnimation:UITableViewRowAnimationFade];
        [tableView insertRowsAtIndexPaths:[NSArray arrayWithObject:newIndexPath] withRowAnimation:UITableViewRowAnimationFade];
      }
      break;
  }
}


- (void)controllerDidChangeContent:(NSFetchedResultsController *)controller {
  [self.tableView endUpdates];
}


#pragma mark -
#pragma mark Memory management

- (void)didReceiveMemoryWarning {
  // Releases the view if it doesn't have a superview.
  [super didReceiveMemoryWarning];
  
  // Relinquish ownership any cached data, images, etc. that aren't in use.
}


- (void)viewDidUnload {
  // Relinquish ownership of anything that can be recreated in viewDidLoad or on demand.
  // For example: self.myOutlet = nil;
}


- (void)dealloc {
  
  [detailViewController_ release];
  [fetchedResultsController_ release];
  [managedObjectContext_ release];
  [dbSession_ release];
  [password_ release];
  [errorHandler_ release];
  [cacheManager_ release];
  
  [super dealloc];
}

@end
