//
//  PasswordControllerTest.m
//  DropboxPrototype
//
//  Created by Brian Dewey on 1/22/11.
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
#import "PasswordController.h"

//
//  Tests |PasswordController|.
//

@interface PasswordControllerTest : GTMTestCase <PasswordControllerDelegate> {
    @private
    NSString *password_;
    BOOL didCancel_;
    BOOL callbackInvoked_;
}


@end


@implementation PasswordControllerTest

-(void) setPassword:(NSString *)password {
    [password_ autorelease];
    password_ = [password copy];
}

//
//  Remember when the controller gives us a password.
//

- (void)passwordController:(PasswordController *)passwordController 
          didEnterPassword:(NSString *)password {
    callbackInvoked_ = YES;
    didCancel_ = NO;
    [self setPassword:password];
}

//
//  Remember that the controller told us that the user cancelled.
//

- (void)passwordControllerDidCancel:(PasswordController *)passwordController {
    callbackInvoked_ = YES;
    didCancel_ = YES;
}

//
//  Verifies all of the expected bindings of a password controller.
//

- (void)verifyBindingsOfController:(PasswordController *)passwordController {
    STAssertEqualStrings(@"PasswordController", 
                         passwordController.nibName, 
                         @"Nib name incorrect");
    STAssertNotNil(passwordController.view, @"View is nil");
    STAssertNotNil(passwordController.passwordField, @"passwordField is nil");
    STAssertNotNil(passwordController.navigationItem, @"Navigation item not set");
    STAssertEqualStrings(passwordController.navigationItem.title, 
                         kProgramName, 
                         @"PasswordController title should be kProgramName");
    UIBarButtonItem *cancelButton = passwordController.navigationItem.leftBarButtonItem;
    STAssertEqualStrings(@"Cancel",
                         cancelButton.title,
                         @"leftBarButtonItem title should be 'Cancel'");
    STAssertEqualObjects(passwordController,
                         cancelButton.target,
                         @"leftBarButtonItem target should be the PasswordController");
    STAssertEquals(@selector(didCancel),
                   cancelButton.action,
                   @"leftBarButtonItem action should be 'didCancel'");
}    

//
//  Test basic wiring.
//

- (void)testViewBinding {
    PasswordController *passwordController = [[[PasswordController alloc] init] autorelease];
    [passwordController loadView];
    
    //
    //  TODO: Why do I have to call this explicitly? I thought it would be
    //  implicitly called after the loadView.
    //
    
    [passwordController viewDidLoad];
    [self verifyBindingsOfController:passwordController];
}

//
//  Test view reloading.
//

- (void)testViewReload {
    PasswordController *passwordController = [[[PasswordController alloc] init] autorelease];
    [passwordController loadView];
    [passwordController viewDidLoad];
    [self verifyBindingsOfController:passwordController];
    [passwordController didReceiveMemoryWarning];
    
    //
    //  Note I cannot test that view is nil, because accessing the view will
    //  cause it to load.
    //
    
    STAssertNil(passwordController.passwordField, @"passwordField should unload after memory warning");
    
    [passwordController loadView];
    [passwordController viewDidLoad];
    [self verifyBindingsOfController:passwordController];
}

//
//  When the user enters a password, we should get called back with that 
//  password.
//

- (void)testEnterPassword {
    callbackInvoked_ = NO;
    PasswordController *passwordController = [[[PasswordController alloc] initWithNibName:@"PasswordController" 
                                                                                   bundle:nil] autorelease];
    [passwordController loadView];
    passwordController.delegate = self;
    passwordController.passwordField.text = @"Password";
    [passwordController textFieldShouldReturn:passwordController.passwordField];
    STAssertTrue(callbackInvoked_, 
                 @"Callback should be invoked when user presses Done");
    STAssertFalse(didCancel_, 
                  @"Callback should not call passwordControllerDidCancel when user presses Done");
    STAssertEqualStrings(@"Password", 
                         password_, 
                         @"PasswordController should provide correct password to passwordController:didEnterPassword");
}

//
//  When the user taps "cancel," we should get a cancellation callback.
//

- (void)testCancel { 
    callbackInvoked_ = NO;
    PasswordController *passwordController = [[[PasswordController alloc] init] autorelease];
    [passwordController loadView];
    [passwordController viewDidLoad];
    passwordController.delegate = self;
    passwordController.passwordField.text = @"Password";
    UIBarButtonItem *cancelButton = passwordController.navigationItem.leftBarButtonItem;
    [cancelButton.target performSelector:cancelButton.action];
    STAssertTrue(callbackInvoked_, @"Callback should be invoked when cancel button pressed");
    STAssertTrue(didCancel_, @"PasswordController should send passwordControllerDidCancel");
}

@end
