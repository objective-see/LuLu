//
//  file: rules.cpp
//  project: lulu (kext)
//  description: manages dictionary of rules
//
//  created by Patrick Wardle
//  copyright (c) 2017 Objective-See. All rights reserved.
//

#include "consts.h"
#include "rules.hpp"

#include <sys/systm.h>
#include <IOKit/IOLib.h>
#include <libkern/c++/OSNumber.h>
#include <libkern/c++/OSDictionary.h>

/* GLOBALS */

//lock
IOLock* rulesLock = NULL;

//rules
// key:pid value:action
OSDictionary* rules = NULL;

//rule event lock
IOLock* ruleEventLock = NULL;

/* FUNCTIONS */

//init
// alloc lock and dictionary for rules
bool initRules()
{
    //status var
    bool status = false;

    //dbg msg
    //IOLog("LULU: in %s\n", __FUNCTION__);
    
    //init global rule event lock
    ruleEventLock = IOLockAlloc();
    if(NULL == ruleEventLock)
    {
        //bail
        goto bail;
    }
    
    //alloc lock
    rulesLock = IOLockAlloc();
    if(NULL == rulesLock)
    {
        //bail
        goto bail;
    }
    
    //alloc rule's dictionary
    rules = OSDictionary::withCapacity(1024);
    
    //happy
    status = true;

bail:
    
    return status;
}

//uninit rules
// frees lock and rules dictionary
void uninitRules()
{
    //dbg msg
    //IOLog("LULU: in %s\n", __FUNCTION__);
    
    //free rules dictionary
    if(NULL != rules)
    {
        //release
        rules->release();
        
        //unset
        rules = NULL;
    }
    
    //free rule event lock
    if(NULL != ruleEventLock)
    {
        //free
        IOLockFree(ruleEventLock);
        
        //unset
        ruleEventLock = NULL;
    }
    
    //free rules lock
    if(NULL != rulesLock)
    {
        //free
        IOLockFree(rulesLock);
        
        //unset
        rulesLock = NULL;
    }
    
    return;
}

//add rule
// key: pid
// value: state (allow/disallow)
bool rulesAdd(int processID, bool state)
{
    //status var
    bool status = false;

    //key (as string)
    char key[32] = {0};
    
    //new rule
    OSNumber* ruleState = NULL;

    //init key
    snprintf(key, sizeof(key), "%d", processID);
    
    //init number obj
    ruleState = OSNumber::withNumber(state, sizeof(bool));
    if(NULL == ruleState)
    {
        //bail
        goto bail;
    }

    //lock
    IOLockLock(rulesLock);
    
    //add rule
    rules->setObject(key, ruleState);
    
    //unlock
    IOLockUnlock(rulesLock);
    
    //happy
    status = true;
    
bail:

    return status;
}

//get state of rule
// not found, block, or allow
int queryRule(int processID)
{
    //result
    int result = RULE_STATE_NOT_FOUND;
    
    //key (as string)
    char key[32] = {0};
    
    //state
    OSNumber* ruleState = NULL;
    
    //init key
    snprintf(key, sizeof(key), "%d", processID);
    
    //lock
    IOLockLock(rulesLock);
    
    //get rule
    ruleState = OSDynamicCast(OSNumber, rules->getObject(key));

    //found
    // set state
    if(NULL != ruleState)
    {
        //set state
        result = ruleState->unsigned8BitValue();
    }
    
    //unlock
    IOLockUnlock(rulesLock);
    
    return result;
}

//remove any rule that matches pid
void rulesRemove(int processID)
{
    //key (as string)
    char key[32] = {0};
    
    //init key
    snprintf(key, sizeof(key), "%d", processID);
    
    //lock
    IOLockLock(rulesLock);
    
    //remove rule
    rules->removeObject(key);
    
    //unlock
    IOLockUnlock(rulesLock);
    
    return;
}



