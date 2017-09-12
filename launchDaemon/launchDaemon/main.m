//
//  file: main.m
//  project: lulu (launch daemon)
//  description: main interface/entry point for launch daemon
//
//  created by Patrick Wardle
//  copyright (c) 2017 Objective-See. All rights reserved.
//

#import "const.h"
#import "logging.h"
#import "Rules.h"
#import "Queue.h"
#import "KextComms.h"
#import "KextListener.h"
#import "ProcListener.h"
#import "UserCommsListener.h"

//GLOBALS

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
NSInteger clientStatus = STATUS_CLIENT_DISABLED;

//'rule changed' semaphore
dispatch_semaphore_t rulesChanged = 0;

//main
// init & kickoff stuffz
int main(int argc, const char * argv[])
{
    @autoreleasepool
    {
        //user comms listener (XPC) obj
        UserCommsListener* userCommsListener = nil;
        
        //dbg msg
        logMsg(LOG_DEBUG, @"launch daemon started");
        
        //alloc/init kernel comms object
        kextComms = [[KextComms alloc] init];
        
        //alloc/init process listener obj
        processListener = [[ProcessListener alloc] init];
        
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
            logMsg(LOG_ERR, [NSString stringWithFormat:@"failed to initialize user comms XPC listener"]);
            
            //bail
            goto bail;
        }
        
        //dbg msg
        logMsg(LOG_DEBUG, @"listening for client XPC connections");
        
        //connect to kext
        if(YES != [kextComms connect])
        {
            //high sierra, users have to approved kext
            // so, just wait for that the kext to load....
            if(YES == NSProcessInfo.processInfo.operatingSystemVersion.minorVersion >= 13)
            {
                //dbg msg
                logMsg(LOG_DEBUG, @"waiting for kext to load (high sierra)");
                
                //nap & try again
                while(YES)
                {
                    //nap
                    [NSThread sleepForTimeInterval:5.0];
                    
                    //try load
                    if(YES == [kextComms connect])
                    {
                        //horray
                        break;
                    }
                }
            }
            
            //older verions of macOS
            // kext should be automatically loaded
            else
            {
                //err msg
                logMsg(LOG_ERR, [NSString stringWithFormat:@"failed to connect to kext, %s", LULU_SERVICE_NAME]);
                
                //bail
                goto bail;
            }
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
        
        //run loop
        [[NSRunLoop currentRunLoop] run];

    }
    
bail:
    
    //dbg msg
    // should never happen unless box is shutting down
    logMsg(LOG_DEBUG, @"LULU launch daemon exiting");
    
    //tell kext to disable
    [kextComms disable];
    
    return 0;
}
