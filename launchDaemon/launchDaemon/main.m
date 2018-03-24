//
//  file: main.m
//  project: lulu (launch daemon)
//  description: main interface/entry point for launch daemon
//
//  created by Patrick Wardle
//  copyright (c) 2017 Objective-See. All rights reserved.
//

#import "Rules.h"
#import "Queue.h"
#import "consts.h"
#import "logging.h"
#import "Baseline.h"
#import "KextComms.h"
#import "utilities.h"
#import "exception.h"
#import "Preferences.h"
#import "KextListener.h"
#import "ProcListener.h"
#import "UserCommsListener.h"

//GLOBALS

//prefs obj
Preferences* preferences = nil;

//kext comms obj
KextComms* kextComms = nil;

//rules obj
Rules* rules = nil;

//queue object
// ->contains watch items that should be processed
Queue* eventQueue = nil;

//process listener obj
ProcessListener* processListener = nil;

//kext listener obj
KextListener* kextListener = nil;

//(a) client status
NSInteger clientConnected;

//'rule changed' semaphore
dispatch_semaphore_t rulesChanged = 0;

//dispatch source for SIGTERM
dispatch_source_t dispatchSource = nil;

/* FUNCTIONS */

//init a handler for SIGTERM
// can perform actions such as disabling firewall and closing logging
void register4Shutdown(void);

//launch daemon should only be unloaded if box is shutting down
// so handle things like telling kext to disable & unregister, de-init logging, etc
void goodbye(void);

//main
// init & kickoff stuffz
int main(int argc, const char * argv[])
{
    @autoreleasepool
    {
        //baseline object
        Baseline* baseline = nil;
        
        //user comms listener (XPC) obj
        UserCommsListener* userCommsListener = nil;
        
        //high sierra version struct
        NSOperatingSystemVersion highSierra = {10,13,0};
        
        //dbg msg
        logMsg(LOG_DEBUG, @"LuLu launch daemon started");
        
        //install exception handlers
        installExceptionHandlers();
        
        //init logging
        if(YES != initLogging(logFilePath()))
        {
            //err msg
            logMsg(LOG_ERR, @"failed to init logging");
            
            //bail
            goto bail;
        }
        
        //alloc/init/load prefs
        preferences = [[Preferences alloc] init];
        if(nil == preferences)
        {
            //err msg
            logMsg(LOG_ERR, @"failed to initialize preferences");
            
            //bail
            goto bail;
        }
        
        //enumerate installed 3rd-party apps?
        // once need to do once, hence the file check...
        if(YES != [[NSFileManager defaultManager] fileExistsAtPath:[INSTALL_DIRECTORY stringByAppendingPathComponent:INSTALLED_APPS]])
        {
            //dbg msg
            logMsg(LOG_DEBUG, [NSString stringWithFormat:@"%@ not found, so kicking off baselining", INSTALLED_APPS]);
            
            //init
            baseline = [[Baseline alloc] init];
            
            //baselining
            // this can be slow, so do in background
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0),^
            {
               //baseline
               [baseline baseline];
            });
        }
        
        //alloc/init kernel comms object
        kextComms = [[KextComms alloc] init];
        
        //alloc/init process listener obj
        processListener = [[ProcessListener alloc] init];
        
        //register for shutdown
        // so, can disable firewall and close logging
        register4Shutdown();
        
        //dbg msg
        logMsg(LOG_DEBUG, @"registered for shutdown events");
        
        //start listening for process events
        [processListener monitor];
        
        //dbg msg
        logMsg(LOG_DEBUG, @"listening for process events");
        
        //init global queue
        eventQueue = [[Queue alloc] init];

        //dbg msg
        logMsg(LOG_DEBUG, @"initialized global queue");
        
        //alloc/init rules object
        rules = [[Rules alloc] init];
        
        //load rules
        if(YES != [rules load])
        {
            //err msg
            logMsg(LOG_ERR, [NSString stringWithFormat:@"failed to load rules from %@", RULES_FILE]);
            
            //bail
            goto bail;
        }
        
        //dbg msg
        logMsg(LOG_DEBUG, [NSString stringWithFormat:@"loaded rules from %@", RULES_FILE]);
    
        //init rule changed semaphore
        rulesChanged = dispatch_semaphore_create(0);
        
        //alloc/init user comms XPC obj
        userCommsListener = [[UserCommsListener alloc] init];
        if(nil == userCommsListener)
        {
            //err msg
            logMsg(LOG_ERR, @"failed to initialize user comms XPC listener");
            
            //bail
            goto bail;
        }
        
        //dbg msg
        logMsg(LOG_DEBUG, @"listening for client XPC connections");
        
        //10.13+ and kext not yet loaded?
        // likely 1st time, and have to wait for user to allow
        if( (YES == [[NSProcessInfo processInfo] isOperatingSystemAtLeastVersion:highSierra]) &&
            (YES != kextIsLoaded([NSString stringWithUTF8String:LULU_SERVICE_NAME])) )
        {
            //dbg msg
            logMsg(LOG_DEBUG, @"waiting for kext to load (high sierra)");
            
            //wait
            wait4kext([NSString stringWithUTF8String:LULU_SERVICE_NAME]);
        }
 
        //connect to kext
        if(YES != [kextComms connect])
        {
            //err msg
            logMsg(LOG_ERR, [NSString stringWithFormat:@"failed to connect to kext, %s", LULU_SERVICE_NAME]);
                
            //bail
            goto bail;
        }
        
        //dbg msg
        logMsg(LOG_DEBUG, [NSString stringWithFormat:@"connected to kext, %s", LULU_SERVICE_NAME]);
        
        //enable
        [kextComms enable];
        
        //dbg msg
        logMsg(LOG_DEBUG, @"enabled firewall");
        
        //alloc/init kernel listener obj
        kextListener = [[KextListener alloc] init];
        
        //start listening for events
        [kextListener monitor];
        
        //dbg msg
        logMsg(LOG_DEBUG, @"listening for kernel events");
        
        //now kext is loaded
        // finally add all rules to kernel
        @synchronized(rules.rules)
        {
            //iterate & add all
            for(NSString* path in rules.rules)
            {
                //add
                [rules addToKernel:rules.rules[path]];
            }
        }
        
        //dbg msg
        logMsg(LOG_DEBUG, @"added all rules, now run-loop'ing");

        //run loop
        [[NSRunLoop currentRunLoop] run];
    }
    
bail:
    
    //dbg msg
    logMsg(LOG_DEBUG, @"LuLu launch daemon exiting");
    
    //bye!
    // tell kext to disable/unregister, etc
    goodbye();
    
    return 0;
}

//launch daemon should only be unloaded if box is shutting down
// so handle things like telling kext to disable & unregister, de-init logging, etc
void goodbye()
{
    //tell kext to disable
    // and also to unregister as we're going away
    [kextComms disable:YES];
    
    //close logging
    deinitLogging();
}

//init a handler for SIGTERM
// can perform actions such as disabling firewall and closing logging
void register4Shutdown()
{
    //ignore sigterm
    // handling it via GCD dispatch
    signal(SIGTERM, SIG_IGN);
    
    //init dispatch source for SIGTERM
    dispatchSource = dispatch_source_create(DISPATCH_SOURCE_TYPE_SIGNAL, SIGTERM, 0, dispatch_get_main_queue());
    
    //set handler
    // disable kext & close logging
    dispatch_source_set_event_handler(dispatchSource, ^{
        
        //dbg msg
        logMsg(LOG_DEBUG, @"caught 'SIGTERM' message....shutting down");
        
        //bye!
        // tell kext to disable/unregister, etc
        goodbye();
        
        //bye bye!
        exit(SIGTERM);
    });
    
    //resume
    dispatch_resume(dispatchSource);

    return;
}
