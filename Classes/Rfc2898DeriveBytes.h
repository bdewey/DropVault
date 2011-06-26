//
//  Rfc2898DeriveBytes.h
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


@interface Rfc2898DeriveBytes : NSObject {

}

//
//  Uses RFC2898 to derive bytes from a password and random salt. 
//  Make sure that the length of deriveBytes is set prior to sending
//  this message, as that determines how many bytes to derive from the
//  password and the salt.
//

+(void)deriveBytes:(NSMutableData *)deriveBytes
      fromPassword:(NSString *)password andSalt:(NSData *)salt;

//
//  Derives a key an initialization vector suitable for AES128 encryption
//  from a password and random salt.
//


+(void)deriveKey:(NSMutableData *)key andIV:(NSMutableData *)iv
    fromPassword:(NSString *)password andSalt:(NSData *)salt;

@end
