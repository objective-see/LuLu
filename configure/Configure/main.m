//
//  file: main.m
//  project: lulu (config app)
//  description: main interface, for config
//
//  created by Patrick Wardle
//  copyright (c) 2018 Objective-See. All rights reserved.
//

//TODO: 10.11 crash!

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
    
    //autolaunched?
    // just exit, as otherwise it's confusing to launch (again)
    if(YES == autoLaunched())
    {
        //dbg msg
        logMsg(LOG_DEBUG, @"exiting, as it looks like we're autolaunched");
        
        //bail
        goto bail;
    }
    
    //default run mode
    // just kick off main app logic
    status = NSApplicationMain(argc,  (const char **) argv);
    
bail:
    
    return status;
}

//since install triggers a reboot
// macOS might automatically launch installer again on login
BOOL autoLaunched()
{
    //flag
    BOOL wasAutoLaunched = NO;
    
    //last arg
    NSString* finalArgument = nil;
      
    //finder.app's pid
    pid_t finderPID = 0;
    
    //(app) start time
    NSDate *startTime = nil;
   
    //finder's start time
    NSDate* finderStartTime;
    
    //get last arg
    finalArgument = [[[NSProcessInfo processInfo] arguments] lastObject];
    
    //when auto started
    // last arg will be `-psn ...`
    if(YES != [finalArgument hasPrefix:@"-psn"])
    {
        //not autostarted
        goto bail;
    }
    
    //get app's start time
    startTime = [NSDate dateWithTimeIntervalSinceNow:-(clock()/CLOCKS_PER_SEC)];
    
    //get finder.app's pid
    finderPID = [[getProcessIDs(FINDER_APP, (int)getuid()) firstObject] intValue];
    if(0 == finderPID)
    {
        //bail
        goto bail;
    }
    
    //get finder.app's start time
    finderStartTime = getProcessStartTime(finderPID);
    if(nil == finderStartTime)
    {
        //bail
        goto bail;
    }
    
    //compare
    // finder launch time / app launch < 2 seconds?
    if(fabs([startTime timeIntervalSinceDate:finderStartTime]) < 2.0f)
    {
        //auto launched
        wasAutoLaunched = YES;
    }
    
bail:
    
    return wasAutoLaunched;
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
