//
//  Rfc2898DeriveBytes.m
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

#import "Rfc2898DeriveBytes.h"
#import "NSData+EncryptionHelpers.h"
#import <CommonCrypto/CommonCryptor.h>
#import <CommonCrypto/CommonHMAC.h>

@implementation Rfc2898DeriveBytes

+(void)deriveBytes:(NSMutableData *)deriveBytes
      fromPassword:(NSString *)password 
           andSalt:(NSData *)salt {
  
  _GTMDevAssert(password != nil, @"password must not be nil");
  _GTMDevAssert(salt != nil, @"salt must not be nil");
  _GTMDevAssert(deriveBytes != nil, @"deriveBytes must not be nil");
  
  //
  //  We work with the password as a UTF8 encoded byte stream.
  //
  
  const char *passPhraseBytes = [password UTF8String];
  int passPhraseLength = strlen(passPhraseBytes);
  
  //
  //  Copy the salt into a mutable buffer. We need to append 4 bytes
  //  onto the end that we change through each iteration of the algorithm.
  //
  
  NSMutableData *mSalt = [[[NSMutableData alloc] initWithData:salt] autorelease];
  [mSalt increaseLengthBy:4];
  
  //
  //  Other buffers & counters used for executing RFC2898.
  //
  
  unsigned char mac[CC_SHA1_DIGEST_LENGTH];
  unsigned char outputBytes[CC_SHA1_DIGEST_LENGTH];
  unsigned char U[CC_SHA1_DIGEST_LENGTH];
  const int iterations = 1000;
  int i;
  int generatedBytes = 0;
  unsigned char blockCount = 0;
  
  while (generatedBytes < [deriveBytes length]) {
    bzero(mac, CC_SHA1_DIGEST_LENGTH);
    bzero(outputBytes, CC_SHA1_DIGEST_LENGTH);
    bzero(U, CC_SHA1_DIGEST_LENGTH);
    
    //
    //  Each time through this loop, I need to update the very last byte
    //  of the salt buffer. (If I implemented the full RFC2898 algorithm,
    //  then I'd be ready to twiddle the last 4 bytes. I don't.)
    //
    
    blockCount++;
    unsigned char *mSaltBytes = (unsigned char *)[mSalt mutableBytes];
    mSaltBytes[[mSalt length]-1] = blockCount;
    _GTMDevLog(@"%s -- salt is %@", __PRETTY_FUNCTION__, [mSalt hexString]);
    
    memcpy(U, [mSalt bytes], [mSalt length]);
    
    //
    //  First iteration. I have to split these apart because the data length
    //  is different between the first iteration (12 bytes) and each subsequent
    //  iteration (20 bytes).
    //
    
    CCHmac(kCCHmacAlgSHA1, passPhraseBytes, passPhraseLength, [mSalt bytes], [mSalt length], mac);
    for (i = 0; i < CC_SHA1_DIGEST_LENGTH; i++) {
      outputBytes[i] ^= mac[i];
      U[i] = mac[i];
    }
    
    //
    //  All subsequent iterations.
    //
    
    for (int iteration = 1; iteration < iterations; iteration++) {
      CCHmac(kCCHmacAlgSHA1, passPhraseBytes, passPhraseLength, U, CC_SHA1_DIGEST_LENGTH, mac);
      for (i = 0; i < CC_SHA1_DIGEST_LENGTH; i++) {
        outputBytes[i] ^= mac[i];
        U[i] = mac[i];
      }
    }
    
    int bytesNeeded = [deriveBytes length] - generatedBytes;
    int bytesToCopy = MIN(bytesNeeded, CC_SHA1_DIGEST_LENGTH);
    [deriveBytes replaceBytesInRange:NSMakeRange(generatedBytes, bytesToCopy) withBytes:outputBytes];
    generatedBytes += bytesToCopy;
  }
}

+(void)deriveKey:(NSMutableData *)key andIV:(NSMutableData *)iv
    fromPassword:(NSString *)password andSalt:(NSData *)salt {
  
  NSMutableData *buffer = [[[NSMutableData alloc] initWithLength:(kCCKeySizeAES128+kCCBlockSizeAES128)] autorelease];
  [Rfc2898DeriveBytes deriveBytes:buffer fromPassword:password andSalt:salt];
  
  //
  //  Copy the bytes for the key
  //
  
  [key setLength:kCCKeySizeAES128];
  [iv setLength:kCCBlockSizeAES128];
  [buffer getBytes:[key mutableBytes] range:NSMakeRange(0, kCCKeySizeAES128)];
  [buffer getBytes:[iv mutableBytes] range:NSMakeRange(kCCKeySizeAES128, kCCBlockSizeAES128)];
}


@end
