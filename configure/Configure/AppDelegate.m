//
//  file: AppDelegate.m
//  project: lulu (config)
//  description: application main/delegate
//
//  created by Patrick Wardle
//  copyright (c) 2018 Objective-See. All rights reserved.
//

#import "consts.h"
#import "HelperComms.h"
#import "AppDelegate.h"

#import "Configure.h"
#import "utilities.h"
#import "AppDelegate.h"

#import <Security/Authorization.h>
#import <ServiceManagement/ServiceManagement.h>


@implementation AppDelegate

@synthesize gotHelp;
@synthesize xpcComms;
@synthesize statusMsg;
@synthesize configureObj;

@synthesize aboutWindowController;
@synthesize configureWindowController;

//main app interface
-(void)applicationDidFinishLaunching:(NSNotification *)notification
{
    #pragma unused(notification)
    
    //alloc/init Config obj
    configureObj = [[Configure alloc] init];
    
    //show config window
    [self displayConfigureWindow:[self.configureObj isInstalled]];
    
    return;
}

//exit when last window is closed
-(BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)sender
{
    #pragma unused(sender)
    
    return YES;
}

//display configuration window w/ 'install' || 'uninstall' button
-(void)displayConfigureWindow:(BOOL)isInstalled
{
    //alloc/init
    configureWindowController = [[ConfigureWindowController alloc] initWithWindowNibName:@"ConfigureWindowController"];
    
    //display it
    // call this first to so that outlets are connected
    [self.configureWindowController display];
    
    //configure it
    [self.configureWindowController configure:isInstalled];
    
    return;
}


//menu handler for 'about'
-(IBAction)displayAboutWindow:(id)sender
{
    #pragma unused(sender)
    
    //alloc/init settings window
    if(nil == self.aboutWindowController)
    {
        //alloc/init
        aboutWindowController = [[AboutWindowController alloc] initWithWindowNibName:@"AboutWindow"];
    }
    
    //center window
    [[self.aboutWindowController window] center];
    
    //show it
    [self.aboutWindowController showWindow:self];
    
    return;
}

@end
