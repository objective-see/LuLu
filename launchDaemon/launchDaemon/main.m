//
//  file: main.m
//  project: lulu (launch daemon)
//  description: main interface/entry point for launch daemon
//
//  created by Patrick Wardle
//  copyright (c) 2017 Objective-See. All rights reserved.
//

#import "main.h"

//TODO: crashes (autorelease pool and status bar)
// main.h
// rules format of plist?

//main
// init & kickoff stuffz
int main(int argc, const char * argv[])
{
    //pool
    @autoreleasepool
    {
        //path to installed apps
        NSString* appDataPath = nil;
        
        //error
        NSError* error = nil;
        
        //user comms listener (XPC) obj
        UserCommsListener* userCommsListener = nil;
        
        //high sierra version struct
        NSOperatingSystemVersion highSierra = {10,13,0};
        
        //dbg msg
        logMsg(LOG_DEBUG, @"LuLu launch daemon started");
        
        //init crash reporting
        initCrashReporting();
        
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
            logMsg(LOG_ERR, @"failed to init/load preferences");
            
            //bail
            goto bail;
        }
        
        //dbg msg
        logMsg(LOG_DEBUG, [NSString stringWithFormat:@"loaded preferences: %@", preferences.preferences]);
        
        //init path to xml file of installed apps
        appDataPath = [INSTALL_DIRECTORY stringByAppendingPathComponent:[NSString stringWithFormat:@"%@.xml", INSTALLED_APPS]];
        
        //init
        baseline = [[Baseline alloc] init];
        
        //installer creates an xml file of installed apps
        // this file needs to be processed and converted to .plist
        if(YES == [[NSFileManager defaultManager] fileExistsAtPath:appDataPath])
        {
            //dbg msg
            logMsg(LOG_DEBUG, [NSString stringWithFormat:@"%@ found, so kicking off baselining logic to process", appDataPath]);
            
            //process app data
            [baseline processAppData:appDataPath];
            
            //delete xml file
            if(YES != [[NSFileManager defaultManager] removeItemAtPath:appDataPath error:&error])
            {
                //err msg
                logMsg(LOG_ERR, [NSString stringWithFormat:@"failed to delete %@ (%@)", appDataPath, error.description]);
                
                //bail
                goto bail;
            }
            
            //dbg msg
            logMsg(LOG_DEBUG, @"baselining complete");
        }
        
        //always load baselined apps
        if(YES != [baseline load])
        {
            //err msg
            logMsg(LOG_ERR, @"failed to load (pre)installed apps");
            
            //bail
            goto bail;
        }
        
        //alloc/init kernel comms object
        kextComms = [[KextComms alloc] init];
        
        //alloc/init alerts object
        alerts = [[Alerts alloc] init];
        
        //alloc/init rules object
        rules = [[Rules alloc] init];
        
        //alloc/init process listener obj
        processListener = [[ProcessListener alloc] init];
    
        //register for shutdown
        // so, can disable firewall and close logging
        register4Shutdown();
        
        //dbg msg
        logMsg(LOG_DEBUG, @"registered for shutdown events");
        
        //init global queue
        eventQueue = [[Queue alloc] init];

        //dbg msg
        logMsg(LOG_DEBUG, @"initialized global queue");
        
        //dbg msg
        logMsg(LOG_DEBUG, [NSString stringWithFormat:@"loaded rules from %@", RULES_FILE]);
    
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
            //trigger kext load again
            // sometimes 'allow' button in system prefs times out?
            execTask(KEXT_LOAD, @[[NSString pathWithComponents:@[@"/", @"Library", @"Extensions", @"LuLu.kext"]]], YES, NO);

            //dbg msg
            logMsg(LOG_DEBUG, @"waiting for kext to load (high sierra)");
            
            //wait
            // will block...
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
        
        //init rule changed semaphore
        rulesChanged = dispatch_semaphore_create(0);
        
        //load rules
        if(YES != [rules load])
        {
            //err msg
            logMsg(LOG_ERR, [NSString stringWithFormat:@"failed to load rules from %@", RULES_FILE]);
            
            //bail
            goto bail;
        }
        
        //add all rules to kernel
        @synchronized(rules.rules)
        {
            //dbg msg
            logMsg(LOG_DEBUG, @"loading (saved) rules into kernel");
            
            //iterate & add all
            for(NSString* path in rules.rules)
            {
                //add
                [rules addToKernel:rules.rules[path]];
            }
        }
        
        //dbg msg
        logMsg(LOG_DEBUG, @"added all rules to kernel");
    
        //no prefs?
        // only happens when user hasn't gone thru 'welcome'
        // so wait until that happens, cuz don't want to being much before anyways...
        while(0 == preferences.preferences.count)
        {
            //dbg msg
            logMsg(LOG_DEBUG, @"waiting for user to complete install");
            
            //nap
            [NSThread sleepForTimeInterval:1.0f];
        }
        
        //dbg msg
        logMsg(LOG_DEBUG, [NSString stringWithFormat:@"user completed install, preferences: %@", preferences.preferences]);
        
        //start enumerating current processes
        // if any have existing rules, tell the kernel about that
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0),
        ^{
           //install/uninstall
           [processListener enumerateCurrent];
        });

        //start listening for process events
        [processListener monitor];
        
        //dbg msg
        logMsg(LOG_DEBUG, @"listening for process events");
        
        //firewall enabled?
        if(YES != [preferences.preferences[PREF_IS_DISABLED] boolValue])
        {
            //enable
            [kextComms enable];
            
            //dbg msg
            logMsg(LOG_DEBUG, @"enabled firewall");
        }
        //user (prev) disabled firewall
        // just log this fact, and don't start it
        else
        {
            //dbg msg
            logMsg(LOG_DEBUG, @"user has disabled firewall, so, not enabling");
        }
        
        //alloc/init kernel listener obj
        kextListener = [[KextListener alloc] init];
        
        //start listening for events
        // though won't be any if firewall is disabled...
        [kextListener monitor];
        
        //dbg msg
        logMsg(LOG_DEBUG, @"listening for kernel events...");
    
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
