//
//  file: driver.cpp
//  project: lulu (kext)
//  description: main driver's interface
//
//  created by Patrick Wardle
//  copyright (c) 2017 Objective-See. All rights reserved.
//

#include "const.h"
#include "rules.hpp"
#include "driver.hpp"
#include "socketEvents.hpp"
#include "userInterface.hpp"
#include "UserClientShared.h"
#include "broadcastEvents.hpp"

#include <IOKit/IOLib.h>
#include <libkern/OSMalloc.h>

//super
#define super IOService

/* GLOBALS */

//malloc tag
OSMallocTag allocTag = (OSMallocTag)0x4242424242424242;

//data queue
IOSharedDataQueue *sharedDataQueue = NULL;

//shared memory
IOMemoryDescriptor *sharedMemoryDescriptor = NULL;

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
    // ->rule locks, etc
    if(true != initRules())
    {
        //err msg
        IOLog("LULU ERROR: failed to init rules/locks\n");
        
        //bail
        goto bail;
    }
    
    //init shared data queue
    sharedDataQueue = IOSharedDataQueue::withCapacity(sizeof(firewallEvent) * (MAX_FIREWALL_EVENT + DATA_QUEUE_ENTRY_HEADER_SIZE));
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
void com_objective_see_firewall::stop(IOService *provider)
{
    //dbg msg
    IOLog("LULU: in %s\n", __FUNCTION__);
    
    //free rule locks, dictionary, etc
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
