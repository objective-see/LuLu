//
//  AppDelegate.m
//  LuLu
//
//  Created by Patrick Wardle on 8/1/20.
//  Copyright (c) 2020 Objective-See. All rights reserved.
//

#import "consts.h"
#import "Update.h"
#import "utilities.h"
#import "Extension.h"
#import "AppDelegate.h"

/* GLOBALS */

//log handle
extern os_log_t logHandle;

//alert windows
NSMutableDictionary* alerts = nil;

//extension obj
//Extension* extension = nil;

@interface AppDelegate ()

@property (weak) IBOutlet NSWindow *window;

@end

@implementation AppDelegate

@synthesize xpcDaemonClient;
@synthesize aboutWindowController;
@synthesize prefsWindowController;
@synthesize rulesWindowController;
@synthesize updateWindowController;
@synthesize statusBarItemController;
@synthesize welcomeWindowController;

//main app interface
-(void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    //dbg msg
    os_log_debug(logHandle, "%s", __PRETTY_FUNCTION__);
    
    //don't relaunch
    [NSApp disableRelaunchOnLogin];

    //CHECK 0x1:
    // must be run from /Applications as LuLu.app
    if(YES != [NSBundle.mainBundle.bundlePath isEqualToString:[@"/Applications" stringByAppendingPathComponent:APP_NAME]])
    {
        //dbg msg
        os_log_debug(logHandle, "LuLu running from %{public}@, not from within /Applications", NSBundle.mainBundle.bundlePath);
        
        //foreground
        [NSApp setActivationPolicy:NSApplicationActivationPolicyRegular];
        
        //show alert
        showAlert([NSString stringWithFormat:@"LuLu must run from:\r\n  %@", [@"/Applications" stringByAppendingPathComponent:APP_NAME]], @"...please copy it to /Applications and re-launch.");
        
        //exit
        [NSApplication.sharedApplication terminate:self];
    }
    
    //CHECK 0x2:
    // is v1.* installed?
    // if so, need to launch uninstaller (to remove kext)
    if(YES == [self shouldLaunchUninstaller])
    {
        //dbg msg
        os_log_debug(logHandle, "version 1.* detected, will launch (un)installer");
        
        //persist as login item
        // as want to be (re)launched after v1.0 uninstall (which requires reboot)
        if(YES != toggleLoginItem(NSBundle.mainBundle.bundleURL, ACTION_INSTALL_FLAG))
        {
            //err msg
            os_log_error(logHandle, "ERROR: failed to install self as login item");
        
        }
        //dbg msg
        else os_log_debug(logHandle, "installed self as login item");
        
        //launch (v1.*) uninstaller
        if(YES != [self launchUninstaller])
        {
            //err msg
            os_log_error(logHandle, "ERROR: failed to launch v1.* uninstaller");
            
        }
        //dbg msg
        else os_log_debug(logHandle, "launched v1.* uninstaller");
                
        //exit
        // on reboot we'll be re-launched to continue...
        [NSApplication.sharedApplication terminate:self];
    }
    
    //first time
    // show/walk thru welcome screen(s)
    // ...will call back here to complete initializations
    if(YES == [self isFirstTime])
    {
        //dbg msg
        os_log_debug(logHandle, "first launch, will kick of welcome window(s)");
        
        //alloc window controller
        welcomeWindowController = [[WelcomeWindowController alloc] initWithWindowNibName:@"Welcome"];
        
        //show window
        [self.welcomeWindowController showWindow:self];
        
        //set activation policy
        [self setActivationPolicy];
        
        //install (self as) login item
        if(YES != toggleLoginItem(NSBundle.mainBundle.bundleURL, ACTION_INSTALL_FLAG))
        {
            //err msg
            os_log_error(logHandle, "ERROR: failed to install self as login item");
            
        }
        //dbg msg
        else os_log_debug(logHandle, "installed self as login item");
    }
    
    //subsequent launches...
    // launch extension & complete initializations
    else
    {
        //dbg
        os_log_debug(logHandle, "subsequent launch...");
        
        //(re)activate extension
        // this will call back to complete inits when done
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0),
        ^{
            //extension
            Extension* extension = nil;
            
            //wait semaphore
            dispatch_semaphore_t semaphore = 0;
            
            //init extension object
            extension = [[Extension alloc] init];
            
            //init wait semaphore
            semaphore = dispatch_semaphore_create(0);
            
            //kick off extension activation request
            [extension toggleExtension:ACTION_ACTIVATE reply:^(BOOL toggled)
            {
                //dbg msg
                os_log_debug(logHandle, "extension 'activate' returned");
                
                //signal semaphore
                dispatch_semaphore_signal(semaphore);
                
                //error
                if(YES != toggled)
                {
                    //err msg
                    os_log_error(logHandle, "ERROR: failed to activate extension");
                    
                    //show error on main thread
                    dispatch_async(dispatch_get_main_queue(), ^{
                        
                        //foreground
                        [NSApp setActivationPolicy:NSApplicationActivationPolicyRegular];
                        
                        //show alert
                        showAlert(@"ERROR: activation failed", @"failed to activate system/network extension");
                        
                        //exit
                        [NSApplication.sharedApplication terminate:self];
                        
                    });
                }
                //happy
                else
                {
                    //dbg msg
                    os_log_debug(logHandle, "extension + network filtering approved");
                    
                    //wait till it's up and running
                    while(YES != [extension isExtensionRunning])
                    {
                        //nap
                        [NSThread sleepForTimeInterval:0.25];
                    }
                    
                    //dbg msg
                    os_log_debug(logHandle, "extension now up and running");
                    
                    //show error on main thread
                    dispatch_async(dispatch_get_main_queue(), ^{
                        
                        //complete inits
                        [self completeInitialization:nil];
                        
                    });
                }
            }];
            
            //wait for extension semaphore
            dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);
        });
    }

bail:
    
    return;
}

//first launch?
// check for install time(stamp)
-(BOOL)isFirstTime
{
   return (nil == [[NSMutableDictionary dictionaryWithContentsOfFile:[INSTALL_DIRECTORY stringByAppendingPathComponent:PREFS_FILE]] objectForKey:PREF_INSTALL_TIMESTAMP]);
}

//check if v1.* is installed
// this requires (un)installer to remove
-(BOOL)shouldLaunchUninstaller
{
    //check for v1.* launch item (bundle)
    return [NSFileManager.defaultManager fileExistsAtPath:[INSTALL_DIRECTORY stringByAppendingPathComponent:@"LuLu.bundle"]];
}

//launch v1. uninstaller
-(BOOL)launchUninstaller
{
    //flag
    BOOL launched = NO;
    
    //error
    NSError* error = nil;
    
    //path
    NSString* path = nil;
    
    //init path
    path = [NSBundle.mainBundle.resourcePath stringByAppendingPathComponent:UNINSTALLER_V1];
    
    //dbg msg
    os_log_debug(logHandle, "launching v1.* uninstaller (%{public}@)", path);

    //launch
    if(YES != [NSWorkspace.sharedWorkspace launchApplication:path])
    {
        //err msg
        os_log_error(logHandle, "ERROR: failed to launch v1.* uninstaller (%{public}@, error:%{public}@)", path, error);
        
        //bail
        goto bail;
    }
    
    //happy
    launched = YES;
    
bail:
    
    return launched;
}

//handle user double-clicks
// app is (likely) already running as login item, so show (or) activate window
-(BOOL)applicationShouldHandleReopen:(NSApplication *)sender hasVisibleWindows:(BOOL)hasVisibleWindows
{
    //extension
    Extension* extension = nil;

    //init extension object
    extension = [[Extension alloc] init];
    
    //dbg msg
    os_log_debug(logHandle, "method '%s' invoked (hasVisibleWindows: %d)", __PRETTY_FUNCTION__, hasVisibleWindows);
    
    //extention isn't running?
    // show alert, otherwise things get confusing
    if(YES != [extension isExtensionRunning])
    {
        //show alert
        [self noExtensionAlert];
        
        //bail
        goto bail;
    }
    
    //no visible window(s)
    // default to show preferences
    if(YES != hasVisibleWindows)
    {
        //show prefs
        [self showPreferences:nil];
    }
    
bail:
    
    return NO;
}

//when extension is not running
// show alert to user, to open sys prefs, or exit
-(void)noExtensionAlert
{
    //alert
    NSAlert* alert = nil;
    
    //response
    NSModalResponse response = 0;

    //init alert
    alert = [[NSAlert alloc] init];
    
    //set style
    alert.alertStyle = NSAlertStyleWarning;
    
    //main text
    alert.messageText = @"LuLu's Network Extension Is Not Running";
    
    //details
    alert.informativeText = @"Extensions must be manually approved via System Preferences.";
    
    //add button
    [alert addButtonWithTitle:@"Open Security Prefs"];

    //add button
    [alert addButtonWithTitle:@"Exit LuLu"];

    //foreground
    [NSApp setActivationPolicy:NSApplicationActivationPolicyRegular];

    //make key and front
    [self.window makeKeyAndOrderFront:self];

    //make app active
    [NSApp activateIgnoringOtherApps:YES];
    
    //dbg msg
    os_log_debug(logHandle, "showing 'no extension running alert' to user...");

    //show alert
    // modal/blocks until response
    response = [alert runModal];
    
    //dbg msg
    os_log_debug(logHandle, "user responsed with %ld", (long)response);
    
    // response: open system prefs?
    if(NSModalResponseOpen == response)
    {
        //dbg msg
        os_log_debug(logHandle, "launching System Preferenes...");
        
        //launch system prefs and show 'privacy'
        [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"x-apple.systempreferences:com.apple.preference.security?General"]];
    }
    //ok
    // user wants to quit
    else
    {
        //dbg msg
        os_log_debug(logHandle, "exiting ...bye!");
        
        //exit
        [NSApplication.sharedApplication terminate:self];
    }
    
    return;
}

//'rules' menu item handler
// alloc and show rules window
-(IBAction)showRules:(id)sender
{
    //dbg msg
    os_log_debug(logHandle, "method '%s' invoked", __PRETTY_FUNCTION__);
    
    //alloc rules window controller
    if(nil == self.rulesWindowController)
    {
        //alloc
        rulesWindowController = [[RulesWindowController alloc] initWithWindowNibName:@"Rules"];
    }
    
    //configure (UI)
    [self.rulesWindowController configure];
    
    //make active
    [self makeActive:self.rulesWindowController];
    
    return;
}

//'preferences' menu item handler
// alloc and show preferences window
-(IBAction)showPreferences:(id)sender
{
    //dbg msg
    os_log_debug(logHandle, "method '%s' invoked", __PRETTY_FUNCTION__);
    
    //alloc prefs window controller
    if(nil == self.prefsWindowController)
    {
        //alloc
        prefsWindowController = [[PrefsWindowController alloc] initWithWindowNibName:@"Preferences"];
    }
    
    //make active
    [self makeActive:self.prefsWindowController];
    
    return;
}

//'about' menu item handler
// alloc/show the about window
-(IBAction)showAbout:(id)sender
{
    //dbg msg
    os_log_debug(logHandle, "method '%s' invoked", __PRETTY_FUNCTION__);
    
    //alloc/init settings window
    if(nil == self.aboutWindowController)
    {
        //alloc/init
        aboutWindowController = [[AboutWindowController alloc] initWithWindowNibName:@"AboutWindow"];
    }
    
    //center window
    [self.aboutWindowController.window center];
    
    //show window
    [self.aboutWindowController showWindow:self];

    return;
}

//preferences changed
// for now, just check status bar icon setting
-(void)preferencesChanged:(NSDictionary*)preferences
{
    //update status bar
    [self toggleIcon:preferences];
    
    return;
}

//close window handler
// close rules || pref window
-(IBAction)closeWindow:(id)sender
{
    //dbg msg
    os_log_debug(logHandle, "method '%s' invoked", __PRETTY_FUNCTION__);
    
    //key window
    NSWindow *keyWindow = nil;
    
    //get key window
    keyWindow = [[NSApplication sharedApplication] keyWindow];
    
    //close
    // but only for rules/pref/about window
    if( (keyWindow != self.aboutWindowController.window) &&
        (keyWindow != self.prefsWindowController.window) &&
        (keyWindow != self.rulesWindowController.window) )
    {
        //dbg msg
        os_log_debug(logHandle, "key window is not rules or pref window, so ignoring...");
        
        //ignore
        goto bail;
    }
    
    //close
    [keyWindow close];
    
    //set activation policy
    [self setActivationPolicy];
    
bail:
    
    return;
}

//make a window control/window front/active
-(void)makeActive:(NSWindowController*)windowController
{
    //make foreground
    [NSApp setActivationPolicy:NSApplicationActivationPolicyRegular];
    
    //center
    [windowController.window center];

    //show it
    [windowController showWindow:self];
    
    //make it key window
    [[windowController window] makeKeyAndOrderFront:self];
    
    //make window front
    [NSApp activateIgnoringOtherApps:YES];
    
    return;
}

//toggle (status) bar icon
-(void)toggleIcon:(NSDictionary*)preferences
{
    //dbg msg
    os_log_debug(logHandle, "method '%s' invoked", __PRETTY_FUNCTION__);
    
    //should run with no icon?
    // init and show status bar item
    if(YES != [preferences[PREF_NO_ICON_MODE] boolValue])
    {
        //already showing?
        if(nil != self.statusBarItemController)
        {
            //bail
            goto bail;
        }
        
        //dbg msg
        os_log_debug(logHandle, "initializing status bar item/menu");
        
        //alloc/load status bar icon/menu
        statusBarItemController = [[StatusBarItem alloc] init:self.statusMenu preferences:(NSDictionary*)preferences];
    }
    
    //run without icon
    // remove status bar item
    else
    {
        //dbg msg
        os_log_debug(logHandle, "removing status bar item/menu");
        
        //already removed?
        if(nil == self.statusBarItemController)
        {
            //bail
            goto bail;
        }
        
        //remove status item
        [self.statusBarItemController removeStatusItem];
        
        //unset
        self.statusBarItemController = nil;
    }
    
bail:
    
    return;
}

//set app foreground/background
-(void)setActivationPolicy
{
    //visible window
    BOOL visibleWindow = NO;
    
    //dbg msg
    os_log_debug(logHandle, "method '%s' invoked", __PRETTY_FUNCTION__);
    
    //find any visible windows
    for(NSWindow* window in NSApp.windows)
    {
        //visible window?
        // that's not status bar?
        if( (YES == window.isVisible) &&
            (YES != [window.className isEqualToString:@"NSStatusBarWindow"]) )
        {
            //set flag
            visibleWindow = YES;
            
            //done
            break;
        }
    }
    
    //any windows?
    // bring app to foreground
    if(YES == visibleWindow)
    {
        //dbg msg
        os_log_debug(logHandle, "window(s) visible, setting policy: NSApplicationActivationPolicyRegular");
        
        //foreground
        [NSApp setActivationPolicy:NSApplicationActivationPolicyRegular];
    }
    
    //no more windows
    // send app to background
    else
    {
        //dbg msg
        os_log_debug(logHandle, "window(s) not visible, setting policy: NSApplicationActivationPolicyAccessory");
        
        //background
        [NSApp setActivationPolicy:NSApplicationActivationPolicyAccessory];
    }
    
    return;
}

//finish up initializations
-(void)completeInitialization:(NSDictionary*)initialPreferenes
{
    //preferences
    NSDictionary* preferences = nil;
       
    //dbg msg
    os_log_debug(logHandle, "method '%s' invoked", __PRETTY_FUNCTION__);
    
    //alloc array for alert (windows)
    alerts = [NSMutableDictionary dictionary];
    
    //init extension comms
    // establishes connection to extension
    xpcDaemonClient = [[XPCDaemonClient alloc] init];
    
    //initial prefs?
    // send to extension
    if(nil != initialPreferenes)
    {
        //set prefs
        [self.xpcDaemonClient updatePreferences:initialPreferenes];
    }

    //(always) get preferences from extension
    // also establishes (persistent) connection with daemon
    preferences = [self.xpcDaemonClient getPreferences];
    
    //dbg msg
    os_log_debug(logHandle, "loaded preferences %{public}@", preferences);
    
    //run with status bar icon?
    if(YES != [preferences[PREF_NO_ICON_MODE] boolValue])
    {
        //alloc/load nib
        statusBarItemController = [[StatusBarItem alloc] init:self.statusMenu preferences:(NSDictionary*)preferences];
        
        //dbg msg
        os_log_debug(logHandle, "initialized/loaded status bar (icon/menu)");
    }
    else
    {
        //dbg msg
        os_log_debug(logHandle, "running in 'no icon' mode (so no need for status bar)");
    }
    
    //automatically check for updates?
    if(YES != [preferences[PREF_NO_UPDATE_MODE] boolValue])
    {
        //after a 30 seconds
        // check for updates in background
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 30 * NSEC_PER_SEC), dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^
        {
            //dbg msg
            os_log_debug(logHandle, "checking for update");
           
            //check
            [self check4Update];
       });
    }
    
    return;
}

//check for update
-(void)check4Update
{
    //update obj
    Update* update = nil;
    
    //init update obj
    update = [[Update alloc] init];
    
    //check for update
    // ->'updateResponse newVersion:' method will be called when check is done
    [update checkForUpdate:^(NSUInteger result, NSString* newVersion) {
        
        //handle response
        // new version, show popup
        switch(result)
        {
            //error
            case -1:
                os_log_error(logHandle, "update check failed");
                break;
                
            //no updates
            case 0:
                os_log_debug(logHandle, "no updates available");
                break;
                
            //new version
            // show update window
            case 1:
                
                //dbg msg
                os_log_debug(logHandle, "a new version (%@) is available", newVersion);

                //alloc update window
                self.updateWindowController = [[UpdateWindowController alloc] initWithWindowNibName:@"UpdateWindow"];
                
                //configure
                [self.updateWindowController configure:[NSString stringWithFormat:@"a new version (%@) is available!", newVersion]];
                
                //center window
                [self.updateWindowController.window center];
                
                //show it
                [self.updateWindowController showWindow:self];
                
                //invoke function in background that will make window modal
                dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                    
                    //make modal
                    makeModal(self.updateWindowController);
                    
                });
            
                break;
        }
    
    }];
    
    return;
}

//quit button handler
// do any cleanup, then exit
-(IBAction)quit:(id)sender
{
    //(confirmation) alert
    NSAlert* alert = nil;
    
    //dbg msg
    os_log_debug(logHandle, "quitting...");
    
    //init alert
    alert = [[NSAlert alloc] init];
     
    //set style
    alert.alertStyle = NSAlertStyleInformational;

    //main text
    alert.messageText = @"Quit LuLu?";

    //details
    alert.informativeText = @"...this will exit LuLu (until restart/(re)login).";

    //add button
    [alert addButtonWithTitle:@"Quit"];

    //add button
    [alert addButtonWithTitle:@"Cancel"];

    //foreground
    [NSApp setActivationPolicy:NSApplicationActivationPolicyRegular];

    //make key and front
    [self.window makeKeyAndOrderFront:self];

    //make app active
    [NSApp activateIgnoringOtherApps:YES];

    //show alert
    // cancel? ignore
    if(NSModalResponseCancel == [alert runModal])
    {
         //dbg msg
         os_log_debug(logHandle, "user canceled quitting");
         
         //(re)background
         [self setActivationPolicy];
    }
    //ok
    // user wants to quit!
    else
    {
        //dbg msg
        os_log_debug(logHandle, "user confirmed quit");
        
        //deactive network extension
        // this will also cause the extension to be unloaded
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            
            //extension
            Extension* extension = nil;
            
            //wait semaphore
            dispatch_semaphore_t semaphore = 0;
            
            //init extension object
            extension = [[Extension alloc] init];
            
            //init wait semaphore
            semaphore = dispatch_semaphore_create(0);
            
            //kick off extension activation request
            [extension toggleExtension:ACTION_DEACTIVATE reply:^(BOOL toggled)
            {
                //dbg msg
                os_log_debug(logHandle, "extension 'deactivate' returned...");
                
                //signal semaphore
                dispatch_semaphore_signal(semaphore);
                
                //error
                // user likely cancelled
                if(YES != toggled)
                {
                   //err msg
                   os_log_error(logHandle, "ERROR: failed to deactivate extension (won't quit)");
                }
                //happy
                else
                {
                    //terminate network monitor
                    [self terminateNetworkMonitor];
                    
                    //dbg msg
                    os_log_debug(logHandle, "all done, goodbye!");
                    
                    //bye
                    [NSApplication.sharedApplication terminate:self];
                }
            }];
            
            //wait for extension semaphore
            dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);

        });
    }
    
    return;
}

//terminate network monitor
-(void)terminateNetworkMonitor
{
    //find match
    // will check if LuLu's, then will terminate
    for(NSRunningApplication* networkMonitor in [NSRunningApplication runningApplicationsWithBundleIdentifier:@"com.objective-see.Netiquette"])
    {
        //non LuLu instance?
        if(YES != [networkMonitor.bundleURL.path hasPrefix:NSBundle.mainBundle.resourcePath]) continue;
        
        //dbg msg
        os_log_debug(logHandle, "terminating network monitor: %{public}@", networkMonitor);
        
        //terminate
        [networkMonitor terminate];
    }
    
    return;
}

//uninstall menu handler
// cleanup all the thingz!
-(IBAction)uninstall:(id)sender
{
    //(confirmation) alert
    NSAlert* alert = nil;
    
    //init alert
    alert = [[NSAlert alloc] init];
    
    //set style
    alert.alertStyle = NSAlertStyleInformational;
    
    //main text
    alert.messageText = @"Uninstall LuLu?";
    
    //details
    alert.informativeText = @"...this will fully remove LuLu from your Mac!";
    
    //add button
    [alert addButtonWithTitle:@"Uninstall"];

    //add button
    [alert addButtonWithTitle:@"Cancel"];
    
    //foreground
    [NSApp setActivationPolicy:NSApplicationActivationPolicyRegular];

    //make key and front
    [self.window makeKeyAndOrderFront:self];
   
    //make app active
    [NSApp activateIgnoringOtherApps:YES];
    
    //show alert
    // and if not a 'cancel', uninstall
    if(NSModalResponseCancel != [alert runModal])
    {
        //dbg msg
        os_log_debug(logHandle, "user confirmed uninstall");

        //tell extension to uninstall
        // and then deactive network extension
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            
            //extension
            Extension* extension = nil;
            
            //flag
            __block BOOL deactivated = NO;
            
            //wait semaphore
            dispatch_semaphore_t semaphore = 0;
            
            //error
            NSError* error = nil;
            
            //app path
            NSString* path = nil;

            //init extension object
            extension = [[Extension alloc] init];
            
            //init wait semaphore
            semaphore = dispatch_semaphore_create(0);
            
            //tell ext to uninstall
            // remove rules, etc, etc
            if(YES != [self.xpcDaemonClient uninstall])
            {
                //err msg
                os_log_error(logHandle, "ERROR: daemon's XPC uninstall logic");
                
                //but continue onwards
            }
            
            //user has to remove
            // otherwise we get into a funky state :/
            while(YES)
            {
                //kick off extension activation request
                [extension toggleExtension:ACTION_DEACTIVATE reply:^(BOOL toggled)
                {
                    //save
                    deactivated = toggled;
                    
                    //toggled ok?
                    if(YES == toggled)
                    {
                        //dbg msg
                        os_log_debug(logHandle, "extension deactivated");
                    }
                    //failed?
                    else
                    {
                        //err msg
                        os_log_error(logHandle, "ERROR: failed to deactivate extension, will reattempt");
                    }
                    
                    //signal semaphore
                    dispatch_semaphore_signal(semaphore);
                }];
                
                //wait for extension semaphore
                dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);
                
                //dbg msg
                os_log_debug(logHandle, "extension event triggered");
                
                //deactivated?
                if(YES == deactivated) break;
            }
            
            //remove login item
            if(YES != toggleLoginItem(NSBundle.mainBundle.bundleURL, ACTION_UNINSTALL_FLAG))
            {
                //err msg
                os_log_error(logHandle, "ERROR: failed to uninstall login item");
                
            } else os_log_debug(logHandle, "uninstalled login item");
            
            //init app path
            path = NSBundle.mainBundle.bundlePath;
            
            //remove app
            if(YES != [NSFileManager.defaultManager removeItemAtPath:path error:&error])
            {
                //err msg
                os_log_error(logHandle, "ERROR: failed to remove %{public}@ (error: %{public}@)", path, error);
                
            } else os_log_debug(logHandle, "removed %{public}@", path);
                  
            //terminate network monitor
            [self terminateNetworkMonitor];
            
            //exit
            [NSApplication.sharedApplication terminate:self];
            
        });
    }
    else
    {
        //dbg msg
        os_log_debug(logHandle, "user canceled uninstall");
    
        //(re)background
        [self setActivationPolicy];
    }
        
bail:
    
    return;
}

@end
