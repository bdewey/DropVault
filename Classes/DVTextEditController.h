//
//  DVTextEditController.h
//  DropVault
//
//  This class implements a simple modal text editor.
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

#import <UIKit/UIKit.h>

@protocol DVTextEditDelegate;

@interface DVTextEditController : UIViewController {
    
  @private
  UITextView *textView_;
  id<DVTextEditDelegate> delegate_;
}

@property (nonatomic, assign) id<DVTextEditDelegate> delegate;
@property (nonatomic, retain) IBOutlet UITextView *textView;

//
//  Cancel the edit.
//

- (IBAction)cancel;

//
//  Commit the edit.
//

- (IBAction)done;

@end

//
//  Defines the messages sent to the DVTextEditDelegate.
//

@protocol DVTextEditDelegate
- (void)textEditControllerDidCancel:(DVTextEditController *)controller;
- (void)textEditControllerDidFinish:(DVTextEditController *)controller;
@end

