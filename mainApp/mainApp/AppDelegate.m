//
//  file: AppDelegate.m
//  project: lulu (main app)
//  description: application delegate
//
//  created by Patrick Wardle
//  copyright (c) 2017 Objective-See. All rights reserved.
//

#import "const.h"
#import "Update.h"
#import "Logging.h"
#import "Utilities.h"
#import "AppDelegate.h"

@implementation AppDelegate

@synthesize aboutWindowController;
@synthesize prefsWindowController;
@synthesize rulesWindowController;

//center window
// also make front, init title bar, etc
-(void)awakeFromNib
{
    //args
    NSArray *arguments = nil;
    
    //grab args
    arguments = [[NSProcessInfo processInfo] arguments];
    
    //handle case for '-prefs'
    if( (2 == arguments.count) &&
        (YES == [CMDLINE_FLAG_PREFS isEqualToString:arguments[1]]) )
    {
        //show preferences window
        [self showPreferences:nil];
        
        //center
        [[self.prefsWindowController window] center];
    }
    
    //display default window
    // this is the rules window
    else
    {
        //show rules window
        [self showRules:nil];
        
        //center window
        [[self.rulesWindowController window] center];
    }
    
    return;
}

//app interface
// init user interface
-(void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    //app prefs
    NSUserDefaults* appPreferences = nil;
    
    //dbg msg
    #ifdef DEBUG
    logMsg(LOG_DEBUG, @"main (config) app launched");
    #endif

    //alloc/init preferences
    appPreferences = [[NSUserDefaults alloc] initWithSuiteName:@"group.com.objective-see.lulu"];
    
    //no preferences?
    // set some default ones
    if( (nil == [appPreferences objectForKey:PREF_PASSIVE_MODE]) ||
        (nil == [appPreferences objectForKey:PREF_ICONLESS_MODE]) ||
        (nil == [appPreferences objectForKey:PREF_NOUPDATES_MODE]) )
    {
        //set defaults
        [appPreferences registerDefaults:@{PREF_PASSIVE_MODE:@NO, PREF_ICONLESS_MODE:@NO, PREF_NOUPDATES_MODE:@NO}];
        
        //sync
        [appPreferences synchronize];
    }
    
    //start login item in background
    // method checks first to make sure only 1 instance is running
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0),
    ^{
        //start
        [self startLoginItem:NO];
    });
    
    //register for notifications from login item
    // if user clicks 'rules' or 'prefs' make sure we show that window
    [[NSDistributedNotificationCenter defaultCenter] addObserver:self selector:@selector(notificationHandler:) name:NOTIFICATION_SHOW_WINDOW object:nil];

    return;
}

//unregister notification handler
-(void)applicationWillTerminate:(NSApplication *)application
{
    //unregister notification
    [[NSDistributedNotificationCenter defaultCenter] removeObserver:self name:NOTIFICATION_SHOW_WINDOW object:nil];
    
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
    
    //error
    NSError* error = nil;
    
    //config (args, etc)
    // ->can't be nil, so init to blank here
    NSDictionary* configuration = @{};
    
    //init path to login item app
    loginItem = [[[NSBundle mainBundle] bundlePath] stringByAppendingPathComponent:[NSString stringWithFormat:@"/Contents/Library/LoginItems/%@.app", LOGIN_ITEM_NAME]];
                 
    //init path to binary
    loginItemBinary = [NSString pathWithComponents:@[loginItem, @"Contents", @"MacOS", LOGIN_ITEM_NAME]];
    
    //get pid(s) of login item for user
    loginItemPID = [getProcessIDs(loginItemBinary, getuid()) firstObject];
    
    //didn't find it?
    // ->try lookup bundle as login items sometimes show up as that
    if(nil == loginItemPID)
    {
        //lookup via bundle
        loginItemPID = [getProcessIDs(@"com.objective-see.luluHelper", getuid()) firstObject];
    }
    
    //already running and no restart?
    if( (nil != loginItemPID) &&
        (YES != shouldRestart) )
    {
        //dbg msg
        #ifdef DEBUG
        logMsg(LOG_DEBUG, @"login item already running and 'shouldRestart' not set, so no need to start it");
        #endif
        
        //happy
        result = YES;
        
        //bail
        goto bail;
    }
    
    //running?
    // ->kill, as restart flag set
    else if(nil != loginItemPID)
    {
        //kill it
        kill(loginItemPID.unsignedShortValue, SIGTERM);
        
        //dbg msg
        #ifdef DEBUG
        logMsg(LOG_DEBUG, [NSString stringWithFormat:@"killed login item (%@)", loginItemPID]);
        #endif
        
        //nap
        [NSThread sleepForTimeInterval:0.5];
    }

    //dbg msg
    #ifdef DEBUG
    logMsg(LOG_DEBUG, @"starting (helper) login item\n");
    #endif
    
    //launch it
    [[NSWorkspace sharedWorkspace] launchApplicationAtURL:[NSURL fileURLWithPath:loginItem] options:NSWorkspaceLaunchWithoutActivation configuration:configuration error:&error];
    if(nil != error)
    {
        //err msg
        logMsg(LOG_ERR, [NSString stringWithFormat:@"failed to start login item, %@/%@", loginItem, error]);
        
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
    #ifdef DEBUG
    logMsg(LOG_DEBUG, [NSString stringWithFormat:@"handling notification from login item %@", notification.userInfo]);
    #endif

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

    return;
}

#pragma mark -
#pragma mark Menu Items

//'rules' menu item handler
// alloc andshow rules window
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
