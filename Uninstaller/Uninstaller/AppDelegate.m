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

@import ServiceManagement;

@implementation AppDelegate

@synthesize gotHelp;
@synthesize xpcComms;
@synthesize statusMsg;
@synthesize configureWindowController;

//main app interface
// kick off uninstaller window
-(void)applicationDidFinishLaunching:(NSNotification *)notification
{
    //alloc/init
    configureWindowController = [[ConfigureWindowController alloc] initWithWindowNibName:@"ConfigureWindowController"];
    
    //show window
    [self.configureWindowController showWindow:nil];

    return;
}

@end
