//
//  file: main.m
//  project: lulu (config app)
//  description: main interface, for config
//
//  created by Patrick Wardle
//  copyright (c) 2018 Objective-See. All rights reserved.
//

@import Cocoa;
@import OSLog;

#import "main.h"
#import "consts.h"
#import "utilities.h"
#import "Configure.h"

/* GLOBALS */

//log handle
os_log_t logHandle = nil;

//main interface
int main(int argc, char *argv[])
{
    //status
    int status = -1;
    
    //init log
    logHandle = os_log_create(BUNDLE_ID, "configure");
    
    //dbg msg(s)
    os_log_debug(logHandle, "started: %{public}@ (pid: %d / uid: %d)", NSProcessInfo.processInfo.arguments.firstObject, getpid(), getuid());
    os_log_debug(logHandle, "arguments: %{public}@", NSProcessInfo.processInfo.arguments);
    
    //disable re-launch
    // don't need macOS restarting us after the reboot
    [NSApplication.sharedApplication disableRelaunchOnLogin];
    
    //cmdline uninstall?
    if( (YES == [NSProcessInfo.processInfo.arguments containsObject:CMD_UPGRADE]) ||
        (YES == [NSProcessInfo.processInfo.arguments containsObject:CMD_UNINSTALL]) )
    {
        //dbg msg
        os_log_debug(logHandle, "performing commandline uninstall of LuLu v1.*");
        
        //install
        if(YES != cmdlineUninstall())
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

//cmdline uninstall
// removes v1.* installs
BOOL cmdlineUninstall()
{
    //flag
    BOOL uninstalled = NO;
    
    //action
    // default to uninstall
    NSInteger action = ACTION_UNINSTALL_FLAG;
    
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
    
    //set action
    if(YES == [NSProcessInfo.processInfo.arguments containsObject:CMD_UPGRADE])
    {
        //set
        action = ACTION_UPGRADE_FLAG;
        
        //dbg msg
        printf("LULU: performing 'uninstall' logic, for an upgrade\n");
        
    } else printf("LULU: performing full 'uninstall' logic\n");

    //configure
    uninstalled = [configure uninstall:action];
    if(YES != uninstalled)
    {
        //bail
        goto bail;
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
    uninstalled = YES;
    
bail:
    
    //cleanup
    if(nil != configure)
    {
        //cleanup
        [configure removeHelper];
    }
    
    return uninstalled;
}
