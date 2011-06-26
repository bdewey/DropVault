//
//  PasswordController.h
//  DropboxPrototype
//
//  Created by Brian Dewey on 1/16/11.
//
//
//    The |PasswordController| gets the password from the user. In future iterations,
//    it will be responsible for validating the password. The 
//    |PasswordControllerDelegate| will recieve the password when it is entered,
//    or a cancellation notice if the user cancels.
//
//
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

#import <UIKit/UIKit.h>

@protocol PasswordControllerDelegate;

//
//  The |PasswordController| gets a password from the user. The assumption is
//  you modally invoke this. The delegate will get notified when the user is
//  done entering the password or if the user cancels.
//

@interface PasswordController : UIViewController <UITextFieldDelegate> {
@private
  UITextField *passwordField_;
  id<PasswordControllerDelegate> delegate_;
}

@property (nonatomic, retain) IBOutlet UITextField *passwordField;
@property (nonatomic, assign) id<PasswordControllerDelegate> delegate;

@end

//
//  The |PasswordControllerDelegate| protocol defines the messages that are sent
//  by |PasswordController| after processing a password. It is the recipient's
//  responsibility to dismiss |PasswordController| after receiving one of these
//  messages.
//

@protocol PasswordControllerDelegate<NSObject>

//
//  Sent when the user enters a valid password.
//

- (void)passwordController:(PasswordController *)passwordController 
          didEnterPassword:(NSString *)password;

//
//  Sent when the user cancels the password controller without providing a
//  password.
//

- (void)passwordControllerDidCancel:(PasswordController *)passwordController;

@end

