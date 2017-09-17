//
//  file: AppDelegate.m
//  project: lulu (login item)
//  description: app delegate for login item
//
//  created by Patrick Wardle
//  copyright (c) 2017 Objective-See. All rights reserved.
//

#import "const.h"
#import "Update.h"
#import "Logging.h"
#import "Utilities.h"
#import "AppDelegate.h"
#import "AlertMonitor.h"

@interface AppDelegate ()

@end

@implementation AppDelegate

@synthesize updateWindowController;
@synthesize statusBarMenuController;

//app's main interface
// ->load status bar and kick off monitor
-(void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    //app preferences
    NSUserDefaults* appPreferences = nil;
    
    //alert monitor obj
    AlertMonitor* alertMonitor = nil;
    
    //dbg msg
    #ifdef DEBUG
    logMsg(LOG_DEBUG, @"starting login item app logic");
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
    
    //init/load status bar
    // ->but only if user didn't say: 'run in headless mode'
    if(YES != [appPreferences boolForKey:PREF_ICONLESS_MODE])
    {
        //alloc/load nib
        statusBarMenuController = [[StatusBarMenu alloc] init:self.statusMenu];
        
        //dbg msg
        #ifdef DEBUG
        logMsg(LOG_DEBUG, @"initialized/loaded status bar (icon/menu)");
        #endif
    }
    #ifdef DEBUG
    else
    {
        //dbg msg
        logMsg(LOG_DEBUG, @"running in headless mode");
    }
    #endif
    
    //check for updates
    // but only when user has not disabled that feature
    if(YES != [appPreferences boolForKey:PREF_NOUPDATES_MODE])
    {
        //after a 30 seconds
        // check for updates in background
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 30 * NSEC_PER_SEC), dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^
        {
            //dbg msg
            #ifdef DEBUG
            logMsg(LOG_DEBUG, @"checking for update");
            #endif
           
            //check
            [self check4Update];
            
        });
    }
    
    //init alert monitor
    alertMonitor = [[AlertMonitor alloc] init];
    
    //in background
    // ->monitor / process alerts
    [alertMonitor performSelectorInBackground:@selector(monitor) withObject:nil];
    
bail:
    
    return;
}


//is there an update?
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
// ->error, no update, update/new version
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
            #ifdef DEBUG
            logMsg(LOG_DEBUG, @"no updates available");
            #endif
            
            break;
            
            
        //new version
        case 1:
            
            //dbg msg
            #ifdef DEBUG
            logMsg(LOG_DEBUG, [NSString stringWithFormat:@"a new version (%@) is available", newVersion]);
            #endif
     
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
