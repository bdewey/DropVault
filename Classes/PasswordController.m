//
//  PasswordController.m
//  DropboxPrototype
//
//  Created by Brian Dewey on 1/16/11.
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

#import "PasswordController.h"

@implementation PasswordController

@synthesize passwordField = passwordField_, delegate = delegate_;

//
//  Performs view initialization (specifically, setting up the title and the 
//  cancel button).
//

- (void)viewDidLoad {
  _GTMDevLog(@"%s", __PRETTY_FUNCTION__);
  [super viewDidLoad];
  self.navigationItem.title = kProgramName;
  self.navigationItem.leftBarButtonItem = [[[UIBarButtonItem alloc] initWithTitle:@"Cancel" 
                                                                            style:UIBarButtonItemStylePlain 
                                                                           target:self 
                                                                           action:@selector(didCancel)] 
                                           autorelease];
}

//
//  The user touched "cancel".
//

- (IBAction)didCancel {
  [delegate_ passwordControllerDidCancel:self];
}


- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
  // Overriden to allow any orientation.
  return YES;
}


- (void)didReceiveMemoryWarning {
  // Releases the view if it doesn't have a superview.
  [super didReceiveMemoryWarning];
  
  // Release any cached data, images, etc. that aren't in use.
}


- (void)viewDidUnload {
  [super viewDidUnload];
  self.passwordField = nil;
}

//
//  Move focus to the password field when the view appears.
//

- (void)viewDidAppear:(BOOL)animated {
  [self.passwordField becomeFirstResponder];
}


- (void)dealloc {
  [passwordField_ release];
  [super dealloc];
}

#pragma mark -
#pragma mark UITextFieldDelegate

//
//  When the user types "enter" or "done", dismiss the keyboard and notify the
//  delegate.
//

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
  [textField resignFirstResponder];
  [delegate_ passwordController:self didEnterPassword:passwordField_.text];
  return YES;
}


@end
