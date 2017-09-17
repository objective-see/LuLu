//
//  file: main.m
//  project: lulu (main app)
//  description: main interface, toggle login item, or just kick off app interface
//
//  created by Patrick Wardle
//  copyright (c) 2017 Objective-See. All rights reserved.
//

@import Cocoa;
#import <ServiceManagement/ServiceManagement.h>

#import "const.h"
#import "logging.h"
#import "Utilities.h"

int main(int argc, const char * argv[])
{
    //return var
    int iReturn = -1;
    
    //when in/uninstalling
    // toggle login item (need to do from here, in main app)
    if(2 == argc)
    {
        //'-install' or '-uninstall'
        // toggle login item
        if( (0 == strcmp(argv[1], CMDLINE_FLAG_INSTALL.UTF8String)) ||
            (0 == strcmp(argv[1], CMDLINE_FLAG_UNINSTALL.UTF8String)) )
        {
            //toggle login item
            if(YES != SMLoginItemSetEnabled((__bridge CFStringRef)@"com.objective-see.luluHelper", !!strcmp(argv[1], CMDLINE_FLAG_UNINSTALL.UTF8String)))
            {
                //err msg
                logMsg(LOG_DEBUG, [NSString stringWithFormat:@"failed to toggle login item (%@)", [[NSBundle mainBundle] bundleIdentifier]]);
                
                //bail
                goto bail;
            }
            
            //happy
            iReturn = 0;
            
            //bail here
            // don't want to show UI or do anything else
            goto bail;
        }
    }
    
    //already running?
    if(YES == isAppRunning([[NSBundle mainBundle] bundleIdentifier]))
    {
        //err msg
        logMsg(LOG_DEBUG, @"an instance of LuLu (main app) is already running");
        
        //bail
        goto bail;
    }
    
    //launch app normally
    iReturn = NSApplicationMain(argc, argv);
    
bail:
    
    return iReturn;
}
