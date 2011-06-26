//
//  KeyFileDecryptor.h
//  DropboxPrototype
//
//  Created by Brian Dewey on 1/24/11.
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

//
//  Given a password, this class can decrypt a DropVault key file and get
//  the AES encryption key, IV, and filename associated with a DropVault data
//  file.
//

@interface KeyFileDecryptor : NSObject {
  
@private
  NSData *key_;
  NSData *iv_;
  NSString *fileName_;
  NSString *password_;
}

@property (nonatomic, retain) NSData *key;
@property (nonatomic, retain) NSData *iv;
@property (nonatomic, copy) NSString *fileName;
@property (nonatomic, copy) NSString *password;

//
//  Decrypts key file data with a password and creates a new KeyFileDescriptor
//  object with the decrypted key, initialization vector, and clear file name.
//

+ (KeyFileDecryptor *)decryptorWithData:(NSData *)keyFileData
                            andPassword:(NSString *)password;

//
//  Generates the encrypted blob format of the key data.
//

- (NSData *)encryptedBlob;

@end
