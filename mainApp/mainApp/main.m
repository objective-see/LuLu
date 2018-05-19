//
//  file: main.m
//  project: lulu (main app)
//  description: main interface, toggle login item, or just kick off app interface
//
//  created by Patrick Wardle
//  copyright (c) 2017 Objective-See. All rights reserved.
//


@import Cocoa;

#import "consts.h"
#import "logging.h"
#import "utilities.h"

//main
// check if already running
// otherwise 'main' logic in app delegate
int main(int argc, const char * argv[])
{
    //return var
    int iReturn = -1;
    
    //init crash reporting
    // kicks off sentry.io
    initCrashReporting();
    
    //dbg msg
    logMsg(LOG_DEBUG, [NSString stringWithFormat:@"starting config/pref's app (args: %@)", [[NSProcessInfo processInfo] arguments]]);
    
    //already running?
    if(YES == isAppRunning([[NSBundle mainBundle] bundleIdentifier]))
    {
        //err msg
        logMsg(LOG_DEBUG, @"an instance of LuLu (main app) is already running...exiting");
        
        //bail
        goto bail;
    }
    
    //launch app normally
    iReturn = NSApplicationMain(argc, argv);
    
bail:
    
    return iReturn;
}
