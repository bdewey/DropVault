//
//  DecryptionStateMachine.m
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

#import "DecryptionStateMachine.h"
#import "NSData+EncryptionHelpers.h"

@implementation DecryptionStateMachine

@synthesize delegate = delegate_, outputFilePath = outputFilePath_;
@synthesize inputHandle = inputHandle_, outputHandle = outputHandle_;
@synthesize fileLength = fileLength_, outputBuffer = outputBuffer_;

- (void)dealloc {
  [outputFilePath_ release];
  [inputHandle_ release];
  [outputHandle_ release];
  [fileLength_ release];
  [outputBuffer_ release];
  [super dealloc];
}

//
//  Decrypts a single |kDecryptionStateMachineBlockSize| byte block of data.
//

- (void)decryptBlock {
  size_t moved, bytesRead;
  
  CCCryptorStatus status;
  NSData *inputData = [inputHandle_ readDataOfLength:kDecryptionStateMachineBlockSize];
  bytesRead = [inputData length];
  if (bytesRead > 0) {
    [outputBuffer_ setLength:kDecryptionStateMachineBlockSize];
    status = CCCryptorUpdate(cryptor_, 
                             [inputData bytes], 
                             [inputData length], 
                             [outputBuffer_ mutableBytes], 
                             [outputBuffer_ length], 
                             &moved);
    if (status) {
      _GTMDevLog(@"%s -- encryption error %d", 
                 __PRETTY_FUNCTION__, 
                 status);
      abort();
    }
    if (moved != [outputBuffer_ length]) {
      [outputBuffer_ setLength:moved];
    }
    [outputHandle_ writeData:outputBuffer_];
    totalDecrypted_ += bytesRead;
    [delegate_ decryptionStateMachine:self 
                      didDecryptBytes:totalDecrypted_ 
                           outOfBytes:[fileLength_ unsignedLongLongValue]];
    if ([delegate_ respondsToSelector:@selector(decryptionStateMachine:willQueueAction:)]) {
      [delegate_ decryptionStateMachine:self 
                        willQueueAction:@selector(decryptBlock)];
    } else {
      [self performSelector:@selector(decryptBlock) 
                 withObject:nil 
                 afterDelay:0.0];
    }
  } else {
    [outputBuffer_ setLength:kDecryptionStateMachineBlockSize];
    status = CCCryptorFinal(cryptor_, 
                            [outputBuffer_ mutableBytes], 
                            [outputBuffer_ length], 
                            &moved);
    _GTMDevLog(@"%s -- CCCryptorFinal status %d", 
               __PRETTY_FUNCTION__, 
               status);
    if (moved) {
      [outputBuffer_ setLength:moved];
      [outputHandle_ writeData:outputBuffer_];
    }
    
    CCCryptorRelease(cryptor_);
    [outputBuffer_ release];
    [inputHandle_ closeFile];
    [outputHandle_ closeFile];
    [delegate_ decryptionStateMachineDidFinish:self];
  }
}

//
//  Decrypts the file at |inputFilePath| and puts the cleartext at |outputFilePath|
//  using |key| and |iv|. The only decryption algorithm is AES128.
//
//  This routine does the initial setup, and then calls |decryptBlock| to 
//  decrypt each block of data. The delegate gets notified each time |decryptBlock|
//  gets invoked.
//

- (void)decryptFile:(NSString *)inputFilePath 
             toPath:(NSString *)outputFilePath 
            withKey:(NSData *)key
              andIV:(NSData *)iv {
  
  _GTMDevLog(@"%s -- decrypting with key %@ and iv %@", 
             __PRETTY_FUNCTION__, 
             [key hexString], 
             [iv hexString]);
  self.outputFilePath = outputFilePath;
  
  self.inputHandle = [NSFileHandle fileHandleForReadingAtPath:inputFilePath];
  if (inputHandle_ == nil) {
    _GTMDevLog(@"%s -- could not open %@", 
               __PRETTY_FUNCTION__, 
               inputFilePath);
    [delegate_ decryptionStateMachineDidFail:self];
    return;
  } else {
    _GTMDevLog(@"%s -- succesfully opened %@", 
               __PRETTY_FUNCTION__, 
               inputFilePath);
  }
  
  [[NSFileManager defaultManager] createFileAtPath:outputFilePath 
                                          contents:nil 
                                        attributes:nil];
  self.outputHandle = [NSFileHandle fileHandleForWritingAtPath:outputFilePath];
  _GTMDevLog(@"%s -- file name %@, file URL %@, length %d", 
             __PRETTY_FUNCTION__,
             outputFilePath,
             [NSURL fileURLWithPath:outputFilePath],
             [outputFilePath length]);
  if (outputHandle_ == nil) {
    [inputHandle_ closeFile];
    [delegate_ decryptionStateMachineDidFail:self];
    return;
  }
  _GTMDevLog(@"%s -- writing to %@", __PRETTY_FUNCTION__, outputFilePath);
  
  NSDictionary *fileAttributes = [[NSFileManager defaultManager] attributesOfItemAtPath:inputFilePath error:NULL];
  self.fileLength = [fileAttributes valueForKey:@"NSFileSize"];
  totalDecrypted_ = 0;
  
  self.outputBuffer = [[NSMutableData alloc] initWithLength:kDecryptionStateMachineBlockSize];
  CCCryptorCreate(kCCDecrypt, 
                  kCCAlgorithmAES128, 
                  kCCOptionPKCS7Padding, 
                  [key bytes], 
                  [key length], 
                  [iv bytes], 
                  &cryptor_);
  
  if ([delegate_ respondsToSelector:@selector(decryptionStateMachine:willQueueAction:)]) {
    [delegate_ decryptionStateMachine:self willQueueAction:@selector(decryptBlock)];
  } else {
    [self performSelector:@selector(decryptBlock) withObject:nil afterDelay:0.0];
  }
}


@end
