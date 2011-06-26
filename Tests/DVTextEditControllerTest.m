//
//  DVTextEditControllerTest.m
//  DropVault
//
//  Created by Brian Dewey on 2/27/11.
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
#import "DVTextEditController.h"


@interface DVTextEditControllerTest : SenTestCase {
  
}

@end


@implementation DVTextEditControllerTest

//
//  Make sure outlets are properly connected.
//

- (void)testOutlets {
  DVTextEditController *controller = [[[DVTextEditController alloc] init] autorelease];
  
  STAssertNotNil(controller, @"Allocation should not fail");
  STAssertNotNil(controller.view, @"Controller should have a view");
  STAssertNotNil(controller.textView, @"textView should be connected");
  STAssertEqualStrings(kDVStringNotesTitle, controller.navigationItem.title, 
                       @"Controller should have correct title");
  STAssertNotNil(controller.navigationItem.leftBarButtonItem,
                 @"Should have a left bar button item");
  STAssertEquals(@selector(cancel), 
                 controller.navigationItem.leftBarButtonItem.action, 
                 @"Left item should be Cancel");
  STAssertNotNil(controller.navigationItem.rightBarButtonItem,
                 @"Should have a right bar button item");
  STAssertEquals(@selector(done), 
                 controller.navigationItem.rightBarButtonItem.action, 
                 @"Left item should be Done");
}

//
//  Make sure the delegate gets invoked on Cancel.
//

- (void)testCancel {
  
  DVTextEditController *controller = [[[DVTextEditController alloc] init] autorelease];
  id mockDelegate = [OCMockObject mockForProtocol:@protocol(DVTextEditDelegate)];
  [[mockDelegate expect] textEditControllerDidCancel:controller];
  controller.delegate = mockDelegate;
  [controller cancel];
  STAssertNoThrow([mockDelegate verify], @"Cancel message should be sent");
}

//
//  Make sure the delegate gets invoked on Done.
//

- (void)testDone {
  
  DVTextEditController *controller = [[[DVTextEditController alloc] init] autorelease];
  id mockDelegate = [OCMockObject mockForProtocol:@protocol(DVTextEditDelegate)];
  [[mockDelegate expect] textEditControllerDidFinish:controller];
  controller.delegate = mockDelegate;
  [controller done];
  STAssertNoThrow([mockDelegate verify], @"Done message should get sent");
}

@end
