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
#import "AlertMonitor.h"

@interface AppDelegate ()

@end

@implementation AppDelegate

@synthesize daemonComms;
@synthesize updateWindowController;
@synthesize statusBarMenuController;

@synthesize observer;

//app's main interface
// ->load status bar and kick off monitor
-(void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    //preferences
    __block NSDictionary* preferences;
    
    //path to main app
    NSURL* mainApp = nil;
    
    //dbg msg
    logMsg(LOG_DEBUG, @"starting login item");
    
    //init deamon comms
    daemonComms = [[DaemonComms alloc] init];
    
    //get preferences
    // sends XPC message to daemon
    preferences = [self.daemonComms getPreferences];
    
    //dbg msg
    logMsg(LOG_DEBUG, [NSString stringWithFormat:@"loaded preferences: %@", preferences]);
    
    //no preferences yet? ... first run
    // kick off main app with '-welcome' flag
    if(0 == preferences.count)
    {
        //dbg msg
        logMsg(LOG_DEBUG, @"no preferences found, so kicking off main application w/ '-welcome' flag");
    
        //get path to main app
        mainApp = [NSURL fileURLWithPath:getMainAppPath()];
        
        //launch main app
        // passing in '-welcome'
        [[NSWorkspace sharedWorkspace] launchApplicationAtURL:mainApp options:0 configuration:@{NSWorkspaceLaunchConfigurationArguments: @[CMDLINE_FLAG_WELCOME]} error:nil];
        
        //set up notification for app exit
        // wait until it's exited to complete initializations
        self.observer = [[[NSWorkspace sharedWorkspace] notificationCenter] addObserverForName:NSWorkspaceDidTerminateApplicationNotification object:nil queue:nil usingBlock:^(NSNotification *notification)
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
            [[[NSWorkspace sharedWorkspace] notificationCenter] removeObserver:observer];
            
            //unset
            self.observer = nil;
            
            //(re)load prefs
            // main app should have set em all now
            preferences = [self.daemonComms getPreferences];
            
            //complete initializations
            [self completeInitialization:preferences firstTime:YES];
        }];
    }
    
    //found prefs
    // main app already ran, so just complete init's
    else
    {
        //complete initializations
        [self completeInitialization:preferences firstTime:NO];
    }
    
bail:
    
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
        statusBarMenuController = [[StatusBarMenu alloc] init:self.statusMenu firstTime:firstTime];
        
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
    
    //wait to checkin
    // first time, need a bit to show the popover
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, firstTime * 5 * NSEC_PER_SEC), dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^
    {
        //check in w/ daemon
        [self.daemonComms clientCheckin];
        
        //dbg msg
        logMsg(LOG_DEBUG, @"checked in with daemon");
        
        //init alert monitor
        // in background will monitor / process alerts
        [[[AlertMonitor alloc] init] performSelectorInBackground:@selector(monitor) withObject:nil];
    
    });
    
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
