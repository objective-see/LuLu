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

//center window
// also make front, init title bar, etc
-(void)awakeFromNib
{
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
    }
    
    //show preferences?
    else if(YES == [[[NSProcessInfo processInfo] arguments] containsObject:CMDLINE_FLAG_PREFS])
    {
        //show preferences window
        [self showPreferences:nil];
        
        //center
        [self.prefsWindowController.window center];
        
        //make key and front
        [self.prefsWindowController.window makeKeyAndOrderFront:self];
    }
    
    //display rules
    // this is the default
    else
    {
        //show rules window
        [self showRules:nil];
        
        //center window
        [self.rulesWindowController.window center];
        
        //make key and front
        [self.rulesWindowController.window makeKeyAndOrderFront:self];
    }

    //make app active
    [NSApp activateIgnoringOtherApps:YES];
    
    return;
}

//app interface
// init user interface
-(void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    //dbg msg
    logMsg(LOG_DEBUG, @"main (rules/pref) app launched");
    
    //for rules/pref view
    // make sure login item is running and register for notifications
    if(YES != [[[NSProcessInfo processInfo] arguments] containsObject:CMDLINE_FLAG_WELCOME])
    {
        //start login item in background
        // method checks first to make sure only one instance is running
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0),
        ^{
               //start
               [self startLoginItem:NO];
        });
        
        //register for notifications from login item
        // if user clicks 'rules' or 'prefs' make sure we show that window
        [[NSDistributedNotificationCenter defaultCenter] addObserver:self selector:@selector(notificationHandler:) name:NOTIFICATION_SHOW_WINDOW object:nil];
    }
    
    return;
}

//unregister notification handler
-(void)applicationWillTerminate:(NSApplication *)application
{
    //for rules/pref view
    // unregister notification
    if(YES != [[[NSProcessInfo processInfo] arguments] containsObject:CMDLINE_FLAG_WELCOME])
    {
        //unregister
        [[NSDistributedNotificationCenter defaultCenter] removeObserver:self name:NOTIFICATION_SHOW_WINDOW object:nil];
    }
    return;
}

//start the (helper) login item
-(BOOL)startLoginItem:(BOOL)shouldRestart
{
    //status var
    BOOL result = NO;
    
    //path to login item app
    NSString* loginItem = nil;
    
    //path to login item binary
    NSString* loginItemBinary = nil;
    
    //login item's pid
    NSNumber* loginItemPID = nil;
    
    //results from 'open'
    NSDictionary* taskResults = nil;
    
    //init path to login item app
    loginItem = [[[NSBundle mainBundle] bundlePath] stringByAppendingPathComponent:[NSString stringWithFormat:@"/Contents/Library/LoginItems/%@.app", LOGIN_ITEM_NAME]];

    //init path to binary
    loginItemBinary = [NSString pathWithComponents:@[loginItem, @"Contents", @"MacOS", LOGIN_ITEM_NAME]];
    
    //dbg msg
    logMsg(LOG_DEBUG, [NSString stringWithFormat:@"looking for login item %@", loginItemBinary]);
    
    //get pid(s) of login item for user
    loginItemPID = [getProcessIDs(loginItemBinary, getuid()) firstObject];
    
    //already running and no restart?
    if( (nil != loginItemPID) &&
        (YES != shouldRestart) )
    {
        //dbg msg
        logMsg(LOG_DEBUG, @"login item already running and 'shouldRestart' not set, so no need to start it");
        
        //happy
        result = YES;
        
        //bail
        goto bail;
    }
    
    //running?
    // kill, as restart flag set
    else if(nil != loginItemPID)
    {
        //kill it
        kill(loginItemPID.intValue, SIGTERM);
        
        //dbg msg
        logMsg(LOG_DEBUG, [NSString stringWithFormat:@"killed login item (%@)", loginItemPID]);
    
        //nap to allow 'kill' sometime...
        [NSThread sleepForTimeInterval:0.5];
    }

    //dbg msg
    logMsg(LOG_DEBUG, @"starting (helper) login item\n");

    //start via 'open'
    // allows launch without losing focus
    taskResults = execTask(OPEN, @[@"-g", loginItem], NO, NO);
    if( (nil == taskResults) ||
        (0 != [taskResults[EXIT_CODE] intValue]) )
    {
        //bail
        goto bail;
    }
    
    //happy
    result = YES;
    
//bail
bail:

    return result;
}

//automatically close when user closes last window
-(BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)theApplication
{
    return YES;
}

//notification handler
-(void)notificationHandler:(NSNotification *)notification
{
    //dbg msg
    logMsg(LOG_DEBUG, [NSString stringWithFormat:@"handling notification from login item %@", notification.userInfo]);
    
    //what window to show?
    switch ([notification.userInfo[@"window"] intValue]) {
        
        //show rules window
        case WINDOW_RULES:
            
            //show
            [self showRules:nil];
            break;
            
        //show preferences window
        case WINDOW_PREFERENCES:
            
            //show
            [self showPreferences:nil];
            break;
            
        default:
            break;
    }
    
    //make it key window
    [self.window makeKeyAndOrderFront:self];
    
    //make window front
    [NSApp activateIgnoringOtherApps:YES];

    return;
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
