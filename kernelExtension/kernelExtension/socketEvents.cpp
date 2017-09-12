//
//  file: socketEvents.cpp
//  project: lulu (kext)
//  description: socket filters and socket filter callbacks
//
//  created by Patrick Wardle
//  copyright (c) 2017 Objective-See. All rights reserved.
//

#include "const.h"
#include "rules.hpp"
#include "socketEvents.hpp"
#include "userInterface.hpp"
#include "UserClientShared.h"
#include "broadcastEvents.hpp"

#include <libkern/OSMalloc.h>

/* TODOs:

 a) add IPV6 support
 b) implement data_in for IP/URL resolution?
 
*/

/* socket events called by OS */
static void detach(void *cookie, socket_t so);
static errno_t attach(void **cookie, socket_t so);
static void unregistered(sflt_handle handle);
static errno_t connect_out(void *cookie, socket_t so, const struct sockaddr *to);
static errno_t data_out(void *cookie, socket_t so, const struct sockaddr *to, mbuf_t *data, mbuf_t *control, sflt_data_flag_t flags);

/* GLOBALS */

//malloc tag
extern OSMallocTag allocTag;

//cookie passed to each socket
// ->just has rule action (allow/block)
struct cookieStruct
{
    //action
    int ruleAction;
};

//socket filter, TCP IPV4
static struct sflt_filter tcpFilterIPV4 = {
    FLT_TCPIPV4_HANDLE,
    SFLT_GLOBAL,
    (char*)BUNDLE_ID,
    unregistered,
    attach,
    detach,
    NULL,
    NULL,
    NULL,
    NULL,
    NULL,
    NULL,
    connect_out,
    NULL,
    NULL,
    NULL,
    NULL,
    NULL
};

//TODO: maybe also attach to connect out?
// see: https://github.com/williamluke/peerguardian-linux/blob/master/pgosx/kern/ppfilter.c

//socket filter, UDP IPV4
static struct sflt_filter udpFilterIPV4 = {
    FLT_UDPIPV4_HANDLE,
    SFLT_GLOBAL,
    (char*)BUNDLE_ID,
    unregistered,
    attach,
    detach,
    NULL,
    NULL,
    NULL,
    NULL,
    data_out,
    NULL,
    NULL,
    NULL,
    NULL,
    NULL,
    NULL,
    NULL
};


//register socket filters
kern_return_t registerSocketFilters()
{
    //return
    IOReturn result = kIOReturnError;
    
    //status var
    kern_return_t status = kIOReturnError;
    
    //dbg msg
    IOLog("LULU: in %s\n", __FUNCTION__);
    
    //sanity check
    // TODO: when IPV6 support added, add here too
    if( (true == gRegisteredTCPIPV4) ||
        (true == gRegisteredUDPIPV4) )
    {
        //err msg
        IOLog("LULU ERROR: socket filters already registered (%d/%d)\n", gRegisteredTCPIPV4, gRegisteredUDPIPV4);
        
        //bail
        goto bail;
    }
    
    //register socket filter
    // ->AF_INET domain, SOCK_STREAM type, TCP protocol
    status = sflt_register(&tcpFilterIPV4, PF_INET, SOCK_STREAM, IPPROTO_TCP);
    if(kIOReturnSuccess != status)
    {
        //err msg
        IOLog("LULU ERROR: sflt_register failed with %d\n", status);
        
        //bail
        goto bail;
    }
    
    //set global flag
    gRegisteredTCPIPV4 = true;
    
    //dbg msg
    IOLog("LULU: registerd socker filter for tcp ipv4\n");
    
    //register socket filter
    // ->AF_INET domain, SOCK_DGRAM type, UDP protocol
    status = sflt_register(&udpFilterIPV4, PF_INET, SOCK_DGRAM, IPPROTO_UDP);
    if(kIOReturnSuccess != status)
    {
        //err msg
        IOLog("LULU ERROR: sflt_register failed with %d\n", status);
        
        //bail
        goto bail;
    }
    
    //set global flag
    gRegisteredUDPIPV4 = true;
    
    //dbg msg
    IOLog("LULU: registerd socker filter for udp ipv4\n");
    
    //happy
    result = kIOReturnSuccess;
    
bail:
    
    return result;
}

//unregister socket filters
kern_return_t unregisterSocketFilters()
{
    //status
    kern_return_t status = kIOReturnError;
    
    //dbg msg
    IOLog("LULU: in %s\n", __FUNCTION__);
    
    //sanity check
    // TODO: when IPV6 support added, add here too
    if( (false == gRegisteredTCPIPV4) ||
        (false == gRegisteredUDPIPV4) )
    {
        //err msg
        IOLog("LULU ERROR: socket filters already unregistered (%d/%d)\n", gRegisteredTCPIPV4, gRegisteredUDPIPV4);
        
        //bail
        goto bail;
    }
    
    //TCP IPV4
    // when filter's been registered & not currently unregistering
    // ->invoke sflt_unregister to unregister, and set global flag
    if( (true == gRegisteredTCPIPV4) &&
        (true != gUnregisteringTCPIPV4))
    {
        //unregister
        sflt_unregister(FLT_TCPIPV4_HANDLE);
        
        //set global flag
        gUnregisteringTCPIPV4 = true;
    }
    
    //UDP IPV4
    // when filter's been registered & not currently unregistering
    // ->invoke sflt_unregister to unregister, and set global flag
    if( (true == gRegisteredUDPIPV4) &&
        (true != gUnregisteringUDPIPV4))
    {
        //unregister
        sflt_unregister(FLT_UDPIPV4_HANDLE);
        
        //set global flag
        gUnregisteringUDPIPV4 = true;
    }
    
    //filter still registered?
    if( (true == gRegisteredTCPIPV4) ||
        (true == gRegisteredUDPIPV4) )
    {
        //err msg
        IOLog("LULU ERROR: socket filter(s) still registered %d/%d\n", gRegisteredTCPIPV4, gRegisteredUDPIPV4);
        
        //set error
        status = EBUSY;
        
        //bail
        goto bail;
    }
    
    //happy
    status = kIOReturnSuccess;
    
bail:
    
    return status;
}

//callback for unregistering a socket filters
// ->set global flag indicating we are done with filter
static void unregistered(sflt_handle handle)
{
    //dbg msg
    IOLog("LULU: in %s\n", __FUNCTION__);
    
    //tcp ipv4
    // ->set flag
    if(FLT_TCPIPV4_HANDLE == handle)
    {
        //set
        gRegisteredTCPIPV4 = false;
    }
    
    //tcp ipv4
    // ->set flag
    else if(FLT_UDPIPV4_HANDLE == handle)
    {
        //set
        gRegisteredUDPIPV4 = false;
    }
    
    return;
}

//called for new socket
// ->find rule, and attach entry (so know to allow/deny for later actions)
//   if no rule is found, that's ok (new proc), request user input in connect_out or sf_data_out, etc
static kern_return_t attach(void **cookie, socket_t so)
{
    //result
    kern_return_t result = kIOReturnError;
    
    //unset
    *cookie = NULL;
    
    //dbg msg
    IOLog("LULU: in %s\n", __FUNCTION__);
    
    //set cookie
    *cookie = (void*)OSMalloc(sizeof(struct cookieStruct), allocTag);
    if(NULL == *cookie)
    {
        //no memory
        result = ENOMEM;
        
        //bail
        goto bail;
    }
    
    //set rule action
    // ->not found, block, allow, etc
    ((struct cookieStruct*)(*cookie))->ruleAction = queryRule(proc_selfpid());
    
    //dbg msg
    IOLog("LULU: rule action for %d: %d\n", proc_selfpid(), ((struct cookieStruct*)(*cookie))->ruleAction);
    
    //happy
    result = kIOReturnSuccess;
    
bail:
    
    return result;
}

//call back for detach
// ->just free socket's cookie
static void detach(void *cookie, socket_t so)
{
    //dbg msg
    IOLog("LULU: in %s\n", __FUNCTION__);
    
    //free cookie
    if(NULL != cookie)
    {
        //free
        OSFree(cookie, sizeof(struct cookieStruct), allocTag);
        
        //reset
        cookie = NULL;
    }
    
    return;
}

/* 

//TODO: might need this for DNS/UDP responses for IPs!
static errno_t data_in(void *cookie, socket_t so, const struct sockaddr *from, mbuf_t *data, mbuf_t *control, sflt_data_flag_t flags)
{
    //result
    errno_t result = 0;
    
    //dbg msg
    //IOLog("LULU: in %s\n", __FUNCTION__);
    
    return result;
    
}
*/

//callback for outgoing (UDP) connections
// NULL rule: broadcast event to user and sleep
// non-NULL rule: block/allow based on what rule says
static kern_return_t data_out(void *cookie, socket_t so, const struct sockaddr *to, mbuf_t *data, mbuf_t *control, sflt_data_flag_t flags)
{
    //result
    kern_return_t result = kIOReturnError;
    
    //dbg msg
    IOLog("LULU: in %s\n", __FUNCTION__);
    
    //sanity check
    if(NULL == cookie)
    {
        //bail
        goto bail;
    }
    
    //broadcast to user mode
    broadcastEvent(EVENT_DATA_OUT, so, to);
    
    //process
    // ->block/allow/ask user
    result = process(cookie, so, to);
    
bail:
    
    return result;
}

//callback for outgoing (TCP) connections
// NULL rule: broadcast event to user and sleep
// non-NULL rule: block/allow based on what rule says
static kern_return_t connect_out(void *cookie, socket_t so, const struct sockaddr *to)
{
    //result
    kern_return_t result = kIOReturnError;
    
    //dbg msg
    IOLog("LULU: in %s\n", __FUNCTION__);
    
    //sanity check
    if(NULL == cookie)
    {
        //bail
        goto bail;
    }
    
    //broadcast to user mode
    broadcastEvent(EVENT_CONNECT_OUT, so, to);
    
    //process
    // ->block/allow/ask user
    result = process(cookie, so, to);
    
bail:
    
    return result;
}

//process
// ->block/allow, or ask user and put thread to sleep
kern_return_t process(void *cookie, socket_t so, const struct sockaddr *to)
{
    //result
    kern_return_t result = kIOReturnError;
    
    //event
    firewallEvent event = {0};
    
    //rule
    int action = RULE_STATE_NOT_FOUND;
    
    //awake reason
    int reason = 0;
    
    //socket type
    int socketType = 0;
    
    //length of socket type
    int socketTypeLength = 0;
    
    //process name
    char processName[PATH_MAX] = {0};

    //what does rule say?
    // ->loop until we have an answer
    while(true)
    {
        //extract action
        action = ((struct cookieStruct*)cookie)->ruleAction;
        
        //get process name
        proc_selfname(processName, PATH_MAX);

        //block?
        if(RULE_STATE_BLOCK == action)
        {
            //dbg msg
            IOLog("LULU: rule says block for %s (pid: %d)\n", processName, proc_selfpid());
            
            //gtfo!
            result = EPERM;
            
            //all done
            goto bail;
        }
        
        //allow?
        else if(RULE_STATE_ALLOW == action)
        {
            //dbg msg
            IOLog("LULU: rule says allow for %s (pid: %d)\n", processName, proc_selfpid());
            
            //ok
            result = kIOReturnSuccess;
            
            //all done
            goto bail;
        }
        
        //not found
        // ->ask daemon and sleep for response
        else if(RULE_STATE_NOT_FOUND == action)
        {
            //dbg msg
            IOLog("LULU: no rule found for %s (pid: %d)\n", processName, proc_selfpid());
            
            //zero out
            bzero(&event, sizeof(firewallEvent));
            
            //add pid
            event.pid = proc_selfpid();
            
            //init length
            socketTypeLength = sizeof(socketType);
            
            //get socket type
            sock_getsockopt(so, SOL_SOCKET, SO_TYPE, &socketType, &socketTypeLength);
            
            //save type
            event.socketType = socketType;
            
            //UDP sockets destination socket might be null
            // ->so grab via 'getpeername' and save as 'remote addr'
            if(NULL == to)
            {
                //copy into 'remote addr' for user mode
                if(0 != sock_getpeername(so, (struct sockaddr*)&(event.remoteAddress), sizeof(struct sockaddr_in)))
                {
                    //err msg
                    IOLog("LULU ERROR: sock_getpeername() failed");
                    
                    //bail
                    goto bail;
                }
            }
            
            //copy remote socket for user mode
            else
            {
                //add remote (destination) socket addr
                memcpy(&(event.remoteAddress), to, sizeof(struct sockaddr));
            }
            
            //queue it up
            sharedDataQueue->enqueue_tail(&event, sizeof(firewallEvent));
            
            //dbg msg
            IOLog("LULU: queued response to user mode, now going to sleep!\n");
            
            //lock
            IOLockLock(ruleEventLock);
            
            //sleep
            reason = IOLockSleep(ruleEventLock, &ruleEventLock, THREAD_ABORTSAFE);
            
            //TODO: fix panic
            // "Preemption level underflow, possible cause unlocking an unlocked mutex or spinlock"
            //  seems to happen when process is killed or kext unloaded while in the IOLockSleep!?
            
            //unlock
            IOLockUnlock(ruleEventLock);
            
            //thread wakeup cuz of signal, etc
            // ->just bail (process likely exited, etc)
            if(THREAD_AWAKENED != reason)
            {
                //dbg msg
                IOLog("LULU: thread awoke, but because of %d!\n", reason);
                
                //gtfo!
                result = EPERM;
                
                //all done
                goto bail;
            }
            
            //dbg msg
            IOLog("LULU: thread awoke, will check/process response\n");
            
            //try get rule action again
            // ->not found, block, allow, etc
            ((struct cookieStruct*)(cookie))->ruleAction = queryRule(proc_selfpid());
            
            //loop to (re)process
        }
        
    }//while
    
bail:
    
    return result;
}
