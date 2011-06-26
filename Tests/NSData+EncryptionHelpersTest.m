//
//  NSData+EncryptionHelpersTest.m
//  DropboxPrototype
//
//  Created by Brian Dewey on 1/20/11.
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
#import "NSData+EncryptionHelpers.h"
#import <CommonCrypto/CommonCryptor.h>


@interface NSData_EncryptionHelpersTest : GTMTestCase {
    
}

@end


@implementation NSData_EncryptionHelpersTest

//
//  Tests simple success cases of translating a data region to a hex string.
//

- (void)testHexStringSuccess {
    NSDictionary *successCases = [NSDictionary dictionaryWithObjectsAndKeys:@"48656C6C6F", @"Hello",
                                  @"61", @"a",
                                  @"", @"",
                                  nil];
    for (NSString *str in successCases.allKeys) {
        NSString *expectedResult = [successCases valueForKey:str];
        NSString *actualResult = [[str dataUsingEncoding:NSUTF8StringEncoding] hexString];
        STAssertEqualStrings(expectedResult, actualResult, @"String did not decode correctly");
    }
}

//
//  Tests the simple success case of converting a hex string to an NSData.
//

- (void)testNSDataFromHexStringSuccess {
    char bytes [] = { 0xBD, 0x00, 0xAA, 0xDD, 0xFF, 0x01, 0x7F };
    
    NSData *expectedData = [NSData dataWithBytes:bytes length:sizeof(bytes)];
    NSData *convertedData = [NSData dataWithHexString:@"BD00AADDFF017F"];
    STAssertEqualObjects(expectedData, convertedData,
                         @"Should properly convert a hex string to NSData");
}

//
//  Makes sure we can get some random bytes.
//

- (void)testGetRandomBytes {
  
  NSData *rnd1 = [NSData dataWithRandomBytes:16];
  STAssertEquals((NSUInteger)16, [rnd1 length], 
                 @"Should have the expected number of bytes");
  
  //
  //  How else should I test that the bytes are truly random?
  //
  
}

//
//  Test encryption.
//

- (void)testAesEncrypt {
  
  NSData *key = [NSData dataWithRandomBytes:kCCKeySizeAES128];
  NSData *iv  = [NSData dataWithRandomBytes:kCCBlockSizeAES128];
  NSString *plaintext = @"This is the plaintext that I need to encrypt.";
  const char *plainutf = [plaintext UTF8String];
  NSData *plainbytes = [NSData dataWithBytes:plainutf 
                                      length:strlen(plainutf) + 1];
  
  //
  //  Encrypt.
  //
  
  NSData *cipherBytes = [plainbytes aesEncryptWithKey:key andIV:iv];
  STAssertNotNil(cipherBytes, @"Should get cipher bytes");
  STAssertGreaterThanOrEqual([cipherBytes length], 
                             [plainbytes length], 
                             @"should have enough bytes");
  _GTMDevLog(@"%s -- cipher text is %@", 
             __PRETTY_FUNCTION__, 
             [cipherBytes hexString]);
  
  //
  //  Decrypt.
  //
  
  NSData *decrypted = [cipherBytes aesDecryptWithKey:key andIV:iv];
  STAssertNotNil(decrypted, @"Should get decrypted bytes");
  STAssertEquals([plainbytes length], [decrypted length], 
                 @"should have same byte count");
  NSString *decryptedText = [NSString stringWithUTF8String:[decrypted bytes]];
  _GTMDevLog(@"%s -- decrypted text is %@", 
             __PRETTY_FUNCTION__, 
             [plainbytes hexString]);
  STAssertEqualStrings(plaintext, decryptedText, @"Should round trip");
}

//
//  Test in-place encryption and decryption.
//

- (void)testAesEncryptInPlace {
  
  NSData *key = [NSData dataWithRandomBytes:kCCKeySizeAES128];
  NSData *iv  = [NSData dataWithRandomBytes:kCCBlockSizeAES128];
  NSString *plaintext = @"This is the plaintext that I need to encrypt and decrypt in place.";
  const char *plainutf = [plaintext UTF8String];
  NSMutableData *plainbytes = [NSMutableData dataWithBytes:plainutf 
                                                    length:strlen(plainutf) + 1];
  NSString *plainHexString = [plainbytes hexString];
  
  //
  //  Encrypt.
  //
  
  [plainbytes aesEncryptInPlaceWithKey:key andIV:iv];
  _GTMDevLog(@"%s -- cipher text is %@", 
             __PRETTY_FUNCTION__, 
             [plainbytes hexString]);
  STAssertNotEqualStrings(plainHexString, 
                          [plainbytes hexString], 
                          @"Bytes should be encrypted");
  
  //
  //  Decrypt.
  //
  
  [plainbytes aesDecryptInPlaceWithKey:key andIV:iv];
  NSString *decryptedText = [NSString stringWithUTF8String:[plainbytes bytes]];
  STAssertEqualStrings(plaintext, decryptedText, @"Should round trip");
}

@end
