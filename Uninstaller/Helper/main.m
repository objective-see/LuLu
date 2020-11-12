//
//  file: Helper.m
//  project: (open-source) installer
//  description: main/entry point of daemon
//
//  created by Patrick Wardle
//  copyright (c) 2018 Objective-See. All rights reserved.
//

@import OSLog;
@import Foundation;

#import "consts.h"
#import "XPCProtocol.h"
#import "HelperListener.h"
#import "HelperInterface.h"

/* GLOBALS */

//log handle
os_log_t logHandle = nil;

//helper daemon entry point
// create XPC listener object and then just wait
int main(int argc, const char * argv[])
{
    //pragmas
    #pragma unused(argc)
    #pragma unused(argv)
    
    //status
    int status = -1;
    
    //init log
    logHandle = os_log_create(BUNDLE_ID, "configure-helper");
    
    //pool
    @autoreleasepool
    {
        //helper listener (XPC) obj
        HelperListener* helperListener = nil;
        
        //dbg msg(s)
        os_log_debug(logHandle, "started: %{public}@ (pid: %d / uid: %d)", NSProcessInfo.processInfo.arguments.firstObject, getpid(), getuid());
        os_log_debug(logHandle, "arguments: %{public}@", NSProcessInfo.processInfo.arguments);
        
        //alloc/init helper listener XPC obj
        helperListener = [[HelperListener alloc] init];
        if(nil == helperListener)
        {
            //err msg
            os_log_error(logHandle, "ERROR: failed to initialize helper XPC listener");
            
            //bail
            goto bail;
        }
        
        //dbg msg
        os_log_debug(logHandle, "listening for client XPC connections...");
    
        //run loop
        [[NSRunLoop currentRunLoop] run];
    
    } //pool
    
    //happy
    // though not sure how we'll ever get here?
    status = 0;

bail:
    
	return status;
}
