//
//  file: UpdateWindowController.m
//  project: lulu
//  description: window handler for update window/popup
//
//  created by Patrick Wardle
//  copyright (c) 2020 Objective-See. All rights reserved.
//

#import "consts.h"
#import "utilities.h"
#import "AppDelegate.h"
#import "UpdateWindowController.h"

@implementation UpdateWindowController

@synthesize infoLabel;
@synthesize actionButton;
@synthesize infoLabelString;

//automatically called when nib is loaded
-(void)awakeFromNib
{
    //center
    [self.window center];
    
    return;
}

//automatically invoked when window is loaded
-(void)windowDidLoad
{
    //super
    [super windowDidLoad];
    
    //not in dark mode?
    // make window white
    if(YES != isDarkMode())
    {
        //make white
        self.window.backgroundColor = NSColor.whiteColor;
    }
    
    //indicated title bar is transparent (too)
    self.window.titlebarAppearsTransparent = YES;
    
    //set main label
    self.infoLabel.stringValue = self.infoLabelString;
        
    //make button first responder
    // calling this without a timeout sometimes fails :/
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (100 * NSEC_PER_MSEC)), dispatch_get_main_queue(), ^{
        
        //make first responder
        [self.window makeFirstResponder:self.actionButton];
        
    });

    //make it key window
    [self.window makeKeyAndOrderFront:self];
    
    //activate
    if(@available(macOS 14.0, *)) {
        [NSApp activate];
    }
    else
    {
        [NSApp activateIgnoringOtherApps:YES];
    }
    
    return;
}

//automatically invoked when window is closing
// ->make ourselves unmodal
-(void)windowWillClose:(NSNotification *)notification
{
    //make un-modal
    [[NSApplication sharedApplication] stopModal];
    
    return;
}

//save the main label
-(void)configure:(NSString*)label
{
    //save label's string
    self.infoLabelString = label;
    
    return;
}

//invoked when user clicks button
-(IBAction)buttonHandler:(id)sender
{
    //open URL
    [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:PRODUCT_URL]];
    
    //always close window
    [[self window] close];
        
    return;
}
@end
