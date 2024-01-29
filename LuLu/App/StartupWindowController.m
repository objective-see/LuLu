//
//  file: StartupWindowController.m
//
//  created by Patrick Wardle
//  copyright (c) 2024 Objective-See. All rights reserved.
//

#import "consts.h"
#import "utilities.h"
#import "AppDelegate.h"
#import "StartupWindowController.h"

/* GLOBALS */

//log handle
extern os_log_t logHandle;

@implementation StartupWindowController

@synthesize spinner;

//automatically called when nib is loaded
// just center window
-(void)awakeFromNib
{
    //center
    [self.window center];
    
    //start progress indicator
    [self.spinner startAnimation:nil];
    
    //not in dark mode?
    // make window white
    if(YES != isDarkMode())
    {
        //make white
        self.window.backgroundColor = NSColor.whiteColor;
    }
    
    //set transparency
    self.window.titlebarAppearsTransparent = YES;
    
    //make it key window
    [self.window makeKeyAndOrderFront:self];
    
    //make window front
    [NSApp activateIgnoringOtherApps:YES];
    
    return;
}

@end
