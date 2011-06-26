//
//  NSString+FileSystemHelper.h
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

#import <Foundation/Foundation.h>


@interface NSString(FileSystemHelper)

//
//  Returns a new string made by appending the last path component of the 
//  receiver to the user's Documents folder.
//

-(NSString *)asPathInDocumentsFolder;

//
//  Returns a new string made by appending the last path component of the 
//  receiver to the user's temporary folder.
//

-(NSString *)asPathInTemporaryFolder;

//
//  Returns the "sidecar" version of a filename. This is a path that has
//  "-sidecar" appended to the last path component, before the extension.
//  E.g., "/StrongBox/foo.key" becomes "/StrongBox/foo-sidecar.key".
//

- (NSString *)stringAsSidecarPath;

@end
