//
//  file: driver.cpp
//  project: lulu (kext)
//  description: main driver's interface
//
//  created by Patrick Wardle
//  copyright (c) 2017 Objective-See. All rights reserved.
//

#include "consts.h"
#include "rules.hpp"
#include "driver.hpp"
#include "socketEvents.hpp"
#include "userInterface.hpp"
#include "UserClientShared.h"
#include "broadcastEvents.hpp"

#include <IOKit/IOLib.h>


#include <libkern/OSKextLib.h>


#include <libkern/OSMalloc.h>

//super
#define super IOService

/* GLOBALS */

//registered flag
bool wasRegistered = false;

//enabled flag
bool isEnabled = false;

//malloc tag
OSMallocTag allocTag = NULL;

//data queue
IOSharedDataQueue *sharedDataQueue = NULL;

//shared memory
IOMemoryDescriptor *sharedMemoryDescriptor = NULL;

//unloading flag
bool isUnloading = false;

//define class's constructors, destructors, etc
OSDefineMetaClassAndStructors(com_objective_see_firewall, IOService)

//init method
// ->alloc everything here
bool com_objective_see_firewall::init(OSDictionary *dict)
{
    //return var
    bool result = false;
    
    //dbg msg
    IOLog("LULU: in %s\n", __FUNCTION__);
    
    //super
    if(true != super::init(dict))
    {
        //bail
        goto bail;
    }
    
    //happy
    result = true;
    
bail:
    
    return result;
}

//start method
bool com_objective_see_firewall::start(IOService *provider)
{
    //return var
    bool result = false;
    
    //dbg msg
    IOLog("LULU: in %s\n", __FUNCTION__);
    
    //super
    if(TRUE != super::start(provider))
    {
        //bail
        goto bail;
    }
    
    if(kIOReturnSuccess != OSKextRetainKextWithLoadTag(OSKextGetCurrentLoadTag()))
    {
        //err msg
        IOLog("LULU ERROR: OSKextRetainKextWithLoadTag() failed\n");
        
        //bail
        goto bail;
    }
    
    //alloc memory tag
    allocTag = OSMalloc_Tagalloc(BUNDLE_ID, OSMT_DEFAULT);
    if(NULL == allocTag)
    {
        //err msg
        IOLog("LULU ERROR: OSMalloc_Tagalloc() failed\n");
        
        //bail
        goto bail;
    }
    
    //alloc
    // rule locks, etc
    if(true != initRules())
    {
        //err msg
        IOLog("LULU ERROR: failed to init rules/locks\n");
        
        //bail
        goto bail;
    }
    
    //init shared data queue
    sharedDataQueue = IOSharedDataQueue::withCapacity(sizeof(firewallEvent) * (MAX_FIREWALL_EVENTS + DATA_QUEUE_ENTRY_HEADER_SIZE));
    if(NULL == sharedDataQueue)
    {
        //bail
        goto bail;
    }
    
    //get memory descriptor
    sharedMemoryDescriptor = sharedDataQueue->getMemoryDescriptor();
    if(NULL == sharedMemoryDescriptor)
    {
        //bail
        goto bail;
    }
    
    //register service
    // allows clients to connect
    registerService();
    
    //dbg msg
    IOLog("LULU: registered service %s\n",  LULU_SERVICE_NAME);
    
    //set user class
    setProperty("IOUserClientClass", LULU_USER_CLIENT_CLASS);
    
    //init broadcast
    if(true != initBroadcast())
    {
        //err msg
        IOLog("LULU ERROR: initBroadcast() failed\n");
        
        //bail
        goto bail;
    }
    
    //all happy
    result = true;
    
bail:
    
    return result;
}

//stop
// should only be called on system shutdown!
void com_objective_see_firewall::stop(IOService *provider)
{
    //result
    kern_return_t result = kIOReturnError;
    
    //dbg msg
    IOLog("LULU: in %s\n", __FUNCTION__);
    
    //set flag
    isUnloading = true;
    
    //unregister socket filters
    result = unregisterSocketFilters();
    if(kIOReturnSuccess != result)
    {
        //error msg
        IOLog("LULU ERROR: failed to unregister socket filters (status: %d)\n", result);
        
        //keep going though...
    }
    
    //wake up any waiting threads
    // prev. put to sleep until response from daemon
    IOLockWakeup(ruleEventLock, &ruleEventLock, false);
    
    //try get lock
    // should only succeed once the all other threads have awoken and relinquished it
    IOLockLock(ruleEventLock);
    
    //unlock
    IOLockUnlock(ruleEventLock);
    
    //now, can free rule locks, dictionary, etc
    uninitRules();
    
    //free shared memory descriptor
    if(NULL != sharedMemoryDescriptor)
    {
        //release
        sharedMemoryDescriptor->release();
        
        //unset
        sharedMemoryDescriptor = NULL;
    }
    
    //free shared data queue
    if(NULL != sharedDataQueue)
    {
        //release
        sharedDataQueue->release();
        
        //unset
        sharedDataQueue = NULL;
    }
    
    //free alloc tag
    if(NULL != allocTag)
    {
        //free
        OSMalloc_Tagfree(allocTag);
        
        //unset
        allocTag = NULL;
    }

    //super
    super::stop(provider);
    
bail:
    
    return;
}

//free
void com_objective_see_firewall::free(void)
{
    //dbg msg
    IOLog("LULU: in %s\n", __FUNCTION__);
    
    //super
    super::free();
    
    return;
}
