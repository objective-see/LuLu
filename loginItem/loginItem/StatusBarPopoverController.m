//
//  file: StatusBarPopoverController.m
//  project: lulu (login item)
//  description: popover for status bar
//
//  created by Patrick Wardle
//  copyright (c) 2017 Objective-See. All rights reserved.
//

#import "AppDelegate.h"
#import "StatusBarPopoverController.h"

@implementation StatusBarPopoverController

//'close' button handler
// simply dismiss/close popover
-(IBAction)closePopover:(NSControl *)sender
{
    //close
    [[[self view] window] close];
    
    return;
}

@end
