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
    //dbg msg
    logMsg(LOG_DEBUG, [NSString stringWithFormat:@"starting config/rules/pref's main app (args: %@)", [[NSProcessInfo processInfo] arguments]]);
    
    //init crash reporting
    // kicks off sentry.io
    initCrashReporting();
    
    //app main
    return NSApplicationMain(argc, argv);
}
