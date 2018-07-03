//
//  file: userInterface.h
//  project: lulu (kext)
//  description: driver's user interface; 'exposed' methods (header)
//
//  created by Patrick Wardle
//  copyright (c) 2017 Objective-See. All rights reserved.
//

#include "driver.hpp"
#include "UserClientShared.h"

#include <IOKit/IOUserClient.h>
#include <IOKit/IODataQueueShared.h>
#include <IOKit/IOSharedDataQueue.h>

/* GLOBALS */

//registered flag
extern bool wasRegistered;

//enabled flag
extern bool isEnabled;

//locked down flag
extern bool isLockedDown;

//shared data queue
extern IOSharedDataQueue *sharedDataQueue;

//shared memory descriptor
extern IOMemoryDescriptor *sharedMemoryDescriptor;

//rule event lock
extern IOLock* ruleEventLock;

//user client
class com_objectivesee_driver_LuLu : public IOUserClient
{
	OSDeclareDefaultStructors(com_objectivesee_driver_LuLu)
	
private:

	//external methods array
	static const IOExternalMethodDispatch sMethods[kTestUserClientMethodCount];
    
    /* static methods */
 
    //enable
    static IOReturn	sEnable(OSObject* target, void* reference, IOExternalMethodArguments* arguments);
    
    //disable
    static IOReturn	sDisable(OSObject* target, void* reference, IOExternalMethodArguments* arguments);
    
    //lockdown
    static IOReturn sLockDown(OSObject* target, void* reference, IOExternalMethodArguments* arguments);
    
    //add rule
    static IOReturn	sAddRule(OSObject* target, void* reference, IOExternalMethodArguments* arguments);
    
    //remove rule
    static IOReturn	sRemoveRule(OSObject* target, void* reference, IOExternalMethodArguments* arguments);
	
public:
    
    //'standard' overrides
	virtual bool		initWithTask (task_t owningTask, void* securityToken, UInt32 type, OSDictionary* properties) override;
	virtual IOReturn	clientClose (void) override;
	virtual IOReturn	clientDied (void) override;
	
	virtual bool		start (IOService* provider) override;
	virtual void		stop (IOService* provider) override;
	virtual void		free (void) override;
	
	virtual IOReturn	externalMethod (uint32_t selector, IOExternalMethodArguments* arguments, IOExternalMethodDispatch* dispatch = 0, OSObject* target = 0, void* reference = 0) override;
    
    IOReturn registerNotificationPort(mach_port_t port, UInt32 type, UInt32 ref) override;
    IOReturn clientMemoryForType(UInt32 type, IOOptionBits *options, IOMemoryDescriptor **memory) override;
};
