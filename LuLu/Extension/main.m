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
    
    //crash reporting
    initCrashReporting();
    
    //alloc/init/load prefs
    preferences = [[Preferences alloc] init];
    
    //alloc/init alerts object
    alerts = [[Alerts alloc] init];
    
    //alloc/init rules object
    rules = [[Rules alloc] init];
    
    //alloc/init XPC comms object
    xpcListener = [[XPCListener alloc] init];
    
    //dbg msg
    os_log_debug(logHandle, "created client XPC listener");
    
    //need to create
    //create install directory?
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
    if(YES != [rules load])
    {
        //err msg
        os_log_error(logHandle, "ERROR: failed to load rules from %{public}@", RULES_FILE);
        
        //bail
        goto bail;
    }
    
    //no prefs w/ install time
    // means user is still clicking thru welcome, so wait for that
    if(nil == preferences.preferences[PREF_INSTALL_TIMESTAMP])
    {
        //dbg msg
        os_log_debug(logHandle, "waiting for preferences...");
        
        //wait
        while(nil == preferences.preferences[PREF_INSTALL_TIMESTAMP]) [NSThread sleepForTimeInterval:0.25];
    }
    
    //dbg msg
    os_log_debug(logHandle, "(current) preferences: %{public}@", preferences.preferences);

    //prefs say, 'enabled'?
    if(YES != [preferences.preferences[PREF_IS_DISABLED] boolValue])
    {
        //start sysext
        [NEProvider startSystemExtensionMode];
        
        //dbg msg
        os_log_debug(logHandle, "enabled extension");
    }
    //user (prev) disabled firewall
    // just log this fact, and don't start it
    else
    {
        //dbg msg
        os_log_debug(logHandle, "user has disabled firewall, so, not enabling extension");
    }

    }//pool
    
    dispatch_main();
               
bail:
    
    return 0;
}
