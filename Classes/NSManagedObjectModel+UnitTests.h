//
//  NSManagedObjectModel+UnitTests.h
//  DropVault
//
//  Created by Brian Dewey on 1/27/11.
//  Code comes from http://www.litp.org/blog/?p=62.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

@interface NSManagedObjectModel (UnitTests)

//
//  Creates an in-memory managed object context from the models compiled
//  into an |NSBundle|.
//

+ (NSManagedObjectContext *) inMemoryMOCFromBundle:(NSBundle *)appBundle;

@end
