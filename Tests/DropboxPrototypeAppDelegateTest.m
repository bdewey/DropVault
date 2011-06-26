//
//  DropboxPrototypeAppDelegateTest.m
//  DropVault
//
//  Created by Brian Dewey on 2/8/11.
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
#import <OCMock/OCMock.h>
#import <UIKit/UIKit.h>
#import "DropboxPrototypeAppDelegate.h"
#import "RootViewController.h"
#import "DetailViewController.h"


@interface DropboxPrototypeAppDelegateTest : GTMTestCase {
    
}

@end


@implementation DropboxPrototypeAppDelegateTest

//
//  When the app becomes active, it should look for new DropBox files
//  and prompt for a password.
//

- (void)testDidBecomeActive {
    //
    //  The rootViewController should get a lookForNewDropBoxFiles message.
    //
    
    id mockRoot = [OCMockObject mockForClass:[RootViewController class]];
    [[mockRoot expect] performSelector:@selector(lookForNewDropBoxFiles) 
                            withObject:nil 
                            afterDelay:0];
    
    //
    //  The detailViewController should get a presentPasswordController message.
    //
    
    id mockDetail = [OCMockObject mockForClass:[DetailViewController class]];
    [[mockDetail expect] performSelector:@selector(presentPasswordController) 
                              withObject:nil 
                              afterDelay:0];
    
    //
    //  Create and set up the appDelegate.
    //
    
    DropboxPrototypeAppDelegate *appDelegate = [[[DropboxPrototypeAppDelegate alloc] init] autorelease];
    appDelegate.rootViewController = mockRoot;
    appDelegate.detailViewController = mockDetail;
    
    //
    //  Send the message.
    //
    
    [appDelegate applicationDidBecomeActive:nil];
    
    //
    //  ...and validate we got the expected responses.
    //
    
    STAssertNoThrow([mockRoot verify], 
                    @"App Delegate should properly handle didBecomeActive");
    STAssertNoThrow([mockDetail verify],
                    @"AppDelegate should send proper messages to detailViewController");
}

//
//  When the app enters the background, it needs to throw away state.
//

- (void)testEnterBackground {
    
    //
    //  the root should get a setPassword:nil message.
    //
    
    id mockRoot = [OCMockObject mockForClass:[RootViewController class]];
    [[mockRoot expect] setPassword:nil];
    
    //
    //  The detailViewController should get both a setPassword:nil and a
    //  setDetailItem:nil message.
    //
    
    id mockDetail = [OCMockObject mockForClass:[DetailViewController class]];
    [[mockDetail expect] setPassword:nil];
    [[mockDetail expect] setDetailItem:nil];
    
    //
    //  Create the app delegate & connect the mock objects.
    //
    
    DropboxPrototypeAppDelegate *appDelegate = [[[DropboxPrototypeAppDelegate alloc] init] autorelease];
    appDelegate.rootViewController = mockRoot;
    appDelegate.detailViewController = mockDetail;
    
    [appDelegate applicationDidEnterBackground:nil];
    
    STAssertNoThrow([mockRoot verify], 
                    @"AppDelegate should send proper messages to root on applicationDidEnterBackground:");
    STAssertNoThrow([mockDetail verify],
                    @"AppDelegate should send proper messages to detailViewController on applicationDidEnterBackground:");
}

@end
