//
//  NSManagedObjectModel+UnitTests.m
//  DropVault
//
//  Created by Brian Dewey on 1/27/11.
//  Code comes from http://www.litp.org/blog/?p=62.
//

#import "NSManagedObjectModel+UnitTests.h"


@implementation NSManagedObjectModel (UnitTests)

+ (NSManagedObjectContext *)inMemoryMOCFromBundle:(NSBundle *)appBundle {
  // get model from app bundle passed into method
  NSArray *bundleArray = [NSArray arrayWithObject:appBundle];
  NSAssert([bundleArray count] == (unsigned)1, @"1 object in bundle array");
  NSManagedObjectModel *model = [NSManagedObjectModel mergedModelFromBundles:bundleArray];
  
  NSPersistentStoreCoordinator *coordinator = [[[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel:model] autorelease];
  if (coordinator == nil) {
    NSLog(@"Can't get instance of NSPersistentStoreCoordinator");
    return nil;
  }
  
  // Add an in-memory persistent store to the coordinator.
  NSDictionary *options = [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithBool:YES], NSMigratePersistentStoresAutomaticallyOption, [NSNumber numberWithBool:YES], NSInferMappingModelAutomaticallyOption, nil];	
  
  NSError *addStoreError = nil;
  if (![coordinator addPersistentStoreWithType:NSInMemoryStoreType configuration:nil URL:nil options:options error:&addStoreError]) {
    NSLog(@"Error setting up in-memory store unit test: %@", addStoreError);
    return nil;
  }
  
  // Now we can set up the managed object context and assign it to persistent store coordinator.
  NSManagedObjectContext *context = [[NSManagedObjectContext alloc] init];
  [context setPersistentStoreCoordinator: coordinator];
  NSAssert( context != nil, @"Can't set up managed object context for unit test.");
  
  return context;
}

@end
