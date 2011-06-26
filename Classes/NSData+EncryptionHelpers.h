//
//  NSData+EncryptionHelpers.h
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


@interface NSData (EncryptionHelpers)

//
//  Converts an NSData to a hex string representation. Each byte is represented
//  as a string from 00 to FF.
//

- (NSString *)hexString;

//
//  Converts a hex string to an NSData object.
//

+ (NSData *)dataWithHexString:(NSString *)hexString;

//
//  Creates an NSData with random bytes. Returns |nil| if there's an error
//  getting the random bytes.
//

+ (NSData *)dataWithRandomBytes:(NSUInteger)count;

//
//  Decrypts the buffer using a specific |key| and |iv| (initialization vector).
//  Returns the decrypted buffer.
//

- (NSData *)aesDecryptWithKey:(NSData *)key andIV:(NSData *)iv;

//
//  Encrypts the buffer using a specific |key| and |iv| (initialization vector).
//  Returns the encrypted buffer.
//

- (NSData *)aesEncryptWithKey:(NSData *)key andIV:(NSData *)iv;

@end

@interface NSMutableData (EncryptionHelpers)

//
//  Decrypts a buffer in place using a specific |key| and |iv|.
//

- (void)aesDecryptInPlaceWithKey:(NSData *)key andIV:(NSData *)iv;

//
//  Encrypts a buffer in place using a specific |key| and |iv|.
//

- (void)aesEncryptInPlaceWithKey:(NSData *)key andIV:(NSData *)iv;
@end
