//
//  KeyFileDecryptor.m
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

#import "KeyFileDecryptor.h"
#import "Rfc2898DeriveBytes.h"
#import "NSData+EncryptionHelpers.h"
#include <CommonCrypto/CommonCryptor.h>

//
//  How many bytes of salt we use when encrypting / decrypting the key 
//  files.
// 

#define kSaltBytes          8

@implementation KeyFileDecryptor

@synthesize key = key_, iv = iv_, fileName = fileName_, password = password_;

- (void)dealloc {
  [key_ release];
  [iv_ release];
  [fileName_ release];
  [password_ release];
  [super dealloc];
}

//
//  Decrypts key file data with a password and creates a new KeyFileDescriptor
//  object with the decrypted key, initialization vector, and clear file name.
//

+ (KeyFileDecryptor *)decryptorWithData:(NSData *)keyData
                            andPassword:(NSString *)password {
  
  KeyFileDecryptor *decryptor = [[[KeyFileDecryptor alloc] init] autorelease];
  decryptor.password = password;
  
  //
  //  The |salt| is the first 8 bytes of |keyData|.
  //
  
  NSMutableData *salt = [[[NSMutableData alloc] initWithLength:kSaltBytes] autorelease];
  [keyData getBytes:[salt mutableBytes] range:NSMakeRange(0, kSaltBytes)];
  
  //
  //  Create a buffer for the key & iv used for decrypting the rest of 
  //  |keyData|.
  //
  
  NSMutableData *key  = [[[NSMutableData alloc] init] autorelease];
  NSMutableData *iv   = [[[NSMutableData alloc] init] autorelease];
  
  //
  //  Get the key & iv for |keyData| from the password & |salt| (which we read
  //  from the beginning of the file, as you recall)
  //
  
  [Rfc2898DeriveBytes deriveKey:key andIV:iv fromPassword:password andSalt:salt];
  
  //
  //  Create a buffer with cipherText. Note we have to remove the 8 bytes at
  //  the front that contain |salt|.
  //
  
  NSMutableData *cipherText = [NSMutableData dataWithData:keyData];
  [cipherText replaceBytesInRange:NSMakeRange(0, kSaltBytes) withBytes:NULL length:0];
  
  //
  //  Decrypt |cipherText| using the |key| and |iv| derived from 
  //  |password| and |salt| (read from the beginning of the data).
  //
  
  NSData *clearText = [cipherText aesDecryptWithKey:key andIV:iv];
  if (!clearText) {
    //
    //  Unable to decrypt key.
    //
    
    return nil;
  }
  
  
  //
  //  Extract the key (first kCCKeySizeAES128 bytes of cleartext)
  //
  
  NSMutableData *fileKey = [NSMutableData dataWithLength:kCCKeySizeAES128];
  [clearText getBytes:[fileKey mutableBytes] 
                range:NSMakeRange(0, kCCKeySizeAES128)];
  decryptor.key = fileKey;
  
  //
  //  Extract the IV (next kCCBlockSizeAES128 bytes of cleartext)
  //
  
  NSMutableData *fileIv  = [NSMutableData dataWithLength:kCCBlockSizeAES128];
  [clearText getBytes:[fileIv mutableBytes] 
                range:NSMakeRange(kCCKeySizeAES128, kCCBlockSizeAES128)];
  decryptor.iv = fileIv;
  
  //
  //  Extract the file name
  //
  
  int fileNameOffset = kCCKeySizeAES128+kCCBlockSizeAES128;
  NSMutableData *fileNameBytes = [NSMutableData dataWithLength:[clearText length]-fileNameOffset];
  [fileNameBytes increaseLengthBy:1];  // add room for the null byte
  [clearText getBytes:[fileNameBytes mutableBytes] 
                range:NSMakeRange(fileNameOffset, [clearText length]-fileNameOffset)];
  NSString *fileName = [NSString stringWithUTF8String:[fileNameBytes mutableBytes]];
  decryptor.fileName = fileName;
  
  return decryptor;
}

//
//  Return the current |KeyFileDecryptor| as an encrypted blob.
//

- (NSData *)encryptedBlob {
  NSUInteger targetCapacity = [self.fileName length] + kCCKeySizeAES128 + kCCBlockSizeAES128 + kSaltBytes;
  NSMutableData *blob = [NSMutableData dataWithCapacity:targetCapacity];
  
  //
  //  Start by creating a random salt. Put it at the start of the blob, and 
  //  then generate the encryption key & iv.
  //
  
  NSData *salt = [NSData dataWithRandomBytes:kSaltBytes];
  _GTMDevAssert([blob length] == 0, @"Blob should start empty");
  [blob appendData:salt];
  NSMutableData *blobKey = [NSMutableData dataWithCapacity:kCCKeySizeAES128];
  NSMutableData *blobIV  = [NSMutableData dataWithCapacity:kCCBlockSizeAES128];
  [Rfc2898DeriveBytes deriveKey:blobKey 
                          andIV:blobIV 
                   fromPassword:self.password 
                        andSalt:salt];
  
  //
  //  Next, build a payload buffer and encrypt it.
  //
  
  NSMutableData *payload = [NSMutableData dataWithCapacity:targetCapacity-kSaltBytes];
  [payload appendData:self.key];
  [payload appendData:self.iv];
  const char *fileNameString = [self.fileName UTF8String];
  [payload appendBytes:fileNameString length:strlen(fileNameString)];
  [payload aesEncryptInPlaceWithKey:blobKey andIV:blobIV];
  
  //
  //  Append the payload to the blob.
  //
  
  [blob appendData:payload];
  return blob;
}

@end
