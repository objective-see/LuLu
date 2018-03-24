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

#import "consts.h"
#import "logging.h"
#import "utilities.h"
#import "exception.h"

int main(int argc, const char * argv[])
{
    //return var
    int iReturn = -1;
    
    //path to login item
    NSString* loginItem = nil;
    
    //TODO: use sentry.io?
    //first thing...
    // install exception handlers
    installExceptionHandlers();
    
    //dbg msg
    logMsg(LOG_DEBUG, [NSString stringWithFormat:@"starting config/pref's app (args: %@)", [[NSProcessInfo processInfo] arguments]]);
    
    //init path to login item app
    loginItem = [[[NSBundle mainBundle] bundlePath] stringByAppendingPathComponent:[NSString stringWithFormat:@"/Contents/Library/LoginItems/%@.app", LOGIN_ITEM_NAME]];
    
    //install
    // enable login item
    if(YES == [[[NSProcessInfo processInfo] arguments] containsObject:CMDLINE_FLAG_INSTALL])
    {
        //enable
        if(YES != toggleLoginItem([NSURL fileURLWithPath:loginItem], ACTION_INSTALL_FLAG))
        {
            //err msg
            logMsg(LOG_ERR, [NSString stringWithFormat:@"failed to enable login item (%@)", loginItem]);
            
            //bail
            goto bail;
        }
        
        //dbg msg
        logMsg(LOG_DEBUG, [NSString stringWithFormat:@"enabled login item (%@)", loginItem]);
        
        //not showing 'welcome' screen(s)?
        // bail here so UI, etc isn't shown to user
        if(YES != [[[NSProcessInfo processInfo] arguments] containsObject:CMDLINE_FLAG_WELCOME])
        {
            //happy
            iReturn = 0;
            
            //bail
            goto bail;
        }
    }
    
    //uninstall
    // disable login item and bail
    else if(YES == [[[NSProcessInfo processInfo] arguments] containsObject:CMDLINE_FLAG_UNINSTALL])
    {
        //disable
        if(YES != toggleLoginItem([NSURL fileURLWithPath:loginItem], ACTION_UNINSTALL_FLAG))
        {
            //err msg
            logMsg(LOG_ERR, [NSString stringWithFormat:@"failed to disable login item (%@)", loginItem]);
            
            //bail
            goto bail;
        }
        
        //happy
        iReturn = 0;
        
        //dbg msg
        logMsg(LOG_DEBUG, [NSString stringWithFormat:@"disabled login item (%@)", [[NSBundle mainBundle] bundleIdentifier]]);
        
        //don't want to show UI or do anything else, so bail
        goto bail;
    }
    
    //already running?
    if(YES == isAppRunning([[NSBundle mainBundle] bundleIdentifier]))
    {
        //dbg msg
        logMsg(LOG_DEBUG, @"an instance of DND (main app) is already running");
        
        //bail
        goto bail;
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
