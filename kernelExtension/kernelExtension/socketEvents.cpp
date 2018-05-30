//
//  file: socketEvents.cpp
//  project: lulu (kext)
//  description: socket filters and socket filter callbacks
//
//  created by Patrick Wardle
//  copyright (c) 2017 Objective-See. All rights reserved.
//

#include "consts.h"
#include "rules.hpp"
#include "socketEvents.hpp"
#include "userInterface.hpp"
#include "UserClientShared.h"
#include "broadcastEvents.hpp"

#include <libkern/OSMalloc.h>

/* socket events called by OS */
static void detach(void *cookie, socket_t so);
static errno_t attach(void **cookie, socket_t so);
static void unregistered(sflt_handle handle);
static errno_t connect_out(void *cookie, socket_t so, const struct sockaddr *to);
static errno_t data_out(void *cookie, socket_t so, const struct sockaddr *to, mbuf_t *data, mbuf_t *control, sflt_data_flag_t flags);
static errno_t data_in(void *cookie, socket_t so, const struct sockaddr *from, mbuf_t *data, mbuf_t *control, sflt_data_flag_t flags);

/* GLOBALS */

//malloc tag
extern OSMallocTag allocTag;

//unloading flag
extern bool isUnloading;

//registered flag
extern bool wasRegistered;

//enabled flag
extern bool isEnabled;

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
    data_in,
    data_out,
    NULL,
    NULL,
    NULL,
    NULL,
    NULL,
    NULL,
    NULL
};

//socket filter, TCP IPV6
static struct sflt_filter tcpFilterIPV6 = {
    FLT_TCPIPV6_HANDLE,
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

//socket filter, UDP IPV4
static struct sflt_filter udpFilterIPV6 = {
    FLT_UDPIPV6_HANDLE,
    SFLT_GLOBAL,
    (char*)BUNDLE_ID,
    unregistered,
    attach,
    detach,
    NULL,
    NULL,
    NULL,
    data_in,
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
    if( (true == gRegisteredTCPIPV4) ||
        (true == gRegisteredUDPIPV4) ||
        (true == gRegisteredTCPIPV6) ||
        (true == gRegisteredUDPIPV6) )
    {
        //err msg
        IOLog("LULU ERROR: socket filters already registered (%d/%d/%d/%d)\n", gRegisteredTCPIPV4, gRegisteredUDPIPV4, gRegisteredTCPIPV6, gRegisteredUDPIPV6);
        
        //bail
        goto bail;
    }
    
    //register socket filter
    // AF_INET domain, SOCK_STREAM type, TCP protocol
    status = sflt_register(&tcpFilterIPV4, AF_INET, SOCK_STREAM, IPPROTO_TCP);
    if(kIOReturnSuccess != status)
    {
        //err msg
        IOLog("LULU ERROR: sflt_register('tcpFilterIPV4') failed with %d\n", status);
        
        //bail
        goto bail;
    }
    
    //set global flag
    gRegisteredTCPIPV4 = true;
    
    //dbg msg
    IOLog("LULU: registered socker filter for tcp ipv4\n");
    
    //register socket filter
    // AF_INET domain, SOCK_DGRAM type, UDP protocol
    status = sflt_register(&udpFilterIPV4, AF_INET, SOCK_DGRAM, IPPROTO_UDP);
    if(kIOReturnSuccess != status)
    {
        //err msg
        IOLog("LULU ERROR: sflt_register('udpFilterIPV4') failed with %d\n", status);
        
        //bail
        goto bail;
    }
    
    //set global flag
    gRegisteredUDPIPV4 = true;
    
    //dbg msg
    IOLog("LULU: registered socker filter for udp ipv4\n");

    //register socket filter
    // ->AF_INET6 domain, SOCK_STREAM type, TCP protocol
    status = sflt_register(&tcpFilterIPV6, AF_INET6, SOCK_STREAM, IPPROTO_TCP);
    if(kIOReturnSuccess != status)
    {
        //err msg
        IOLog("LULU ERROR: sflt_register('tcpFilterIPV6') failed with %d\n", status);
        
        //bail
        goto bail;
    }
    
    //set global flag
    gRegisteredTCPIPV6 = true;
    
    //dbg msg
    IOLog("LULU: registered socker filter for tcp ipv6\n");
    
    //register socket filter
    // AF_INET6 domain, SOCK_DGRAM type, UDP protocol
    status = sflt_register(&udpFilterIPV6, AF_INET6, SOCK_DGRAM, IPPROTO_UDP);
    if(kIOReturnSuccess != status)
    {
        //err msg
        IOLog("LULU ERROR: sflt_register('udpFilterIPV6') failed with %d\n", status);
        
        //bail
        goto bail;
    }
    
    //set global flag
    gRegisteredUDPIPV6 = true;
    
    //dbg msg
    IOLog("LULU: registered socker filter for udp ipv6\n");
    
    //set flag
    wasRegistered = true;
    
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
    if( (false == gRegisteredTCPIPV4) ||
        (false == gRegisteredUDPIPV4) ||
        (false == gRegisteredTCPIPV6) ||
        (false == gRegisteredUDPIPV6) )
    {
        //err msg
        IOLog("LULU ERROR: socket filters already unregistered (%d/%d/%d/%d)\n", gRegisteredTCPIPV4, gRegisteredUDPIPV4, gRegisteredTCPIPV6, gRegisteredUDPIPV6);
        
        //bail
        goto bail;
    }
    
    //TCP IPV4
    // when filter's been registered & not currently unregistering
    // invoke sflt_unregister to unregister, and set global flag
    if( (true == gRegisteredTCPIPV4) &&
        (true != gUnregisteringTCPIPV4))
    {
        //unregister
        status = sflt_unregister(FLT_TCPIPV4_HANDLE);
        if(kIOReturnSuccess != status)
        {
            //err msg
            IOLog("LULU ERROR: sflt_unregister('TCP IPV4') failed with %d\n", status);
            
            //bail
            goto bail;
        }
        
        //set global flag
        gUnregisteringTCPIPV4 = true;
    }
    
    //UDP IPV4
    // when filter's been registered & not currently unregistering
    // invoke sflt_unregister to unregister, and set global flag
    if( (true == gRegisteredUDPIPV4) &&
        (true != gUnregisteringUDPIPV4))
    {
        //unregister
        status = sflt_unregister(FLT_UDPIPV4_HANDLE);
        if(kIOReturnSuccess != status)
        {
            //err msg
            IOLog("LULU ERROR: sflt_unregister('UDP IPV4') failed with %d\n", status);
            
            //bail
            goto bail;
        }
        
        //set global flag
        gUnregisteringUDPIPV4 = true;
    }
    
    //TCP IPV6
    // when filter's been registered & not currently unregistering
    // invoke sflt_unregister to unregister, and set global flag
    if( (true == gRegisteredTCPIPV6) &&
        (true != gUnregisteringTCPIPV6))
    {
        //unregister
        status = sflt_unregister(FLT_TCPIPV6_HANDLE);
        if(kIOReturnSuccess != status)
        {
            //err msg
            IOLog("LULU ERROR: sflt_unregister('TCP IPV6') failed with %d\n", status);
            
            //bail
            goto bail;
        }
        
        //set global flag
        gUnregisteringTCPIPV6 = true;
    }
    
    //UDP IPV6
    // when filter's been registered & not currently unregistering
    // invoke sflt_unregister to unregister, and set global flag
    if( (true == gRegisteredUDPIPV6) &&
        (true != gUnregisteringUDPIPV6))
    {
        //unregister
        status = sflt_unregister(FLT_UDPIPV6_HANDLE);
        if(kIOReturnSuccess != status)
        {
            //err msg
            IOLog("LULU ERROR: sflt_unregister('TCP IPV6') failed with %d\n", status);
            
            //bail
            goto bail;
        }
        
        //set global flag
        gUnregisteringUDPIPV6 = true;
    }

    //filter still registered?
    if( (true == gRegisteredTCPIPV4) ||
        (true == gRegisteredUDPIPV4) ||
        (true == gRegisteredTCPIPV6) ||
        (true == gRegisteredUDPIPV6) )
    {
        //err msg
        IOLog("LULU ERROR: socket filter(s) still registered %d/%d/%d/%d\n", gRegisteredTCPIPV4, gRegisteredUDPIPV4, gRegisteredTCPIPV6, gRegisteredUDPIPV6);
        
        //set error
        status = kIOReturnBusy;
        
        //bail
        goto bail;
    }
    
    //happy
    status = kIOReturnSuccess;
    
bail:
    
    return status;
}

//callback for unregistering a socket filters
// set global flag indicating we are done with filter
static void unregistered(sflt_handle handle)
{
    //dbg msg
    IOLog("LULU: in %s\n", __FUNCTION__);
    
    //dbg msg
    IOLog("LULU: unregistering handle %d\n", handle);
    
    //set appropriate handle
    switch (handle) {
        
        //tcp ipv4
        case FLT_TCPIPV4_HANDLE:
            
            //set
            gRegisteredTCPIPV4 = false;
            break;
            
        //udp ipv4
        case FLT_UDPIPV4_HANDLE:
            
            //set
            gRegisteredUDPIPV4 = false;
            break;
            
        //tcp ipv6
        case FLT_TCPIPV6_HANDLE:
            
            //set
            gRegisteredTCPIPV6 = false;
            break;
            
        //udp ipv6
        case FLT_UDPIPV6_HANDLE:
            
            //set
            gRegisteredUDPIPV6 = false;
            break;
            
        default:
            break;
    }
    
    return;
}

//called for new socket
// find rule, and attach entry (so know to ask/allow/deny for later actions)
static kern_return_t attach(void **cookie, socket_t so)
{
    //result
    kern_return_t result = kIOReturnError;
    
    //unset
    *cookie = NULL;
    
    //dbg msg
    //IOLog("LULU: in %s\n", __FUNCTION__);
    
    //ignore if not enabled
    if(true != isEnabled)
    {
        //ignore
        // but no errors
        result = kIOReturnSuccess;
        
        //bail
        goto bail;
    }
    
    //don't mess w/ kernel sockets
    if(0 == proc_selfpid())
    {
        //ignore
        // but no errors
        result = kIOReturnSuccess;
        
        //bail
        goto bail;
    }
    
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
    // not found, block, allow, etc
    ((struct cookieStruct*)(*cookie))->ruleAction = queryRule(proc_selfpid());
    
    //dbg msg
    IOLog("LULU: rule action for %d: %d\n", proc_selfpid(), ((struct cookieStruct*)(*cookie))->ruleAction);
    
    //happy
    result = kIOReturnSuccess;
    
bail:
    
    return result;
}

//call back for detach
// just free socket's cookie
static void detach(void *cookie, socket_t so)
{
    //dbg msg
    //IOLog("LULU: in %s\n", __FUNCTION__);
    
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

//callback for incoming data
// only interested in DNS responses for IP:URL mappings, so always return 'ok'
// code inspired by: https://github.com/williamluke/peerguardian-linux/blob/master/pgosx/kern/ppfilter.c
static errno_t data_in(void *cookie, socket_t so, const struct sockaddr *from, mbuf_t *data, mbuf_t *control, sflt_data_flag_t flags)
{
    //port
    in_port_t port = 0;
    
    //peer name
    struct sockaddr_in6 peerName = {0};
    
    //mem buffer
    mbuf_t memBuffer = NULL;
    
    //response size
    size_t responseSize = 0;
    
    //dns header
    dnsHeader* dnsHeader = NULL;
    
    //firewall event
    firewallEvent event = {0};
    
    //dbg msg
    //IOLog("LULU: in %s\n", __FUNCTION__);
    
    //ignore if not enabled
    if(true != isEnabled)
    {
        //bail
        goto bail;
    }
    
    //destination socket ('from') might be null?
    // if so, grab it via 'getpeername' from the socket
    if(NULL == from)
    {
        //lookup remote socket info
        if(0 != sock_getpeername(so, (struct sockaddr*)&peerName, sizeof(peerName)))
        {
            //err msg
            IOLog("LULU ERROR: sock_getpeername() failed\n");
            
            //bail
            goto bail;
        }
        
        //now, assign
        from = (const struct sockaddr*)&peerName;
    }

    //get port
    switch(from->sa_family)
    {
        //IPv4
        case AF_INET:
            port = ntohs(((const struct sockaddr_in*)from)->sin_port);
            break;
            
        //IPv6
        case AF_INET6:
            port = ntohs(((const struct sockaddr_in6*)from)->sin6_port);
            break;
            
        default:
            break;
    }
    
    //ignore non-DNS
    if(53 != port)
    {
        //bail
        goto bail;
    }
    
    //init memory buffer
    memBuffer = *data;
    if(NULL == memBuffer)
    {
        //bail
        goto bail;
    }
    
    //get memory buffer
    while(MBUF_TYPE_DATA != mbuf_type(memBuffer))
    {
        //get next
        memBuffer = mbuf_next(memBuffer);
        if(NULL == memBuffer)
        {
            //bail
            goto bail;
        }
    }
    
    //sanity check length
    if(mbuf_len(memBuffer) <= sizeof(struct dnsHeader))
    {
        //bail
        goto bail;
    }
    
    //get data
    // should be a DNS header
    dnsHeader = (struct dnsHeader*)mbuf_data(memBuffer);
    
    //ignore everything that isn't a DNS response
    // top bit flag will be 0x1, for "a name service response"
    if(0 == ((ntohs(dnsHeader->flags)) & (1<<(15))))
    {
        //bail
        goto bail;
    }
    
    //ignore any errors
    // bottom (4) bits will be 0x0 for "successful response"
    if(0 != ((ntohs(dnsHeader->flags)) & (1<<(0))))
    {
        //bail
        goto bail;
    }
    
    //ignore any packets that don't have answers
    if(0 == ntohs(dnsHeader->ancount))
    {
        //bail
        goto bail;
    }
    
    //zero out event struct
    bzero(&event, sizeof(firewallEvent));
    
    //set type
    event.dnsResponseEvent.type = EVENT_DNS_RESPONSE;
    
    //set size
    // max, 512
    responseSize = MIN(sizeof(event.dnsResponseEvent.response), mbuf_len(memBuffer));
    
    //copy response
    memcpy(event.dnsResponseEvent.response, mbuf_data(memBuffer), responseSize);
    
    //queue it up
    sharedDataQueue->enqueue_tail(&event, sizeof(firewallEvent));
    
bail:
    
    return kIOReturnSuccess;
}

//callback for outgoing (UDP) connections
// NULL rule: broadcast event to user and sleep
// non-NULL rule: block/allow based on what rule says
static kern_return_t data_out(void *cookie, socket_t so, const struct sockaddr *to, mbuf_t *data, mbuf_t *control, sflt_data_flag_t flags)
{
    //result
    kern_return_t result = kIOReturnError;
    
    //dbg msg
    //IOLog("LULU: in %s\n", __FUNCTION__);
    
    //ignore if not enabled
    if(true != isEnabled)
    {
        //ignore
        // but no errors
        result = kIOReturnSuccess;
        
        //bail
        goto bail;
    }
    
    //sanity check
    // socket we're watching?
    if(NULL == cookie)
    {
        //ignore
        // but no errors
        result = kIOReturnSuccess;
        
        //bail
        goto bail;
    }
    
    //broadcast to user mode
    broadcastEvent(EVENT_DATA_OUT, so, to);
    
    //process
    // block/allow/ask user
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
    //IOLog("LULU: in %s\n", __FUNCTION__);
    
    //ignore if not enabled
    if(true != isEnabled)
    {
        //ignore
        // but no errors
        result = kIOReturnSuccess;
        
        //bail
        goto bail;
    }
    
    //sanity check
    // socket we're watching?
    if(NULL == cookie)
    {
        //ignore
        // but no errors
        result = kIOReturnSuccess;
        
        //bail
        goto bail;
    }
    
    //broadcast to user mode
    broadcastEvent(EVENT_CONNECT_OUT, so, to);
    
    //process
    // block/allow/ask user
    result = process(cookie, so, to);
    
bail:
    
    return result;
}

//process
// block/allow, or ask user and put thread to sleep
kern_return_t process(void *cookie, socket_t so, const struct sockaddr *to)
{
    //result
    kern_return_t result = kIOReturnError;
    
    //rule
    int action = RULE_STATE_NOT_FOUND;
    
    //awake reason
    int reason = THREAD_WAITING;
    
    //process name
    char processName[PATH_MAX] = {0};
    
    //what does rule say?
    // loop until we have an answer
    while(true)
    {
        //extract action
        action = ((struct cookieStruct*)cookie)->ruleAction;
        
        //get process name
        proc_selfname(processName, PATH_MAX);
        
        //dbg msg
        IOLog("LULU: processing outgoing network event for %s (pid: %d / action: %d)\n", processName, proc_selfpid(), action);

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
        
        //not found?
        // ask daemon and sleep for response
        else if(RULE_STATE_NOT_FOUND == action)
        {
            //dbg msg
            IOLog("LULU: no rule found for %s (pid: %d)\n", processName, proc_selfpid());
            
            //first time
            // send to user mode
            if(THREAD_WAITING == reason)
            {
                //send
                queueEvent(so, to);
            }
            
            //dbg msg
            IOLog("LULU: thread for %s (pid: %d) going (back) to sleep\n", processName, proc_selfpid());
            
            //lock
            IOLockLock(ruleEventLock);
            
            //sleep
            reason = IOLockSleep(ruleEventLock, &ruleEventLock, THREAD_ABORTSAFE);
            
            //unlock
            IOLockUnlock(ruleEventLock);
            
            //dbg msg
            IOLog("LULU: process %d's thread awoke with reason %d\n", proc_selfpid(), reason);
            
            //woke becuase kext is unloading?
            if(true == isUnloading)
            {
                //dbg msg
                IOLog("LULU: thread awoke, but because of kext is unloading\n");
                
                //just allow
                result = kIOReturnSuccess;
                
                //bail
                goto bail;
            }
            
            //thread wakeup cuz of signal, etc
            // just bail (process likely exited, etc)
            else if(THREAD_AWAKENED != reason)
            {
                //dbg msg
                IOLog("LULU: thread awoke, but because of %d!\n", reason);
                
                //gtfo!
                result = kIOReturnNotPermitted;
                
                //all done
                goto bail;
            }
            
            //dbg msg
            IOLog("LULU: process %d's thread awoke, will check/handle response\n", proc_selfpid());
            
            //try get rule action again
            // not found, block, allow, etc.
            ((struct cookieStruct*)(cookie))->ruleAction = queryRule(proc_selfpid());
            
            //loop to (re)process
        }
        
    }//while
    
bail:
    
    return result;
}

//queue event
// basically, send to user mode for alert/response, etc
void queueEvent(socket_t so, const struct sockaddr *to)
{
    //event
    firewallEvent event = {0};
    
    //socket type
    int socketType = 0;
    
    //length of socket type
    int socketTypeLength = 0;
    
    //dbg msg
    IOLog("LULU: queueing event for user mode...\n");
    
    //zero out
    bzero(&event, sizeof(firewallEvent));
    
    //set type
    event.networkOutEvent.type = EVENT_NETWORK_OUT;
    
    //add pid
    event.networkOutEvent.pid = proc_selfpid();
    
    //init length
    socketTypeLength = sizeof(socketType);
    
    //get socket type
    sock_getsockopt(so, SOL_SOCKET, SO_TYPE, &socketType, &socketTypeLength);
    
    //save type
    event.networkOutEvent.socketType = socketType;
    
    //UDP sockets destination socket might be null
    // so grab via 'getpeername' and save as 'remote addr'
    if(NULL == to)
    {
        //copy into 'remote addr' for user mode
        if(0 != sock_getpeername(so, (struct sockaddr*)&(event.networkOutEvent.remoteAddress), sizeof(event.networkOutEvent.remoteAddress)))
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
        memcpy(&(event.networkOutEvent.remoteAddress), to, sizeof(event.networkOutEvent.remoteAddress));
    }
    
    //queue it up
    sharedDataQueue->enqueue_tail(&event, sizeof(firewallEvent));
    
bail:
    
    return;
}
