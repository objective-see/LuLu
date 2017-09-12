//
//  file: AboutWindowController.m
//  project: lulu (main app)
//  description: 'about' window controller
//
//  created by Patrick Wardle
//  copyright (c) 2017 Objective-See. All rights reserved.
//

#import "const.h"
#import "Utilities.h"
#import "AboutWindowController.h"

@implementation AboutWindowController

@synthesize patrons;
@synthesize versionLabel;

//automatically called when nib is loaded
// ->center window
-(void)awakeFromNib
{
    //center
    [self.window center];
}

//automatically invoked when window is loaded
// ->set to white
-(void)windowDidLoad
{
    //version
    NSString* version = nil;
    
    //super
    [super windowDidLoad];
    
    //make white
    [self.window setBackgroundColor: NSColor.whiteColor];
    
    //grab app version
    version = getAppVersion();
    if(nil == version)
    {
        //default
        version = @"unknown";
    }
    
    //set version sting
    self.versionLabel.stringValue = version;

    //load patrons
    // <3 you guys & girls
    self.patrons.string = [NSString stringWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"patrons" ofType:@"txt"] encoding:NSUTF8StringEncoding error:NULL];
    if(nil == self.patrons.string)
    {
        //default
        self.patrons.string = @"error: failed to load patrons :/";
    }

    return;
}

//automatically invoked when window is closing
// ->make window unmodal
-(void)windowWillClose:(NSNotification *)notification
{
    //make un-modal
    [[NSApplication sharedApplication] stopModal];
    
    return;
}

//automatically invoked when user clicks any of the buttons
// ->perform actions, such as loading patreon or products URL
-(IBAction)buttonHandler:(id)sender
{
    //support us button
    if(((NSButton*)sender).tag == BUTTON_SUPPORT_US)
    {
        //open URL
        // ->invokes user's default browser
        [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:PATREON_URL]];
    }
    
    //more info button
    else if(((NSButton*)sender).tag == BUTTON_MORE_INFO)
    {
        //open URL
        // ->invokes user's default browser
        [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:PRODUCT_URL]];
    }

    return;
}
@end
