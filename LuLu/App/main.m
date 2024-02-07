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


/* GLOBALS */

//log handle
os_log_t logHandle = nil;

int main(int argc, const char * argv[]) {
    
    //status
    int status = -1;
    
    //config obj
    Configure* configure = nil;
    
    //pool
    @autoreleasepool {
        
        //init log
        logHandle = os_log_create(BUNDLE_ID, "application");
        
        //dbg msg(s)
        os_log_debug(logHandle, "started: %{public}@ (pid: %d / uid: %d)", NSProcessInfo.processInfo.arguments.firstObject, getpid(), getuid());
        os_log_debug(logHandle, "arguments: %{public}@", NSProcessInfo.processInfo.arguments);
    
        /* cmdline interface - for install/upgrade/uninstall */
        
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
            [configure quit];
            
            //done
            goto bail;
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
    
bail:
    
    return status;
}
