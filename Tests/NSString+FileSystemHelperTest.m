//
//  NSString+FileSystemHelperTest.m
//  DropVault
//
//  Created by Brian Dewey on 1/25/11.
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

//
//  Everything needs a test, I guess...
//

@interface NSString_FileSystemHelperTest : GTMTestCase {
    
}


@end


@implementation NSString_FileSystemHelperTest

//
//  Verifies that a set of test paths are placed in the expected directory
//  after performing the specific |FileSystemHelper| action.
//

- (void)verifyPathsInExpectedDirectory:(NSString *)expectedDirectory 
                           forSelector:(SEL)action {

  NSArray *testStrings = [NSArray arrayWithObjects:@"foo", @"foo.txt",
                            @"hello/there", nil];

    for (NSString *testCase in testStrings) {
        
        NSString *result = [testCase performSelector:action];
        NSRange range = [result rangeOfString:expectedDirectory];
        STAssertNotEquals((NSUInteger)NSNotFound,
                          range.location,
                          @"Expected folder should be found");
        STAssertEquals((NSUInteger)0, 
                       range.location, 
                       @"Expected folder should prefix result");
        //
        //  Note that if |testCase| includes multiple path components,
        //  only the last path component is present on the result.
        //  E.g., if |testCase| is "hello/there", then the result is
        //  "~/there" and not "~/hello/there".
        //
        
        range = [result rangeOfString:[testCase lastPathComponent]];
        STAssertNotEquals((NSUInteger)NSNotFound,
                          range.location,
                          @"Should find original string");
        STAssertEquals([result length],
                       range.location + range.length,
                       @"Test case should be at the end of the result");
    }
}

- (void)testPathInDocumentsFolder {
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, 
                                                         NSUserDomainMask, 
                                                         YES);
    NSString *expectedDirectory = [paths objectAtIndex:0];
    [self verifyPathsInExpectedDirectory:expectedDirectory 
                             forSelector:@selector(asPathInDocumentsFolder)];

}

- (void)testPathInTemporaryFolder {
    NSString *temp = NSTemporaryDirectory();
    [self verifyPathsInExpectedDirectory:temp 
                             forSelector:@selector(asPathInTemporaryFolder)];
}

//
//  Test the sidecar path routines.
//

- (void)testSidecarPath {
  
  NSDictionary *testCases = [NSDictionary dictionaryWithObjectsAndKeys:@"foo-sidecar", @"foo",
                             @"foo-sidecar.dat", @"foo.dat",
                             @"/StrongBox/foo-sidecar", @"/StrongBox/foo",
                             @"/StrongBox/foo-sidecar.dat", @"/StrongBox/foo.dat", 
                             @"/StrongBox/foo-sidecar.dat", @"/StrongBox/foo-sidecar.dat",
                             nil];
  for (NSString *test in [testCases allKeys]) {
    
    NSString *expected = [testCases objectForKey:test];
    _GTMDevLog(@"%s -- for %@, expect %@",
               __PRETTY_FUNCTION__,
               test,
               expected);
    NSString *result = [test stringAsSidecarPath];
    STAssertEqualStrings([testCases objectForKey:test], 
                         result, 
                         @"Expected %@ for %@", 
                         expected,
                         test);
  }
}

@end
