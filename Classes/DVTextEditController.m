//
//  DVTextEditController.m
//  DropVault
//
//  Created by Brian Dewey on 2/24/11.
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

#import "DVTextEditController.h"


@implementation DVTextEditController

@synthesize delegate = delegate_;
@synthesize textView = textView_;

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil {
  
  self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
  if (self) {
    self.navigationItem.title = kDVStringNotesTitle;
    self.navigationItem.leftBarButtonItem = [[[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel
                                                                                           target:self 
                                                                                           action:@selector(cancel)] autorelease];
    self.navigationItem.rightBarButtonItem = [[[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone 
                                                                                            target:self 
                                                                                            action:@selector(done)] autorelease];
  }
  return self;
}

- (void)dealloc {
  
  [textView_ release];
  [super dealloc];
}

- (void)didReceiveMemoryWarning {
  
  // Releases the view if it doesn't have a superview.
  [super didReceiveMemoryWarning];
  
  // Release any cached data, images, etc that aren't in use.
}

#pragma mark - View lifecycle

- (void)viewDidLoad {
  
  [super viewDidLoad];
}

- (void)viewDidUnload {
  
  [self setTextView:nil];
  [super viewDidUnload];
  // Release any retained subviews of the main view.
  // e.g. self.myOutlet = nil;
}

- (void)viewDidAppear:(BOOL)animated {
  [self.textView becomeFirstResponder];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
  
  return YES;
}

//
//  Someone clicked Cancel. Let the delegate know.
//

- (IBAction)cancel {
  [delegate_ textEditControllerDidCancel:self];
}

//
//  Someone clicked Done. Let the delegate know.
//

- (IBAction)done {
  [delegate_ textEditControllerDidFinish:self];
}

@end
