//
//  DecryptionStateMachine.h
//  DropboxPrototype
//
//  Created by Brian Dewey on 1/19/11.
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
#import <CommonCrypto/CommonCryptor.h>

//
//  The chunk size for decryption.
//

#define kDecryptionStateMachineBlockSize    (2048)

//
//  |DecryptionStateMachine| decrypts a file in chunks to make it easier to show 
//  progress.
//

@protocol DecryptionStateMachineDelegate;
@interface DecryptionStateMachine : NSObject {
@private
  id<DecryptionStateMachineDelegate> delegate_;
  NSString *outputFilePath_;
  NSFileHandle *inputHandle_;
  NSFileHandle *outputHandle_;
  NSNumber *fileLength_;
  NSMutableData *outputBuffer_;
  
  unsigned long long totalDecrypted_;
  CCCryptorRef cryptor_;
}

@property (nonatomic, assign) id<DecryptionStateMachineDelegate> delegate;
@property (nonatomic, retain) NSString *outputFilePath;
@property (nonatomic, retain) NSFileHandle *inputHandle;
@property (nonatomic, retain) NSFileHandle *outputHandle;
@property (nonatomic, retain) NSNumber *fileLength;
@property (nonatomic, retain) NSMutableData *outputBuffer;

//
//  Decrypts the file at |inputFilePath| and puts the cleartext at |outputFilePath|
//  using |key| and |iv|. The only decryption algorithm is AES128.
//

- (void)decryptFile:(NSString *)inputFilePath 
             toPath:(NSString *)outputFilePath
            withKey:(NSData *)key
              andIV:(NSData *)iv;

@end

//
//  |DecryptionStateMachineDelegate| defines the messages that are sent
//  to track the progress, and eventual resolution, of decrypting a file.
//

@protocol DecryptionStateMachineDelegate <NSObject>

//
//  This message is sent every kDecryptionStateMachineBlockSize bytes 
//

- (void)decryptionStateMachine:(DecryptionStateMachine *)stateMachine
               didDecryptBytes:(unsigned long long)bytesDecrypted
                    outOfBytes:(unsigned long long)totalBytes;

//
//  This message is sent when the entire file is decrypted.
//

- (void)decryptionStateMachineDidFinish:(DecryptionStateMachine *)stateMachine;

//
//  This message is sent if the file could not be decrypted.
//

- (void)decryptionStateMachineDidFail:(DecryptionStateMachine *)stateMachine;

@optional

//
//  The delegate can optionally control how to queue state machine
//  actions. If the delegate does not respond to this message, then 
//  the DecryptionStateMachine will use performSelector:withObject:afterDelay:
//  to perform the action after a zero delay. If the delegate responds
//  to this message, it MUST ensure that the action gets performed.
//

- (void)decryptionStateMachine:(DecryptionStateMachine *)stateMachine
               willQueueAction:(SEL)action;

@end

