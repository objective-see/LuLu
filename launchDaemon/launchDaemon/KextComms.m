//
//  file: KextComms.h
//  project: lulu (launch daemon)
//  description: interface to kernel extension
//
//  created by Patrick Wardle
//  copyright (c) 2017 Objective-See. All rights reserved.
//

#import "Rule.h"
#import "Rules.h"
#import "consts.h"
#import "logging.h"
#import "KextComms.h"
#import "UserClientShared.h"

#include <IOKit/IOKitLib.h>
#include <CoreFoundation/CoreFoundation.h>

/* GLOBALS */

//rules obj
extern Rules* rules;

@implementation KextComms

@synthesize connection;

//connect to the firewall kext
-(BOOL)connect
{
    //status
    BOOL result = NO;
    
    //service object
    io_service_t serviceObject = 0;
    
    //status
    kern_return_t status = KERN_FAILURE;

    //get matching service
    serviceObject = IOServiceGetMatchingService(kIOMasterPortDefault, IOServiceMatching(LULU_SERVICE_NAME));
    if(0 == serviceObject)
    {
        //err msg
        logMsg(LOG_ERR, [NSString stringWithFormat:@"IOServiceGetMatchingService(%s) failed", LULU_SERVICE_NAME]);
        
        //bail
        goto bail;
    }
    
    //dbg msg
    logMsg(LOG_DEBUG, [NSString stringWithFormat:@"got matching service (%s): %#x", LULU_SERVICE_NAME, serviceObject]);
    
    //open service
    status = IOServiceOpen(serviceObject, mach_task_self(), 0, &connection);
    if(KERN_SUCCESS != status)
    {
        //err msg
        logMsg(LOG_ERR, [NSString stringWithFormat:@"IOServiceOpen() failed with: %#x", status]);
        
        //bail
        goto bail;
    }
    
    //dbg msg
    logMsg(LOG_DEBUG, @"opened service");
    
    //happy
    result = YES;
    
bail:
    
    //release matching service
    if(0 != serviceObject)
    {
        //release
        IOObjectRelease(serviceObject);
        
        //unset
        serviceObject = 0;
    }
    
    return result;
}

//enable socket filtering in kernel
-(kern_return_t)enable
{
    //matching rule
    __block Rule* matchingRule = nil;
    
    //process
    __block Process* process = nil;
    
    //return
    kern_return_t enabled = !noErr;
    
    //dbg msg
    logMsg(LOG_DEBUG, @"sending msg to kext: 'enable'");
    
    //talk to kext
    // enable firewall
    enabled = IOConnectCallScalarMethod(self.connection, kTestUserClientEnable, NULL, 0, NULL, NULL);
    if(noErr == enabled)
    {
        //dbg msg
        logMsg(LOG_DEBUG, @"adding process 'start' observer");
        
        //(always)start process start observer
        // code block: add rule to kext
        self.processStartObvserver =  [[NSNotificationCenter defaultCenter] addObserverForName:NOTIFICATION_PROCESS_START object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *notification)
        {
            //extract process
            process = notification.userInfo[NOTIFICATION_PROCESS_START];
            if(nil == process)
            {
                //bail
                return;
            }
            
            //skip xpcproxy
            // always fork/execs anyways
            if(YES == [process.path isEqualToString:XPCPROXY])
            {
                //skip
                return;
            }
            
            //existing rule for process
            matchingRule = [rules find:process];
            if(nil != matchingRule)
            {
                //dbg msg
                logMsg(LOG_DEBUG, [NSString stringWithFormat:@"found matching rule: %@\n", matchingRule]);
                
                //tell kernel to add rule for this process
                [self addRule:process.pid action:matchingRule.action.unsignedIntValue];
            }
        }];
        
        //process end observer isn't (by design) unregistered
        // so only start first time...
        if(nil == self.processEndObvserver)
        {
            //dbg msg
            logMsg(LOG_DEBUG, @"adding process 'end' observer");
            
            //start process end observer
            // code block: remove rule from kext
            self.processEndObvserver =  [[NSNotificationCenter defaultCenter] addObserverForName:NOTIFICATION_PROCESS_END object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *notification)
            {
                //extract process
                process = notification.userInfo[NOTIFICATION_PROCESS_END];
                if(nil == process)
                {
                   //bail
                   return;
                }
                
                //tell kernel to remove rule for this process
                [self removeRule:process.pid];
           }];
        }
    }
    
    return enabled;

}

//disable socket filtering in kernel
-(kern_return_t)disable:(BOOL)shouldUnregister
{
    //input
    uint64_t scalarIn[1] = {0};
    
    //dbg msg
    logMsg(LOG_DEBUG, @"removing 'process start' observer");
    
    //remove process start notification
    if(nil != self.processStartObvserver)
    {
        //remove
        [[NSNotificationCenter defaultCenter] removeObserver:self.processStartObvserver];
        
        //unset
        self.processStartObvserver = nil;
    }
    
    //note:
    // don't unregister process 'end' notification
    // as this is needed to cleanup procs as they end (even if firewall isn't enabled)
    
    //add pid
    scalarIn[0] = shouldUnregister;
    
    //dbg msg
    logMsg(LOG_DEBUG, @"sending msg to kext: 'disable'");
    
    //talk to kext
    // disable firewall
    return IOConnectCallScalarMethod(self.connection, kTestUserClientDisable, scalarIn, 1, NULL, NULL);
}

//add a rule by pid/action
-(kern_return_t)addRule:(uint32_t)pid action:(uint32_t)action
{
    //input
    uint64_t scalarIn[2] = {0};
    
    //add pid
    scalarIn[0] = pid;
    
    //add action
    scalarIn[1] = action;
    
    //dbg msg
    logMsg(LOG_DEBUG, [NSString stringWithFormat:@"sending msg to kext: 'add rule' (pid: %d, action: %d)", pid, action]);
    
    //talk to kext
    // add rule by pid/action
    return IOConnectCallScalarMethod(self.connection, kTestUserClientAddRule, scalarIn, 2, NULL, NULL);
}

//remove a rule by pid
-(kern_return_t)removeRule:(uint32_t)pid;
{
    //input
    uint64_t scalarIn[1] = {0};
    
    //add pid
    scalarIn[0] = pid;
    
    //dbg msg
    logMsg(LOG_DEBUG, [NSString stringWithFormat:@"sending msg to kext: 'removeRule' (pid: %d)", pid]);
    
    //remove rule by pid
    return IOConnectCallScalarMethod(self.connection, kTestUserClientRemoveRule, scalarIn, 1, NULL, NULL);
}

@end
