//
//  DropboxPrototypeAppDelegate.m
//
//  This is the main application delegate for DropVault. Its primary job
//  is to initialize the Core Data stack and handle application events, such
//  as entering/leaving the background.
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
#import "DropboxPrototypeAppDelegate.h"


#import "RootViewController.h"
#import "DetailViewController.h"

#include "DropVaultKeys.h"


@implementation DropboxPrototypeAppDelegate

@synthesize window = window_;
@synthesize splitViewController = splitViewController_;
@synthesize rootViewController = rootViewController_;
@synthesize detailViewController = detailViewController_;


#pragma mark -
#pragma mark Application lifecycle


- (void)awakeFromNib {
  // Pass the managed object context to the root view controller.
  self.rootViewController.managedObjectContext = self.managedObjectContext; 
}


- (BOOL)application:(UIApplication *)application 
didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {    
  
  // Override point for customization after app launch.
  
  DBSession *session = [[[DBSession alloc] initWithConsumerKey:DROPVAULT_CONSUMER_KEY
                                                consumerSecret:DROPVAULT_API_SECRET] autorelease];
  [DBSession setSharedSession:session];
  
  // Add the split view controller's view to the window and display.
  [self.window addSubview:self.splitViewController.view];
  [self.window makeKeyAndVisible];
  
  return YES;
}

//
//  When we leave the active state, throw away all decrypted information.
//

- (void)applicationDidEnterBackground:(UIApplication *)application {
  self.rootViewController.password = nil;
  self.detailViewController.password = nil;
  self.detailViewController.detailItem = nil;
}

//
//  When we become foreground, we've forgotten our password. Prompt.
//

- (void)applicationDidBecomeActive:(UIApplication *)application {
  [self.rootViewController performSelector:@selector(lookForNewDropBoxFiles) 
                                withObject:nil 
                                afterDelay:0];
  [self.detailViewController performSelector:@selector(presentPasswordController) 
                                  withObject:nil
                                  afterDelay:0];
}


/**
 applicationWillTerminate: saves changes in the application's managed object context before the application terminates.
 */
- (void)applicationWillTerminate:(UIApplication *)application {
  
  NSError *error = nil;
  NSManagedObjectContext *managedObjectContext = self.managedObjectContext;
  if (managedObjectContext != nil) {
    if ([managedObjectContext hasChanges] && ![managedObjectContext save:&error]) {
      /*
       Replace this implementation with code to handle the error appropriately.
       
       abort() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development. If it is not possible to recover from the error, display an alert panel that instructs the user to quit the application by pressing the Home button.
       */
      NSLog(@"Unresolved error %@, %@", error, [error userInfo]);
      abort();
    } 
  }
}


#pragma mark -
#pragma mark Core Data stack

/**
 Returns the managed object context for the application.
 If the context doesn't already exist, it is created and bound to the persistent store coordinator for the application.
 */
- (NSManagedObjectContext *)managedObjectContext {
  
  if (managedObjectContext_ != nil) {
    return managedObjectContext_;
  }
  
  NSPersistentStoreCoordinator *coordinator = [self persistentStoreCoordinator];
  if (coordinator != nil) {
    managedObjectContext_ = [[NSManagedObjectContext alloc] init];
    [managedObjectContext_ setPersistentStoreCoordinator:coordinator];
  }
  return managedObjectContext_;
}


/**
 Returns the managed object model for the application.
 If the model doesn't already exist, it is created from the application's model.
 */
- (NSManagedObjectModel *)managedObjectModel {
  
  if (managedObjectModel_ != nil) {
    return managedObjectModel_;
  }
  NSURL *modelURL = [[NSBundle mainBundle] URLForResource:@"DropboxPrototype" withExtension:@"momd"];
  managedObjectModel_ = [[NSManagedObjectModel alloc] initWithContentsOfURL:modelURL];    
  return managedObjectModel_;
}


/**
 Returns the persistent store coordinator for the application.
 If the coordinator doesn't already exist, it is created and the application's store added to it.
 */
- (NSPersistentStoreCoordinator *)persistentStoreCoordinator {
  
  BOOL didRetry = NO;
  if (persistentStoreCoordinator_ != nil) {
    return persistentStoreCoordinator_;
  }
  
  NSURL *storeURL = [[self applicationDocumentsDirectory] URLByAppendingPathComponent:@"DropboxPrototype.sqlite"];
  
  NSError *error = nil;
  persistentStoreCoordinator_ = [[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel:[self managedObjectModel]];
retry:
  if (![persistentStoreCoordinator_ addPersistentStoreWithType:NSSQLiteStoreType configuration:nil URL:storeURL options:nil error:&error]) {
    /*
     Replace this implementation with code to handle the error appropriately.
     
     abort() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development. If it is not possible to recover from the error, display an alert panel that instructs the user to quit the application by pressing the Home button.
     
     Typical reasons for an error here include:
     * The persistent store is not accessible;
     * The schema for the persistent store is incompatible with current managed object model.
     Check the error message to determine what the actual problem was.
     
     
     If the persistent store is not accessible, there is typically something wrong with the file path. Often, a file URL is pointing into the application's resources directory instead of a writeable directory.
     
     If you encounter schema incompatibility errors during development, you can reduce their frequency by:
     * Simply deleting the existing store:
     [[NSFileManager defaultManager] removeItemAtURL:storeURL error:nil]
     
     * Performing automatic lightweight migration by passing the following dictionary as the options parameter: 
     [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithBool:YES],NSMigratePersistentStoresAutomaticallyOption, [NSNumber numberWithBool:YES], NSInferMappingModelAutomaticallyOption, nil];
     
     Lightweight migration will only work for a limited set of schema changes; consult "Core Data Model Versioning and Data Migration Programming Guide" for details.
     
     */
    NSLog(@"Unresolved error %@, %@", error, [error userInfo]);
    
    //
    //  Development code only.
    //
    
    if (!didRetry) {
      [[NSFileManager defaultManager] removeItemAtURL:storeURL error:nil];
      didRetry = YES;
      goto retry;
    }
    abort();
  }    
  
  return persistentStoreCoordinator_;
}


#pragma mark -
#pragma mark Application's Documents directory

/**
 Returns the URL to the application's Documents directory.
 */
- (NSURL *)applicationDocumentsDirectory {
  return [[[NSFileManager defaultManager] URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask] lastObject];
}


#pragma mark -
#pragma mark Memory management

- (void)applicationDidReceiveMemoryWarning:(UIApplication *)application {
  /*
   Free up as much memory as possible by purging cached data objects that can be recreated (or reloaded from disk) later.
   */
}


- (void)dealloc {
  
  [window_ release];
  [splitViewController_ release];
  [rootViewController_ release];
  [detailViewController_ release];
  [managedObjectContext_ release];
  [managedObjectModel_ release];
  [persistentStoreCoordinator_ release];
  
  
  [super dealloc];
}


@end

