//
//  file: Helper.m
//  project: (open-source) installer
//  description: main/entry point of daemon
//
//  created by Patrick Wardle
//  copyright (c) 2018 Objective-See. All rights reserved.
//

@import Foundation;

#include <syslog.h>

#import "logging.h"
#import "XPCProtocol.h"
#import "HelperListener.h"
#import "HelperInterface.h"

//helper daemon entry point
// create XPC listener object and then just wait
int main(int argc, const char * argv[])
{
    //pragmas
    #pragma unused(argc)
    #pragma unused(argv)
    
    //status
    int status = -1;
    
    //pool
    @autoreleasepool
    {
        //helper listener (XPC) obj
        HelperListener* helperListener = nil;
        
        //alloc/init helper listener XPC obj
        helperListener = [[HelperListener alloc] init];
        if(nil == helperListener)
        {
            //err msg
            logMsg(LOG_ERR, @"failed to initialize user comms XPC listener");
            
            //bail
            goto bail;
        }
        
        //dbg msg
        logMsg(LOG_DEBUG, @"listening for client XPC connections...");
    
        //run loop
        [[NSRunLoop currentRunLoop] run];
    
    } //pool
    
    //happy
    // though not sure how we'll ever get here?
    status = 0;

bail:
    
	return status;
}
