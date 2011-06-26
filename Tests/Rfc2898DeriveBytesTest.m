//
//  Rfc2898DeriveBytesTest.m
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

//  See Also: http://developer.apple.com/iphone/library/documentation/Xcode/Conceptual/iphone_development/135-Unit_Testing_Applications/unit_testing_applications.html

#import "GTMSenTestCase.h"
#import <UIKit/UIKit.h>
#import "NSData+EncryptionHelpers.h"
#import "Rfc2898DeriveBytes.h"


@interface Rfc2898DeriveBytesTest : GTMTestCase {
    
}

@end



@implementation Rfc2898DeriveBytesTest

//
//  Tests some of the common success paths for deriving bytes.
//

- (void)testDeriveBytes {
    NSMutableData *derivedBytes = [[NSMutableData alloc] initWithLength:20];
    char saltBytes[8] = { 1, 1, 2, 3, 5, 8, 13, 21 };
    NSData *salt = [[[NSData alloc] initWithBytes:saltBytes length:8] autorelease];
    [Rfc2898DeriveBytes deriveBytes:derivedBytes fromPassword:@"Orwell." andSalt:salt];
    STAssertEqualStrings([derivedBytes hexString],
                         @"BE74CA67FF18FC2E2BDAD643D2101F83AF507944",
                         @"Bytes were not properly derived");
}

- (void)testDeriveBytesInvalidParameters {
    STAssertThrows([Rfc2898DeriveBytes deriveBytes:nil fromPassword:nil andSalt:nil], @"invalid parameters accepted");
}

@end
