//
//  file: main.m
//  project: lulu (config app)
//  description: main interface, for config
//
//  created by Patrick Wardle
//  copyright (c) 2018 Objective-See. All rights reserved.
//

@import Cocoa;
@import Sentry;

#import "main.h"
#import "consts.h"
#import "logging.h"
#import "utilities.h"
#import "Configure.h"

//main interface
int main(int argc, char *argv[])
{
    //status
    int status = -1;
    
    //init crash reporting
    initCrashReporting();
    
    //cmdline install?
    if(YES == [[[NSProcessInfo processInfo] arguments] containsObject:CMD_INSTALL])
    {
        //dbg msg
        logMsg(LOG_DEBUG, @"performing commandline install");
        
        //install
        if(YES != cmdlineInterface(ACTION_INSTALL_FLAG))
        {
            //err msg
            printf("\nLULU ERROR: install failed\n\n");
            
            //bail
            goto bail;
        }
        
        //dbg msg
        printf("LULU: install ok!\n...reboot to complete\n\n");
        
        //happy
        status = 0;
        
        //done
        goto bail;
    }
    
    //cmdline uninstall?
    else if(YES == [[[NSProcessInfo processInfo] arguments] containsObject:CMD_UNINSTALL])
    {
        //dbg msg
        logMsg(LOG_DEBUG, @"performing commandline uninstall");
        
        //install
        if(YES != cmdlineInterface(ACTION_UNINSTALL_FLAG))
        {
            //err msg
            printf("\nLULU ERROR: uninstall failed\n\n");
            
            //bail
            goto bail;
        }
        
        //dbg msg
        printf("LULU: uninstall ok!\n...reboot to complete\n\n");
        
        //happy
        status = 0;
        
        //done
        goto bail;
    }
    
    //default run mode
    // just kick off main app logic
    status = NSApplicationMain(argc,  (const char **) argv);
    
bail:
    
    return status;
}

//cmdline interface
// install or uninstall
BOOL cmdlineInterface(int action)
{
    //flag
    BOOL wasConfigured = NO;
    
    //configure obj
    Configure* configure = nil;
    
    //ignore SIGPIPE
    signal(SIGPIPE, SIG_IGN);
    
    //alloc/init
    configure = [[Configure alloc] init];
    
    //first check root
    if(0 != geteuid())
    {
        //err msg
        printf("\nLULU ERROR: cmdline interface actions require root!\n\n");
        
        //bail
        goto bail;
    }
    
    //configure
    wasConfigured = [configure configure:action];
    if(YES != wasConfigured)
    {
        //bail
        goto bail;
    }
    
    //for install, wait for 'system_profiler'
    // note: this is only exec'd on fresh install
    if( (ACTION_INSTALL_FLAG == action) &&
        (0 != [getProcessIDs(SYSTEM_PROFILER, -1) count]) )
    {
        //dbg msg
        printf("LULU: waiting for 'system_profiler' to complete\n");

        //wait for 'system_profiler'
        while(YES)
        {
            //nap
            [NSThread sleepForTimeInterval:1.0];
            
            //exit'd?
            if(0 == [getProcessIDs(SYSTEM_PROFILER, -1) count])
            {
                //bye
                break;
            }
        }
    }
    
    //dbg msg
    printf("LULU: waiting for 'kextcache' to complete\n");
    
    //wait for 'kextcache'
    while(YES)
    {
        //nap
        [NSThread sleepForTimeInterval:1.0];
        
        //exit'd?
        if(0 == [getProcessIDs(KEXT_CACHE, -1) count])
        {
            //bye
            break;
        }
    }
    
    //happy
    wasConfigured = YES;
    
bail:
    
    //cleanup
    if(nil != configure)
    {
        //cleanup
        [configure removeHelper];
    }
    
    return wasConfigured;
}
