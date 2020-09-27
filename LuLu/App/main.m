//
//  main.m
//  LuLu
//
//  Created by Patrick Wardle on 8/1/20.
//  Copyright (c) 2020 Objective-See. All rights reserved.
//

#import "consts.h"
#import "utilities.h"

@import Cocoa;
@import OSLog;

/* GLOBALS */

//log handle
os_log_t logHandle = nil;

int main(int argc, const char * argv[]) {
    
    //pool
    @autoreleasepool {
        
        //init log
        logHandle = os_log_create(BUNDLE_ID, "application");
        
        //dbg msg(s)
        os_log_debug(logHandle, "started: %{public}@ (pid: %d / uid: %d)", NSProcessInfo.processInfo.arguments.firstObject, getpid(), getuid());
        os_log_debug(logHandle, "arguments: %{public}@", NSProcessInfo.processInfo.arguments);
    
        //crash reporting
        initCrashReporting();
    }
    
    //main app interface
    return NSApplicationMain(argc, argv);
}
