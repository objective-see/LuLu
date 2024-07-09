//
//  Configure.m
//  LuLu
//
//  Created by Patrick Wardle on 2/6/24.
//  Copyright © 2024 Objective-See. All rights reserved.
//

#import "consts.h"
#import "utilities.h"

#import "Configure.h"
#import "Extension.h"
#import "XPCDaemonClient.h"

/* GLOBALS */

//log handle
extern os_log_t logHandle;

//xpc for daemon comms
extern XPCDaemonClient* xpcDaemonClient;

@implementation Configure

//init
-(id)init
{
    //init
    if(self = [super init])
    {
        //if needed, in extension comms
        if(nil == xpcDaemonClient)
        {
            //init
            xpcDaemonClient = [[XPCDaemonClient alloc] init];
        }
    }
    
    return self;
}

//install
-(BOOL)install
{
    //flag
    BOOL installed = NO;
    
    //error
    NSError* error = nil;
    
    //source
    NSString* source = nil;
    
    //destination
    NSString* destination = nil;
    
    //dbg msg
    os_log_debug(logHandle, "function '%s' invoked", __PRETTY_FUNCTION__);
    
    //quit LuLu
    [self quit];
    
    //init source
    source = NSBundle.mainBundle.bundlePath;
    
    //init destination
    destination = [@"/Applications" stringByAppendingPathComponent:APP_NAME];
    
    //remove any existing LuLu.app
    if(YES == [NSFileManager.defaultManager fileExistsAtPath:destination])
    {
        //not us?
        // remove
        if(YES != [source isEqualToString:destination])
        {
            //remove
            if(YES != [NSFileManager.defaultManager removeItemAtPath:destination error:&error])
            {
                //err msg
                os_log_error(logHandle, "ERROR: failed to remove %{public}@ (error: %{public}@)", destination, error);
                goto bail;
            }
        }
    }
    
    //copy self into /Applications
    if(YES != [NSFileManager.defaultManager copyItemAtPath:source toPath:destination error:&error])
    {
        //err msg
        os_log_error(logHandle, "ERROR: failed to move %{public}@ to %{public}@ (error: %{public}@)", source, destination, error);
        goto bail;
    }
    
    //dbg msg
    os_log_debug(logHandle, "moved self into /Applications and will launch...");
    
    //now launch
    if(nil == [NSWorkspace.sharedWorkspace launchApplicationAtURL:[NSURL fileURLWithPath:destination] options:0 configuration:@{} error:&error])
    {
        //err msg
        os_log_error(logHandle, "ERROR: failed to launch  %{public}@, (error: %{public}@)", destination, error);
        goto bail;
    }
    
    //happy
    installed = YES;
    
bail:
    
    return installed;
    
}

//upgrade
// same as install
-(BOOL)upgrade
{
    //dbg msg
    os_log_debug(logHandle, "function '%s' invoked", __PRETTY_FUNCTION__);
    
    return [self install];
}

//unistall
-(BOOL)uninstall
{
    //flag
    BOOL errors = NO;
    
    //error
    NSError* error = nil;
    
    //app
    NSString* app = [@"/Applications" stringByAppendingPathComponent:APP_NAME];
    
    //dbg msg
    os_log_debug(logHandle, "function '%s' invoked", __PRETTY_FUNCTION__);
    
    //tell ext. to uninstall
    // remove rules, etc, etc
    if(YES != [xpcDaemonClient uninstall])
    {
        //err msg
        os_log_error(logHandle, "ERROR: daemon's XPC uninstall logic");
        
        //set flag
        errors = YES;
        
        //but continue onwards
    }
    
    //first, remove login item
    toggleLoginItem([NSURL fileURLWithPath:app], ACTION_UNINSTALL_FLAG);

    //quit (other) LuLu
    [self quit];
    
    //app found in /Apps?
    if(YES == [NSFileManager.defaultManager fileExistsAtPath:app])
    {
        //remove
        if(YES != [NSFileManager.defaultManager removeItemAtPath:app error:&error])
        {
            //set flag
            errors = YES;
            
            //err msg
            os_log_error(logHandle, "ERROR: failed to remove %{public}@ (error: %{public}@)", app, error);
            
            //but continue onwards
            
        } 
        //dbg msg
        else
        {
            os_log_debug(logHandle, "removed %{public}@", app);
        }
    }
    
    //dbg msg
    os_log_debug(logHandle, "uninstalling completed (with any errors? %d)", errors);
    
    return !errors;
}

//quit
// and optionally uninstall
-(void)quit
{
    //extension
    Extension* extension = nil;
    
    //source
    NSString* source = nil;
    
    //copy in /Apps
    NSString* copy = nil;
    
    //running copy
    NSRunningApplication* runningCopy = nil;
    
    //error
    NSError* error = nil;

    //flag
    __block BOOL deactivated = NO;
    
    //wait semaphore
    dispatch_semaphore_t semaphore = 0;
    
    //dbg msg
    os_log_debug(logHandle, "function '%s' invoked", __PRETTY_FUNCTION__);
    
    //init extension object
    extension = [[Extension alloc] init];
    
    //init source
    source = NSBundle.mainBundle.bundlePath;
    
    //init copy
    copy = [@"/Applications" stringByAppendingPathComponent:APP_NAME];
    
    //end LuLu
    // besides this running instance
    for(NSDictionary* lulu in findProcesses(@"LuLu"))
    {
        //pid
        NSNumber* pid = 0;
        
        //extract pid
        pid = lulu[KEY_PROCESS_ID];
        
        //skip self
        if(pid.intValue == getpid())
        {
            //skip
            continue;
        }
        
        //dbg msg
        os_log_debug(logHandle, "terminating %{public}@", lulu);
        
        //kill
        kill(pid.intValue, SIGKILL);
    }
    
    //terminate NQ
    [self terminateNetworkMonitor];

    //need to stop extension?
    if(YES == [extension isExtensionRunning])
    {
        //dbg msg
        os_log_debug(logHandle, "extension running, will deactivate...");
        
        //have to be running from /Applications for this to work
        // so if we're not there, spawn a copy to exectute this logic
        if(YES != [source isEqualToString:copy])
        {
            //dbg msg
            os_log_debug(logHandle, "will spawn copy from /Applications");
            
            //any existing?
            if(YES == [NSFileManager.defaultManager fileExistsAtPath:copy])
            {
                //remove
                if(YES != [NSFileManager.defaultManager removeItemAtPath:copy error:&error])
                {
                    //err msg
                    os_log_error(logHandle, "ERROR: failed to remove %{public}@ (error: %{public}@)", copy, error);
                    goto bail;
                }
            }
            
            //copy self into /Applications
            if(YES != [NSFileManager.defaultManager copyItemAtPath:source toPath:copy error:&error])
            {
                //err msg
                os_log_error(logHandle, "ERROR: failed to move %{public}@ to %{public}@ (error: %{public}@)", source, copy, error);
                goto bail;
            }
            
            //dbg msg
            os_log_debug(logHandle, "launching copy %{public}@, to deactivate extension", copy);
            
            //launch copy
            runningCopy = [NSWorkspace.sharedWorkspace launchApplicationAtURL:[NSURL fileURLWithPath:copy] options:0 configuration:[NSDictionary dictionaryWithObject:@[@"-quit"] forKey:NSWorkspaceLaunchConfigurationArguments] error:&error];
            if(nil == runningCopy)
            {
                //err msg
                os_log_error(logHandle, "ERROR: failed to launch copy, %{public}@, (error: %{public}@)", copy, error);
                goto bail;
            }
            
            //wait till copy exits
            while(YES != runningCopy.isTerminated)
            {
                [NSThread sleepForTimeInterval:0.1];
            }
            
            //dbg msg
            os_log_debug(logHandle, "copy terminated, will delete");
            
            //delete copy
            if(YES != [NSFileManager.defaultManager removeItemAtPath:copy error:&error])
            {
                //err msg
                os_log_error(logHandle, "ERROR: failed to remove %{public}@ (error: %{public}@)", copy, error);
                goto bail;
                
            } 
            
            //dbg msg
            os_log_debug(logHandle, "removed copy %{public}@", copy);
        }
        
        //(now) running from /Apps
        // go ahead and remove extension
        else
        {
            //init wait semaphore
            semaphore = dispatch_semaphore_create(0);
            
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
                
                //dbg msg
                os_log_debug(logHandle, "waiting system extension deactivation...");
                
                //wait for extension semaphore
                dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);
                
                //dbg msg
                os_log_debug(logHandle, "extension event triggered");
                
                //deactivated?
                if(YES == deactivated) break;
            }
        }
    }
    
bail:
    
    return;
}

//terminate network monitor
// unless its the non-LuLu version
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

@end

