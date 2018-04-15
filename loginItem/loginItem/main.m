//
//  file: main.m
//  project: lulu (login item)
//  description: main; 'nuff said
//
//  created by Patrick Wardle
//  copyright (c) 2017 Objective-See. All rights reserved.
//

@import Cocoa;

#import "logging.h"
#import "exception.h"
#import "utilities.h"

//TODO: sentry.io

int main(int argc, const char * argv[])
{
    //return var
    int iReturn = -1;
    
    //install exception handlers
    installExceptionHandlers();
    
    //already running?
    if(YES == isAppRunning([[NSBundle mainBundle] bundleIdentifier]))
    {
        //err msg
        logMsg(LOG_DEBUG, @"an instance of LuLu (helper app) is already running...exiting");
        
        //bail
        goto bail;
    }
    
    //launch app normally
    iReturn = NSApplicationMain(argc, argv);
    
bail:
    
    return iReturn;
}

