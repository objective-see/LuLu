//
//  file: KextComms.h
//  project: lulu (launch daemon)
//  description: interface to kernel extension
//
//  created by Patrick Wardle
//  copyright (c) 2017 Objective-See. All rights reserved.
//

#import "consts.h"
#import "logging.h"
#import "KextComms.h"
#import "KextListener.h"
#import "UserClientShared.h"

#include <IOKit/IOKitLib.h>
#include <CoreFoundation/CoreFoundation.h>

//global kext listener object
extern KextListener* kextListener;

@implementation KextComms

@synthesize connection;

//init
-(id)init
{
    //init super
    self = [super init];
    if(nil != self)
    {
        
    }
    
    return self;
}

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
    //dbg msg
    logMsg(LOG_DEBUG, @"sending msg to kext: 'enable'");
    
    //talk to kext
    // enable firewall
    return IOConnectCallScalarMethod(self.connection, kTestUserClientEnable, NULL, 0, NULL, NULL);
}

//disable socket filtering in kernel
-(kern_return_t)disable:(BOOL)shouldUnregister
{
    //input
    uint64_t scalarIn[1] = {0};
    
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
    
    //tell kext listener to reset
    // will ensure alerts are now (re)shown for process
    [kextListener resetAlert:pid];

    //remove rule by pid
    return IOConnectCallScalarMethod(self.connection, kTestUserClientRemoveRule, scalarIn, 1, NULL, NULL);
}

@end
