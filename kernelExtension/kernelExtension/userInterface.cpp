//
//  file: userInterface.cpp
//  project: lulu (kext)
//  description: driver's user interface ('exposed' methods)
//
//  created by Patrick Wardle
//  copyright (c) 2017 Objective-See. All rights reserved.
//

/* TODOs:
 
 a) authenticate client
 b) ensure only 1 client

*/

#include "consts.h"
#include "rules.hpp"
#include "socketEvents.hpp"
#include "userInterface.hpp"

#include <IOKit/IOLib.h>

//external ('user-invokable') methods
const IOExternalMethodDispatch com_objectivesee_driver_LuLu::sMethods[kTestUserClientMethodCount] =
{
    //enable
    {sEnable, 0, 0, 0, 0},
    
    //disable
    // takes 1 scalar
    {sDisable, 1, 0, 0, 0},
    
    //lockdown state
    // takes 1 scalar
    {sLockDown, 1, 0, 0, 0},
    
    //add rule
    // takes 2 scalars
    {sAddRule,  2, 0, 0, 0},
    
    //add rule
    // takes 1 scalar
    {sRemoveRule,  1, 0, 0, 0},
};

//superclass
#define super IOUserClient

//define meta class/structors
OSDefineMetaClassAndStructors(com_objectivesee_driver_LuLu, IOUserClient)

//start
bool com_objectivesee_driver_LuLu::start(IOService* provider)
{
    //result
    bool result = false;

    //dbg msg
    IOLog("LULU: in (IOUserClient) %s\n", __FUNCTION__);
    
    //invoke super
	if(true != super::start(provider))
    {
        //bail
        goto bail;
    }

    //happy
    result = true;

bail:
	
	return result;
}

//stop
void com_objectivesee_driver_LuLu::stop(IOService* provider)
{
    //dbg msg
    IOLog("LULU: in (IOUserClient) %s\n", __FUNCTION__);
    
    //so set flag
    // tells kext to allow everything
    isEnabled = false;
    
    //dbg msg
    //IOLog("LULU: set 'enabled flag' to false\n");
    
    //invoke super
	super::stop(provider);
    
    return;
}

//free
// don't do anything here, at the moment
void com_objectivesee_driver_LuLu::free(void)
{
    //dbg msg
    IOLog("LULU: in (IOUserClient) %s\n", __FUNCTION__);
    
    //invoke super
	super::free();
    
    return;
}

//client close
// invoke terminate to make object inactive
IOReturn com_objectivesee_driver_LuLu::clientClose(void)
{
    //result
    IOReturn result = kIOReturnError;
 
    //dbg msg
    IOLog("LULU: in (IOUserClient) %s\n", __FUNCTION__);
    
    //terminate
	if(true != terminate())
    {
        //bail
        goto bail;
    }

    //happy
    result = kIOReturnSuccess;
    
bail:
    
	return result;
}

//client died
IOReturn com_objectivesee_driver_LuLu::clientDied(void)
{
    //dbg msg
    IOLog("LULU: in (IOUserClient) %s\n", __FUNCTION__);
    
    //invoke/return super
	return super::clientDied();
}

//init with task
// invoked when client connects
// TODO: validate what client is connecting
bool com_objectivesee_driver_LuLu::initWithTask(task_t owningTask, void* securityToken, UInt32 type, OSDictionary* properties)
{
    //result
    bool result = false;
    
    //dbg msg
    IOLog("LULU: in (IOUserClient) %s\n", __FUNCTION__);
    
    //sanity check
    if(NULL == owningTask)
    {
        //bail
        goto bail;
    }
    
    //call super
    if(true != super::initWithTask(owningTask, securityToken, type, properties))
    {
        //bail
        goto bail;
    }
    
    //client has to be r00t
    if(kIOReturnSuccess != clientHasPrivilege(securityToken, kIOClientPrivilegeAdministrator))
    {
        //bail
        goto bail;
    }
    
    //TODO: validate client here
    // only signed by objective-see!?
    
    //dbg msg
    IOLog("LULU: allowed client to connect\n");
    
    //happy
    result = true;
    
bail:
    
    return result;
}

//dispatcher for external methods
// validate selector, then invoke super which re-routes to appropriate method
IOReturn com_objectivesee_driver_LuLu::externalMethod(uint32_t selector, IOExternalMethodArguments* arguments, IOExternalMethodDispatch* dispatch, OSObject* target, void* reference)
{
    //result
    IOReturn result = kIOReturnError;
    
    //dbg msg
    //IOLog("LULU: in (IOUserClient) %s\n", __FUNCTION__);
    
    //set target
    target = this;
    
    //unset
    reference = NULL;
    
    //sanity check
    if(selector >= kTestUserClientMethodCount)
    {
        //set result
        result = kIOReturnUnsupported;
        
        //bail
        goto bail;
    }
    
    //set dispatch
    dispatch = (IOExternalMethodDispatch*)&sMethods[selector];
    
    //invoke super
    result = super::externalMethod(selector, arguments, dispatch, target, reference);
    
bail:
    
    return result;
}

//set notification port for shared data queue
IOReturn com_objectivesee_driver_LuLu::registerNotificationPort(mach_port_t port, UInt32 type, UInt32 ref)
{
    //return
    IOReturn result = kIOReturnError;
    
    //dbg msg
    //IOLog("LULU: in (IOUserClient) %s\n", __FUNCTION__);
    
    //sanity check
    if( (NULL == sharedDataQueue) ||
        (MACH_PORT_NULL == port) )
    {
        //bail
        goto bail;
    }
    
    //set notification port
    sharedDataQueue->setNotificationPort(port);
    
    //happy
    result = kIOReturnSuccess;

bail:
    
    return result;
}

//set memory type for client
IOReturn com_objectivesee_driver_LuLu::clientMemoryForType(UInt32 type, IOOptionBits *options, IOMemoryDescriptor **memory)
{
    //result
    IOReturn result = kIOReturnError;
    
    //dbg msg
    //IOLog("LULU: in (IOUserClient) %s\n", __FUNCTION__);
    
    //unset
    *memory = NULL;
    
    //unset
    *options = 0;
    
    //check memory type
    // ->only going to handle default type
    if(kIODefaultMemoryType != type)
    {
        //set error
        result = kIOReturnNoMemory;
        
        //bail
        goto bail;
    }
    
    //sanity check
    if(NULL == sharedMemoryDescriptor)
    {
        //set error
        result = kIOReturnNoMemory;
        
        //bail
        goto bail;
    }
    
    //retain
    // ->"client will decrement this reference"
    sharedMemoryDescriptor->retain();
    
    //set type
    *memory = sharedMemoryDescriptor;
    
    //happy
    result = kIOReturnSuccess;
    
bail:
    
    return result;
}

/* IOKIT USER ACCESSIBLE METHODS */

//user method: enable
// register socket filters and set (global) flag
IOReturn com_objectivesee_driver_LuLu::sEnable(OSObject* target, void* reference, IOExternalMethodArguments* arguments)
{
    //result
    IOReturn result = kIOReturnError;
    
    //dbg msg
    IOLog("LULU: in %s\n", __FUNCTION__);
    
    //already registered?
    if(true == wasRegistered)
    {
        //dbg msg
        //IOLog("LULU: socket filters already registered\n");
        
        //no errors
        result = kIOReturnSuccess;
        
        //bail
        goto bail;
    }
    
    //socket filters need to be registered
    result = registerSocketFilters();
    if(kIOReturnSuccess != result)
    {
        //err msg
        IOLog("LULU ERROR: failed to register socket filters (status: %d)\n", result);
        
        //bail
        goto bail;
    }
    
    //happy
    result = kIOReturnSuccess;
    
bail:
    
    //happy?
    // set enabled flag
    if(result == kIOReturnSuccess)
    {
        //set enabled flag
        isEnabled = true;
        
        //dbg msg
        //IOLog("LULU: set 'enabled flag' to true\n");
    }
    
    return result;
}

//user method: disable
// unsets flags, and if specified by args, unregisters all socket filters
IOReturn com_objectivesee_driver_LuLu::sDisable(OSObject* target, void* reference, IOExternalMethodArguments* arguments)
{
    //result
    IOReturn result = kIOReturnError;
    
    //dbg msg
    IOLog("LULU: in %s\n", __FUNCTION__);
    
    //set flag
    // tells kext to allow everything
    isEnabled = false;
    
    //dbg msg
    //IOLog("LULU: set 'enabled flag' to false\n");
    
    //also unregister?
    if(1 == (uint32_t)arguments->scalarInput[0])
    {
        //unregister socket filters
        // this might
        result = unregisterSocketFilters();
        if(kIOReturnSuccess != result)
        {
            //error msg
            IOLog("LULU ERROR: failed to unregister socket filters (status: %#x)\n", result);
            
            //bail
            goto bail;
        }
    }
    
    //happy
    result = kIOReturnSuccess;
    
bail:
    
    return result;
}

//user method: lockdown
// sets lockdown flag, telling system to now block all connections
IOReturn com_objectivesee_driver_LuLu::sLockDown(OSObject* target, void* reference, IOExternalMethodArguments* arguments)
{
    //result
    IOReturn result = kIOReturnError;
    
    //dbg msg
    IOLog("LULU: in %s\n", __FUNCTION__);
    
    //set flag
    // tells kext to allow everything
    isLockedDown = (uint32_t)arguments->scalarInput[0];
    
    //dbg msg
    //IOLog("LULU: set 'locked down flag' to %d\n", isLockedDown);
    
    //happy
    result = kIOReturnSuccess;
    
bail:
    
    return result;
}

//user method: add rule
// add rule, for pid/action
IOReturn com_objectivesee_driver_LuLu::sAddRule(OSObject* target, void* reference, IOExternalMethodArguments* arguments)
{
    //result
    IOReturn result = kIOReturnError;
    
    //pid
    uint32_t pid = 0;
    
    //action
    uint32_t action = 0;
    
    //dbg msg
    //IOLog("LULU: in %s\n", __FUNCTION__);
    
    //grab pid
    pid = (uint32_t)arguments->scalarInput[0];
    
    //grab action
    action = (uint32_t)arguments->scalarInput[1];
    
    //add rule
    if(true != rulesAdd(pid, action))
    {
        //bail
        goto bail;
    }
    
    //dbg msg
    //IOLog("LULU: added rule %d/%d\n", pid, action);
    
    //wake up any waiting threads
    // prev. put to sleep until response from daemon
    IOLockWakeup(ruleEventLock, &ruleEventLock, false);
    
    //happy
    result = kIOReturnSuccess;
    
bail:
    
    return result;
}

//user method: remove rule
// just remove rule for pid
IOReturn com_objectivesee_driver_LuLu::sRemoveRule(OSObject* target, void* reference, IOExternalMethodArguments* arguments)
{
    //pid
    uint32_t pid = 0;
    
    //dbg msg
    //IOLog("LULU: in %s\n", __FUNCTION__);
    
    //grab pid
    pid = (uint32_t)arguments->scalarInput[0];
    
    //remove rule
    rulesRemove(pid);
    
    //dbg msg
    //IOLog("LULU: removed rule %d\n", pid);
    
    return kIOReturnSuccess;
}
