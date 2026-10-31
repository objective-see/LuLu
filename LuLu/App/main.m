//
//  main.m
//  LuLu
//
//  Created by Patrick Wardle on 8/1/20.
//  Copyright (c) 2020 Objective-See. All rights reserved.
//

#import "consts.h"
#import "utilities.h"
#import "Configure.h"

@import Cocoa;
@import OSLog;

//TODO:
// new pref: allow apple programs, unless has args + parent is untrusted
// add rule option: args

/* GLOBALS */

//log handle
os_log_t logHandle = nil;

//is cmdline action?
// install/upgrade/uninstall/quit
static BOOL isCmdlineAction(void)
{
    //args
    NSArray* arguments = NSProcessInfo.processInfo.arguments;
    
    return ( (YES == [arguments containsObject:@"-install"]) ||
             (YES == [arguments containsObject:@"-upgrade"]) ||
             (YES == [arguments containsObject:@"-uninstall"]) ||
             (YES == [arguments containsObject:@"-quit"]) );
}

//cmdline interface - for install/upgrade/uninstall/quit
// returns exit status (0: ok, -1: error)
static int cmdlineAction(void)
{
    //status
    int status = -1;
    
    //config obj
    Configure* configure = nil;
    
    
    //install?
    if(YES == [NSProcessInfo.processInfo.arguments containsObject:@"-install"])
    {
        //first check root
        if(0 != geteuid())
        {
            //err msg
            printf("\nLULU ERROR: cmdline interface actions require root\n\n");
            goto bail;
        }
        
        //init
        configure = [[Configure alloc] init];
        
        //dbg msg
        os_log_debug(logHandle, "performing cmdline install");
        
        //install
        if(YES != [configure install])
        {
            //error
            printf("\nLULU ERROR: install failed (see system log for details)\n\n");
            goto bail;
        }
        
        //dbg msg
        printf("\nLULU: installed\n\n");

        //happy
        status = 0;
        
        //done
        goto bail;
    }
    
    //upgrade?
    else if(YES == [NSProcessInfo.processInfo.arguments containsObject:@"-upgrade"])
    {
        //first check root
        if(0 != geteuid())
        {
            //err msg
            printf("\nLULU ERROR: cmdline interface actions require root\n\n");
            goto bail;
        }
        
        //init
        configure = [[Configure alloc] init];
        
        //dbg msg
        os_log_debug(logHandle, "performing cmdline upgrade");
        
        //upgrade
        if(YES != [configure upgrade])
        {
            //error
            printf("\nLULU ERROR: upgrade failed (see system log for details)\n\n");
            goto bail;
        }
        
        //dbg msg
        printf("\nLULU: upgraded\n\n");

        //happy
        status = 0;
        
        //done
        goto bail;
    }
    
    //uninstall?
    if(YES == [NSProcessInfo.processInfo.arguments containsObject:@"-uninstall"])
    {
        //first check root
        if(0 != geteuid())
        {
            //err msg
            printf("\nLULU ERROR: cmdline interface actions require root\n\n");
            goto bail;
        }
        
        //init
        configure = [[Configure alloc] init];
        
        //dbg msg
        os_log_debug(logHandle, "performing cmdline uninstall");
        
        //uninstall
        if(YES != [configure uninstall])
        {
            //error
            printf("\nLULU ERROR: uninstall failed (see system log for details)\n\n");
            goto bail;
        }
        
        //dbg msg
        printf("\nLULU: uninstalled\n\n");

        //happy
        status = 0;
        
        //done
        goto bail;
    }
    
    //quit?
    // this is the copy, to (just) deactivate extension
    if(YES == [NSProcessInfo.processInfo.arguments containsObject:@"-quit"])
    {
        //init
        configure = [[Configure alloc] init];

        //dbg msg
        os_log_debug(logHandle, "performing cmdline quit");

        //quit
        // this copy exists solely to deactivate the system extension
        [configure quit:YES];

        //happy
        status = 0;
        
        //done
        goto bail;
    }
    
    
bail:
    
    return status;
}

int main(int argc, const char * argv[]) {
    
    //status
    int status = -1;
    
    //pool
    @autoreleasepool {
        
        //init log
        logHandle = os_log_create(BUNDLE_ID, "application");
        
        //dbg msg(s)
        os_log_debug(logHandle, "started: %{public}@ (pid: %d / uid: %d)", NSProcessInfo.processInfo.arguments.firstObject, getpid(), getuid());
        os_log_debug(logHandle, "arguments: %{public}@", NSProcessInfo.processInfo.arguments);
    
        /* cmdline interface - for install/upgrade/uninstall/quit */
        // note: run off the main thread, w/ the main run loop kept alive, as the network extension framework
        //       delivers its completion handlers on the main queue ...so (synchronously) waiting on main deadlocks (see #915)
        if(YES == isCmdlineAction())
        {
            //run action (on background queue)
            // ...then exit w/ its status
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                
                //run & exit
                exit(cmdlineAction());
            });
            
            //keep main run loop alive
            // never returns, as action exits
            CFRunLoopRun();
        }
        
        //invalid args
        // just print msg, for cmdline case
        else if(NSProcessInfo.processInfo.arguments.count > 1)
        {
            //err msg
            printf("\nLULU ERROR: %s are not valid args\n\n", NSProcessInfo.processInfo.arguments.description.UTF8String);
        }
    
        //main app interface
        status = NSApplicationMain(argc, argv);
        
    } //pool
    
    return status;
}
