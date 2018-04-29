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

#import <syslog.h>
#import <Security/Authorization.h>
#import <ServiceManagement/ServiceManagement.h>


@implementation AppDelegate

@synthesize gotHelp;
@synthesize xpcComms;
@synthesize statusMsg;
@synthesize configureObj;

@synthesize aboutWindowController;
@synthesize errorWindowController;
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

//display error window
-(void)displayErrorWindow:(NSDictionary*)errorInfo
{
    //alloc error window
    errorWindowController = [[ErrorWindowController alloc] initWithWindowNibName:@"ErrorWindowController"];
    
    //main thread
    // just show UI alert, unless its fatal (then load URL)
    if(YES == [NSThread isMainThread])
    {
        //non-fatal errors
        // show error error popup
        if(YES != [errorInfo[KEY_ERROR_URL] isEqualToString:FATAL_ERROR_URL])
        {
            //display it
            // call this first to so that outlets are connected
            [self.errorWindowController display];
            
            //configure it
            [self.errorWindowController configure:errorInfo];
        }
        //fatal error
        // launch browser to go to fatal error page, then exit
        else
        {
            //launch browser
            [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:errorInfo[KEY_ERROR_URL]]];
            
            //then exit
            [NSApp terminate:self];
        }
    }
    //background thread
    // have to show error window on main thread
    else
    {
        //show alert
        // in main UI thread
        dispatch_sync(dispatch_get_main_queue(), ^{
            
            //display it
            // call this first to so that outlets are connected
            [self.errorWindowController display];
            
            //configure it
            [self.errorWindowController configure:errorInfo];
            
        });
    }
    
    return;
}

//menu handler for 'about'
- (IBAction)displayAboutWindow:(id)sender
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
