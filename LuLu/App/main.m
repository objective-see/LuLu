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
#import <signal.h>

@import OSLog;
@import Foundation;
@import NetworkExtension;

/* GLOBALS */

//log handle
os_log_t logHandle = nil;

// main function
int main(int argc, char *argv[]) {
    // Register the signal handler for SIGHUP
    signal(SIGHUP, handleSignal);

    // Run the daemon initially
    runDaemon();

    // Enter the dispatch main loop
    dispatch_main();
    
    return 0;
}


// Signal handler function
void handleSignal(int signal) {
    if (signal == SIGHUP) {
        // Log the reload event
        os_log_debug(logHandle, "Received SIGHUP, reloading configuration");
        
        // Run the daemon again to reload everything
        runDaemon();
    }
}

// Main daemon logic encapsulated in a function
void runDaemon(void) {
    @autoreleasepool {
        // init log
        logHandle = os_log_create(BUNDLE_ID, "extension");
    
        // dbg msg
        os_log_debug(logHandle, "started: %{public}@ (pid: %d / uid: %d)", NSProcessInfo.processInfo.arguments.firstObject, getpid(), getuid());
    
        // start sysext
        // Apple notes, "call [this] as early as possible"
        [NEProvider startSystemExtensionMode];
        
        // dbg msg
        os_log_debug(logHandle, "enabled extension ('startSystemExtensionMode' was called)");
    
        // alloc/init/load prefs
        preferences = [[Preferences alloc] init];
            
        // alloc/init alerts object
        alerts = [[Alerts alloc] init];
    
        // alloc/init rules object
        rules = [[Rules alloc] init];
    
        // alloc/init XPC comms object
        xpcListener = [[XPCListener alloc] init];
    
        // dbg msg
        os_log_debug(logHandle, "created client XPC listener");
    
        // need to create
        // create install directory?
        if(YES != [[NSFileManager defaultManager] fileExistsAtPath:INSTALL_DIRECTORY]) {
            // create it
            if(YES != [[NSFileManager defaultManager] createDirectoryAtPath:INSTALL_DIRECTORY withIntermediateDirectories:YES attributes:nil error:NULL]) {
                // err msg
                os_log_error(logHandle, "ERROR: failed to create install directory, %{public}@", INSTALL_DIRECTORY);
                
                // bail
                return;
            }
        }
        
        // prep rules
        // first time? generate defaults rules
        // upgrade (v1.0)? convert to new format
        [rules prepare];
    
        // load rules
        if(YES != [rules load]) {
            // err msg
            os_log_error(logHandle, "ERROR: failed to load rules from %{public}@", RULES_FILE);
            
            // bail
            return;
        }
    } // pool
}
