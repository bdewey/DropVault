//
//  KeyFileDecryptorTest.m
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

#import "GTMSenTestCase.h"
#import <UIKit/UIKit.h>
#import "KeyFileDecryptor.h"
#import "NSData+EncryptionHelpers.h"
#import <CommonCrypto/CommonCryptor.h>

#define kKeyFileDecryptorTestPassword       @"Orwell."

@interface KeyFileDecryptorTest : GTMTestCase {
    
}


@end


@implementation KeyFileDecryptorTest

//
//  Tests the "success path" of key file decryption... a set of key files in
//  the bundle that are expected to succeed, and with file names that all end
//  in .txt
//

- (void)testSuccessPath {
    NSString *bundlePath = [[NSBundle mainBundle] bundlePath];
    NSArray *bundleContents = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:bundlePath 
                                                                                  error:nil];
    for (NSString *fileName in bundleContents) {
        if ([[fileName pathExtension] isEqualToString:@"key"]) {
            _GTMDevLog(@"%s -- loading %@", __PRETTY_FUNCTION__, fileName);
            NSData *keyData = [NSData dataWithContentsOfFile:[bundlePath stringByAppendingPathComponent:fileName]];
            STAssertNotNil(keyData, @"Should be able to load key data");
            KeyFileDecryptor *decryptor = [KeyFileDecryptor decryptorWithData:keyData 
                                                                  andPassword:kKeyFileDecryptorTestPassword];
            STAssertNotNil(decryptor, @"Should be able to decrypt key data");
            _GTMDevLog(@"%s -- cleartext file name is %@", 
                       __PRETTY_FUNCTION__, 
                       decryptor.fileName);
            STAssertEqualStrings(@"txt",
                                 [decryptor.fileName pathExtension],
                                 @"Cleartext extension should be 'txt'");
        }
    }
}

//
//  Test "round trip" of key file decryption. Create a new object,
//  encrypt and decrypt, should have the same payload at the end.
//

- (void)testRoundTrip {
  KeyFileDecryptor *kfd = [[[KeyFileDecryptor alloc] init] autorelease];
  NSString *testFileName = @"test-round-trip.txt";
  kfd.key = [NSData dataWithRandomBytes:kCCKeySizeAES128];
  kfd.iv  = [NSData dataWithRandomBytes:kCCBlockSizeAES128];
  kfd.fileName = testFileName;
  kfd.password = kKeyFileDecryptorTestPassword;
  
  //
  //  Get an encrypted blob.
  //
  
  NSData *blob = [kfd encryptedBlob];
  
  //
  //  Now, see if it decrypts.
  //
  
  KeyFileDecryptor *decrypted = [KeyFileDecryptor decryptorWithData:blob 
                                                        andPassword:kKeyFileDecryptorTestPassword];
  
  STAssertEqualStrings(testFileName, decrypted.fileName, 
                       @"Should decrypt file name");
  STAssertEqualStrings([kfd.key hexString],
                       [decrypted.key hexString],
                       @"Should decrypt key");
  STAssertEqualStrings([kfd.iv hexString],
                       [decrypted.iv hexString],
                       @"Should decrypt IV");
}

@end
