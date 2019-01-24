//
//  file: main.m
//  project: lulu (login item)
//  description: main; 'nuff said
//
//  created by Patrick Wardle
//  copyright (c) 2017 Objective-See. All rights reserved.
//

@import Cocoa;

#import "consts.h"
#import "logging.h"
#import "utilities.h"

int main(int argc, const char * argv[])
{
    //dbg msg
    logMsg(LOG_DEBUG, @"starting helper (login item)");
    
    //init crash reporting
    // kicks off sentry.io
    initCrashReporting();
    
    //launch app normally
    return NSApplicationMain(argc, argv);
}
