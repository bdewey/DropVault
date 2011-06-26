//
//  DecryptionStateMachineTest.m
//  DropboxPrototype
//
//  Created by Brian Dewey on 1/23/11.
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
#import "NSString+FileSystemHelper.h"
#import "NSData+EncryptionHelpers.h"
#import "DecryptionStateMachine.h"
#import <CommonCrypto/CommonDigest.h>
#import "KeyFileDecryptor.h"

#define kPassword               @"Orwell."

//
//  The SHA-1 hash of the cleartext of DecryptionStateMachineTest.dat
//

#define kCleartextHash @"C0EA1C21637F34C238D6462569474524F5C393D1"

//
//  This is the AES128 key used to decrypt DecryptionStateMachineTest.dat
//

unsigned char keyBytes[] = {
    0x87, 0x5C, 0x72, 0xDD, 0x1B, 0x50, 0x01, 0xAB, 0xFB, 0xEF,
    0x4B, 0x7A, 0xEB, 0x30, 0x77, 0x2E
};

//
//  This is the initialization vector to decrypt DecryptionStateMachineTest.dat
//

unsigned char ivBytes[] = {
    0x16, 0xDA, 0x47, 0x1D, 0xBC, 0xF3, 0x5D, 0x75, 0xAC, 0x2F,
    0xDC, 0x1C, 0xD3, 0xC0, 0x12, 0xE2
};

//
//  This tests DecryptionStateMachine
//

@interface DecryptionStateMachineTest : GTMTestCase <DecryptionStateMachineDelegate> {
    @private
    BOOL didReceiveProgress_;
    unsigned int progressNotifications_;
    BOOL didComplete_;
    BOOL didSucceed_;
}

- (void)resetStateMachineFlags;

@end


@implementation DecryptionStateMachineTest

#pragma mark -
#pragma mark Tests 

//
//  Computes the SHA-1 hash for a file. Returns it as a |hexString|.
//

- (NSString *)hashForFile:(NSString *)outputFileName {
    NSData *clearData = [NSData dataWithContentsOfFile:outputFileName];
    NSMutableData *clearDigest = [NSMutableData dataWithLength:CC_SHA1_DIGEST_LENGTH];
    CC_SHA1([clearData bytes], [clearData length], [clearDigest mutableBytes]);
    return [clearDigest hexString];
}

//
//  Tests the success case
//

- (void)testStateMachine {
    DecryptionStateMachine *stateMachine = [[[DecryptionStateMachine alloc] init] autorelease];
    stateMachine.delegate = self;
    int keysTested = 0;
    NSString *bundlePath = [[NSBundle mainBundle] bundlePath];
    for (NSString *bundleFileName in [[NSFileManager defaultManager] contentsOfDirectoryAtPath:bundlePath error:nil]) {
        NSString *fileName = [bundlePath stringByAppendingPathComponent:bundleFileName];
        if (![[fileName pathExtension] isEqual:@"key"]) {
            continue;
        }
        [self resetStateMachineFlags];
        keysTested++;

        NSData *keyData = [NSData dataWithContentsOfFile:fileName];
        KeyFileDecryptor *decryptor = [KeyFileDecryptor decryptorWithData:keyData andPassword:kPassword];
        STAssertNotNil(decryptor, @"Should be able to read key data");

        NSString *outputFileName = [decryptor.fileName asPathInDocumentsFolder];
        _GTMDevLog(@"%s -- writing to %@", __PRETTY_FUNCTION__, outputFileName);
        NSString *dataFileName = [[fileName stringByDeletingPathExtension] stringByAppendingPathExtension:@"dat"];
        [stateMachine decryptFile:dataFileName
                           toPath:outputFileName
                          withKey:decryptor.key
                            andIV:decryptor.iv];
        STAssertTrue(didComplete_, @"DecryptionStateMachine should complete");
        STAssertTrue(didSucceed_, @"DecryptionStateMachine should succeed");
        STAssertTrue(didReceiveProgress_, 
                     @"DecryptionStateMachine should report progress");
        
        //
        //  Verify that we received the correct number of progress notifications.
        //
        
        NSDictionary *attributes = [[NSFileManager defaultManager] attributesOfItemAtPath:dataFileName error:nil];
        NSNumber *fileSize = [attributes objectForKey:NSFileSize];
        unsigned int expectedNotifications = ceil([fileSize doubleValue] / (double)kDecryptionStateMachineBlockSize);
        _GTMDevLog(@"%s -- processed file of size %@", __PRETTY_FUNCTION__, fileSize);
        STAssertEquals(expectedNotifications,
                       progressNotifications_,
                       @"DecryptionStateMachine should generate the correct number of notifications. Expected %d, saw %d, file size %@",
                       expectedNotifications,
                       progressNotifications_,
                       fileSize);
        
        //
        //  Verify the hash.
        //
        
        STAssertEqualStrings([[decryptor.fileName lastPathComponent] stringByDeletingPathExtension],
                             [self hashForFile:outputFileName],
                             @"DecryptionStateMachine should properly decrypt");
    }
    STAssertEquals(16, keysTested, @"Should test 16 keys, but tested %d", keysTested);
}

#pragma mark -
#pragma mark DecryptionStateMachineDelegate

//
//  Resets all of the internal flags that the test uses to verify that the
//  proper messages were sent by the state machine.
//

- (void)resetStateMachineFlags {
    didReceiveProgress_ = NO;
    didComplete_ = NO;
    didSucceed_ = NO;
    progressNotifications_ = 0;
}

//
//  Progress indicator... notes how many bytes have been decrypted.
//

-(void)decryptionStateMachine:(DecryptionStateMachine *)stateMachine
              didDecryptBytes:(unsigned long long)bytesDecrypted
                   outOfBytes:(unsigned long long)totalBytes {
    didReceiveProgress_ = YES;
    progressNotifications_++;
}

//
//  Sent when decryption successfully completes.
//

-(void)decryptionStateMachineDidFinish:(DecryptionStateMachine *)stateMachine {
    didComplete_ = YES;
    didSucceed_ = YES;
}


//
//  Sent when decrytpion fails.
//

-(void)decryptionStateMachineDidFail:(DecryptionStateMachine *)stateMachine {
    didComplete_ = YES;
    didSucceed_ = NO;
}

//
//  Perform actions NOW, on this thread.
//

- (void)decryptionStateMachine:(DecryptionStateMachine *)stateMachine
               willQueueAction:(SEL)action {
    [stateMachine performSelector:action];
}


@end
