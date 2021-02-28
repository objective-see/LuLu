//
//  file: StatusBarPopoverController.h
//  project: lulu (login item)
//  description: popover for status bar (header)
//
//  created by Patrick Wardle
//  copyright (c) 2017 Objective-See. All rights reserved.
//

@import Cocoa;

@interface StatusBarPopoverController : NSViewController

//message
@property(nonatomic, retain)NSString* message;

//label for popover
@property (weak) IBOutlet NSTextField *label;

@end
