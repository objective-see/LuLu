//
//  file: AppDelegate.m
//  project: lulu (login item)
//  description: app delegate for login item
//
//  created by Patrick Wardle
//  copyright (c) 2017 Objective-See. All rights reserved.
//

#import "consts.h"
#import "Update.h"
#import "logging.h"
#import "utilities.h"
#import "AppDelegate.h"

@interface AppDelegate ()

@end

@implementation AppDelegate

@synthesize alerts;
@synthesize appObserver;
@synthesize prefsChanged;
@synthesize xpcDaemonClient;
@synthesize updateWindowController;
@synthesize statusBarMenuController;

//app's main interface
// load status bar
-(void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    //preferences
    NSDictionary* preferences = nil;
    
    //alloc array for alert (windows)
    alerts = [NSMutableDictionary dictionary];
    
    //init deamon comms
    // establishes connection to daemon
    xpcDaemonClient = [[XPCDaemonClient alloc] init];
    
    //get preferences
    // sends XPC message to daemon
    preferences = [self.xpcDaemonClient getPreferences];
    
    //dbg msg
    logMsg(LOG_DEBUG, [NSString stringWithFormat:@"loaded preferences: %@", preferences]);

    //no preferences yet? ... first run
    // kick off main app to show welcome screen(s)
    if(0 == preferences.count)
    {
        //welcome
        [self welcome];
    }
    
    //all subsequent times
    // load status bar icon, etc
    else
    {
        //complete initializations
        [self completeInitialization:preferences firstTime:NO];
    }
    
    //register notification listener for preferences changing...
    self.prefsChanged = [[NSDistributedNotificationCenter defaultCenter] addObserverForName:NOTIFICATION_PREFS_CHANGED object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *notification)
     {
         //handle
         [self preferencesChanged];
         
     }];
    
    return;
}

//app going away
// cleanup (i.e remove notification, ets
- (void)applicationWillTerminate:(NSNotification *)notification
{
    //remove "prefs changed" observer
    if(nil != self.prefsChanged)
    {
        //remove
        [[NSDistributedNotificationCenter defaultCenter] removeObserver:self.prefsChanged];
        
        //unset
        self.prefsChanged = nil;
    }
    
    return;
}

//show welcome/config window
// wait till it's done, then complete (standard) initializations
-(void)welcome
{
    //path to main app
    NSURL* mainApp = nil;
    
    //dbg msg
    logMsg(LOG_DEBUG, @"first launch, so kicking off main application w/ '-welcome' flag");
    
    //get path to main app
    mainApp = [NSURL fileURLWithPath:getMainAppPath()];
    
    //launch main app
    // passing in '-welcome'
    [[NSWorkspace sharedWorkspace] launchApplicationAtURL:mainApp options:0 configuration:@{NSWorkspaceLaunchConfigurationArguments: @[CMDLINE_FLAG_WELCOME]} error:nil];
    
    //set up notification for main app exit
    // wait until it's exited to complete initializations
    self.appObserver = [[[NSWorkspace sharedWorkspace] notificationCenter] addObserverForName:NSWorkspaceDidTerminateApplicationNotification object:nil queue:nil usingBlock:^(NSNotification *notification)
    {
         //ignore others
         if(YES != [MAIN_APP_ID isEqualToString:[((NSRunningApplication*)notification.userInfo[NSWorkspaceApplicationKey]) bundleIdentifier]])
         {
             //ignore
             return;
         }
         
         //dbg msg
         logMsg(LOG_DEBUG, @"main application completed");
         
         //remove observer
         [[[NSWorkspace sharedWorkspace] notificationCenter] removeObserver:self.appObserver];
         
         //unset
         self.appObserver = nil;
        
         //complete initializations
         // requery daemon to get latest prefs (as main app will have updated them)
         [self completeInitialization:[self.xpcDaemonClient getPreferences] firstTime:YES];
        
    }];
    
    return;
}

//finish up initializations
// based on prefs, show status bar, check for updates, etc...
-(void)completeInitialization:(NSDictionary*)preferences firstTime:(BOOL)firstTime
{
    //run with status bar icon?
    if(YES != [preferences[PREF_NO_ICON_MODE] boolValue])
    {
        //alloc/load nib
        statusBarMenuController = [[StatusBarMenu alloc] init:self.statusMenu preferences:(NSDictionary*)preferences firstTime:firstTime];
        
        //dbg msg
        logMsg(LOG_DEBUG, @"initialized/loaded status bar (icon/menu)");
    }
    else
    {
        //dbg msg
        logMsg(LOG_DEBUG, @"running in headless mode");
    }
    
    //automatically check for updates?
    if(YES != [preferences[PREF_NO_UPDATE_MODE] boolValue])
    {
        //after a 30 seconds
        // check for updates in background
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 30 * NSEC_PER_SEC), dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^
        {
            //dbg msg
            logMsg(LOG_DEBUG, @"checking for update");
           
            //check
            [self check4Update];
       });
    }
    
    return;
}

//preferences changed
// for now, just check status bar icon setting
-(void)preferencesChanged
{
    //preferences
    NSDictionary* preferences = nil;
    
    //dbg msg
    logMsg(LOG_DEBUG, @"handling 'preferences changed' notification");
    
    //get preferences
    // sends XPC message to daemon
    preferences = [self.xpcDaemonClient getPreferences];
    
    //should run with icon?
    if(YES != [preferences[PREF_NO_ICON_MODE] boolValue])
    {
        //need to init?
        if(nil == self.statusBarMenuController)
        {
            //alloc/load nib
            statusBarMenuController = [[StatusBarMenu alloc] init:self.statusMenu preferences:(NSDictionary*)preferences firstTime:NO];
        }
        
        //(always) show
        statusBarMenuController.statusItem.button.hidden = NO;
    }

    //run without icon
    // just hide button
    else
    {
        //hide
        statusBarMenuController.statusItem.button.hidden = YES;
    }
    
    return;
}

//call into Update obj
// check to see if there an update?
-(void)check4Update
{
    //update obj
    Update* update = nil;
    
    //init update obj
    update = [[Update alloc] init];
    
    //check for update
    // ->'updateResponse newVersion:' method will be called when check is done
    [update checkForUpdate:^(NSUInteger result, NSString* newVersion) {
        
        //process response
        [self updateResponse:result newVersion:newVersion];
        
    }];
    
    return;
}

//process update response
// error, no update, update/new version
-(void)updateResponse:(NSInteger)result newVersion:(NSString*)newVersion
{
    //handle response
    // new version, show popup
    switch (result)
    {
        //error
        case -1:
            
            //err msg
            logMsg(LOG_ERR, @"update check failed");
            break;
            
        //no updates
        case 0:
            
            //dbg msg
            logMsg(LOG_DEBUG, @"no updates available");
            break;
            
        //new version
        case 1:
            
            //dbg msg
            logMsg(LOG_DEBUG, [NSString stringWithFormat:@"a new version (%@) is available", newVersion]);

            //alloc update window
            updateWindowController = [[UpdateWindowController alloc] initWithWindowNibName:@"UpdateWindow"];
            
            //configure
            [self.updateWindowController configure:[NSString stringWithFormat:@"a new version (%@) is available!", newVersion] buttonTitle:@"update"];
            
            //center window
            [[self.updateWindowController window] center];
            
            //show it
            [self.updateWindowController showWindow:self];
            
            //invoke function in background that will make window modal
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                
                //make modal
                makeModal(self.updateWindowController);
                
            });
        
            break;
    }
    
    return;
}

@end
