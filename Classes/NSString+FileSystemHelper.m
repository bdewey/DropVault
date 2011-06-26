//
//  NSString+FileSystemHelper.m
//  DropboxPrototype
//
//  Created by Brian Dewey on 1/14/11.
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

#import "NSString+FileSystemHelper.h"

#define kSidecarIdentifier        @"-sidecar"


@implementation NSString(FileSystemHelper)

-(NSString *)asPathInDocumentsFolder {
  NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
  NSString *homeDir = [paths objectAtIndex:0];
  return [homeDir stringByAppendingPathComponent:[self lastPathComponent]];
}

-(NSString *)asPathInTemporaryFolder {
  NSString *temp = NSTemporaryDirectory();
  return [temp stringByAppendingPathComponent:[self lastPathComponent]];
}

- (NSString *)stringAsSidecarPath {
  
  NSMutableArray *components = [NSMutableArray arrayWithArray:[self pathComponents]];
  NSString *lastComponent = [components lastObject];
  NSString *extension = [lastComponent pathExtension];
  lastComponent = [lastComponent stringByDeletingPathExtension];
  if ([lastComponent length] >= [kSidecarIdentifier length]) {
    NSUInteger index = [lastComponent length] - [kSidecarIdentifier length];
    NSString *suffix = [lastComponent substringFromIndex:index];
    if ([suffix isEqualToString:kSidecarIdentifier]) {
      
      //
      //  OK, this is a path that already matches the sidecar pattern.
      //  Just return the path. For safety, though, return a new copy of the
      //  path.
      //
      
      return [[self copy] autorelease];
    }
  }
  lastComponent = [lastComponent stringByAppendingString:kSidecarIdentifier];
  if ([extension length] > 0) {
    lastComponent = [lastComponent stringByAppendingPathExtension:extension];
  }
  [components replaceObjectAtIndex:([components count] - 1) withObject:lastComponent];
  return [NSString pathWithComponents:components];
}

@end
