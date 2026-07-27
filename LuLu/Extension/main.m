//
//  main.m
//  Extension
//
//  Created by Patrick Wardle on 8/1/20.
//  Copyright (c) 2020 Objective-See. All rights reserved.
//

//FOR LOGGING:
// % log stream --level debug --predicate="subsystem='com.objective-see.lulu'"

#import "main.h"

@import OSLog;
@import Foundation;
@import NetworkExtension;

/* GLOBALS */

//log handle
os_log_t logHandle = nil;

//main
int main(int argc, char *argv[])
{
    //pool
    @autoreleasepool {
    
    //init log
    logHandle = os_log_create(BUNDLE_ID, "extension");
    
    //dbg msg
    os_log_debug(logHandle, "started: %{public}@ (pid: %d / uid: %d)", NSProcessInfo.processInfo.arguments.firstObject, getpid(), getuid());
    
    //start sysext
    // Apple notes, "call [this] as early as possible"
    [NEProvider startSystemExtensionMode];
        
    //dbg msg
    os_log_debug(logHandle, "enabled extension ('startSystemExtensionMode' was called)");
    
    //alloc/init/load prefs
    preferences = [[Preferences alloc] init];
            
    //alloc/init alerts object
    alerts = [[Alerts alloc] init];
    
    //alloc/init rules object
    rules = [[Rules alloc] init];
    
    //alloc/init profiles object
    profiles = [[Profiles alloc] init];
        
    //alloc/init XPC comms object
    xpcListener = [[XPCListener alloc] init];
        
    //dbg msg
    os_log_debug(logHandle, "created client XPC listener");
    
    //need to create
    // create install directory?
    if(YES != [[NSFileManager defaultManager] fileExistsAtPath:INSTALL_DIRECTORY])
    {
        //create it
        if(YES != [[NSFileManager defaultManager] createDirectoryAtPath:INSTALL_DIRECTORY withIntermediateDirectories:YES attributes:nil error:NULL])
        {
            //err msg
            os_log_error(logHandle, "ERROR: failed to create install directory, %{public}@", INSTALL_DIRECTORY);
            
            //bail
            goto bail;
        }
    }
        
    //prep rules
    // first time? generate defaults rules
    // upgrade (v1.0)? convert to new format
    [rules prepare];
    
    //load rules
    // if this fails, bail so we don't mask the issue or overwrite the user's rules
    if(YES != [rules load])
    {
        //err msg
        os_log_error(logHandle, "ERROR: failed to load rules from %{public}@ ...will exit", RULES_FILE);
        
        //bail
        goto bail;
    }
    
    //allow list?
    if(YES == [preferences.preferences[PREF_USE_ALLOW_LIST] boolValue])
    {
        //dbg msg
        os_log_debug(logHandle, "init'ing allow list");

        //path
        NSString* allowListPath = preferences.preferences[PREF_ALLOW_LIST];

        //load in the background, retrying until it succeeds
        // a remote list can fail to load at boot (network not up yet); don't block startup on it
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{

            //alloc/init
            allowList = [[BlockOrAllowList alloc] init:allowListPath];

            //loaded?
            BOOL loaded = NO;

            //(re)try the load (up to 10x), napping between attempts
            for(NSUInteger attempt = 1; attempt <= 10; attempt++)
            {
                //loaded? done
                if(YES == [allowList load:allowListPath])
                {
                    loaded = YES;
                    break;
                }

                //err msg
                os_log_error(logHandle, "allow list load failed (attempt %lu) ...will retry", (unsigned long)attempt);

                //nap, then retry
                if(attempt < 10) {
                    [NSThread sleepForTimeInterval:3.0f];
                }
            }

            //final outcome
            if(YES == loaded) {
                os_log_debug(logHandle, "allow list loaded (%lu items)", (unsigned long)allowList.items.count);
            } else {
                os_log_error(logHandle, "ERROR: gave up loading allow list after 10 attempts");
            }
        });
    }

    //block list?
    if(YES == [preferences.preferences[PREF_USE_BLOCK_LIST] boolValue])
    {
        //dbg msg
        os_log_debug(logHandle, "init'ing block list");

        //path
        NSString* blockListPath = preferences.preferences[PREF_BLOCK_LIST];

        //load in the background, retrying until it succeeds
        // a remote list can fail to load at boot (network not up yet); don't block startup on it
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{

            //alloc/init
            blockList = [[BlockOrAllowList alloc] init:blockListPath];

            //loaded?
            BOOL loaded = NO;

            //(re)try the load (up to 10x), napping between attempts
            for(NSUInteger attempt = 1; attempt <= 10; attempt++)
            {
                //loaded? done
                if(YES == [blockList load:blockListPath])
                {
                    loaded = YES;
                    break;
                }

                //err msg
                os_log_error(logHandle, "block list load failed (attempt %lu) ...will retry", (unsigned long)attempt);

                //nap, then retry
                if(attempt < 10) {
                    [NSThread sleepForTimeInterval:3.0f];
                }
            }

            //final outcome
            if(YES == loaded) {
                os_log_debug(logHandle, "block list loaded (%lu items)", (unsigned long)blockList.items.count);
            } else {
                os_log_error(logHandle, "ERROR: gave up loading block list after 10 attempts");
            }
        });
    }
    
    }//pool
    
    dispatch_main();
               
bail:
    
    return 0;
}
