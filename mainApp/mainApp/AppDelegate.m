//
//  file: AppDelegate.m
//  project: lulu (main app)
//  description: application delegate
//
//  created by Patrick Wardle
//  copyright (c) 2017 Objective-See. All rights reserved.
//

#import "consts.h"
#import "Update.h"
#import "logging.h"
#import "utilities.h"
#import "AppDelegate.h"

@implementation AppDelegate

@synthesize xpcDaemonClient;
@synthesize aboutWindowController;
@synthesize prefsWindowController;
@synthesize rulesWindowController;
@synthesize welcomeWindowController;

//app interface
// init user interface
-(void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    //path to login item
    NSString* loginItem = nil;
    
    //dbg msg
    logMsg(LOG_DEBUG, @"main (rules/pref) app launched");
    
    //when launched via URL handler
    // no need to do anything here...
    if(YES == self.urlLaunch)
    {
        //all set
        goto bail;
    }
    
    //init deamon comms
    // establishes connection to daemon
    xpcDaemonClient = [[XPCDaemonClient alloc] init];
    
    //show welcome screen?
    if(YES == [[[NSProcessInfo processInfo] arguments] containsObject:CMDLINE_FLAG_WELCOME])
    {
        //disable all menu items except 'About ...'
        for(NSMenuItem* menuItem in NSApplication.sharedApplication.mainMenu.itemArray.firstObject.submenu.itemArray)
        {
            //not 'About ...'
            // disable menu item
            if(YES != [menuItem.title containsString:@"About"])
            {
                //disable
                menuItem.action = nil;
            }
        }
        
        //alloc
        welcomeWindowController = [[WelcomeWindowController alloc] initWithWindowNibName:@"Welcome"];
        
        //center
        [self.welcomeWindowController.window center];
        
        //make key and front
        [self.welcomeWindowController.window makeKeyAndOrderFront:self];
        
        //make app active
        [NSApp activateIgnoringOtherApps:YES];
    }
    
    //otherwise
    // make sure login item is running, and show rules
    else
    {
        //init path to login item
        loginItem = [[[NSBundle mainBundle] bundlePath] stringByAppendingPathComponent:[NSString stringWithFormat:@"/Contents/Library/LoginItems/%@.app", LOGIN_ITEM_NAME]];
        
        //show rules window
        [self showRules:nil];
        
        //if needed
        // start login item
        if(nil == [[NSRunningApplication runningApplicationsWithBundleIdentifier:HELPER_ID] firstObject])
        {
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0),
            ^{
               //start
               startApplication([NSURL fileURLWithPath:loginItem], NSWorkspaceLaunchWithoutActivation);
            });
        }
    }
    
bail:
    
    return;
}

//(custom) url handler
// invoked automatically when user clicks on menu item in login item
-(void)application:(NSApplication *)application openURLs:(NSArray<NSURL *> *)urls
{
    //dbg msg
    logMsg(LOG_DEBUG, [NSString stringWithFormat:@"main (rules/pref) app launched to handle url(s): %@", urls]);
    
    //set flag
    self.urlLaunch = YES;
    
    //init deamon comms
    // establishes connection to daemon
    xpcDaemonClient = [[XPCDaemonClient alloc] init];
    
    //parse each url
    // scan or show prefs...
    for(NSURL* url  in urls)
    {
        //show rules?
        if(YES == [url.host isEqualToString:@"rules"])
        {
            //show
            [self showRules:nil];
        }
        
        //show preferences?
        else if(YES == [url.host isEqualToString:@"preferences"])
        {
            //show
            [self showPreferences:nil];
        }
        
        /*
        //close?
        else if(YES == [url.host isEqualToString:@"close"])
        {
            //bye!
            [NSApp terminate:nil];
        }
        */
    }
    
    return;
}


//automatically close when user closes last window
-(BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)theApplication
{
    return YES;
}

#pragma mark -
#pragma mark Menu Items

//'rules' menu item handler
// alloc and show rules window
-(IBAction)showRules:(id)sender
{
    //alloc rules window controller
    if(nil == self.rulesWindowController)
    {
        //alloc
        rulesWindowController = [[RulesWindowController alloc] initWithWindowNibName:@"Rules"];
    }

    //center
    [self.rulesWindowController.window center];
    
    //show it
    [self.rulesWindowController showWindow:self];
    
    //make it key window
    [[self.rulesWindowController window] makeKeyAndOrderFront:self];
    
    return;
}

//'preferences' menu item handler
// alloc and show preferences window
-(IBAction)showPreferences:(id)sender
{
    //alloc prefs window controller
    if(nil == self.prefsWindowController)
    {
        //alloc
        prefsWindowController = [[PrefsWindowController alloc] initWithWindowNibName:@"Preferences"];
    }
    
    //center
    [self.prefsWindowController.window center];

    //show it
    [self.prefsWindowController showWindow:self];
    
    //make it key window
    [[self.prefsWindowController window] makeKeyAndOrderFront:self];
    
    return;
}

//'about' menu item handler
// ->alloc/show about window
-(IBAction)showAbout:(id)sender
{
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
    
    //invoke function in background that will make window modal
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        
        //make modal
        makeModal(self.aboutWindowController);
        
    });
    
    return;
}

@end
