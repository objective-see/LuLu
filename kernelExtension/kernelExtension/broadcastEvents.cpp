//
//  file: broadcastEvents.cpp
//  project: lulu (kext)
//  description: broadcasts socket events to user mode
//
//  created by Patrick Wardle
//  copyright (c) 2017 Objective-See. All rights reserved.
//

#include "const.h"
#include "broadcastEvents.hpp"

//kext's/objective-see's vendor id
u_int32_t objSeeVendorID = 0;

//init broadcast
// ->basically just set vendor code
bool initBroadcast()
{
    //result var
    bool result = false;
    
    //status var
    errno_t status = KERN_FAILURE;
    
    //grab vendor id
    status = kev_vendor_code_find(OBJECTIVE_SEE_VENDOR, &objSeeVendorID);
    if(KERN_SUCCESS != status)
    {
        //err msg
        IOLog("LULU ERROR: kev_vendor_code_find() failed to get vendor code (%#x)\n", status);
        
        //bail
        goto bail;
    }
    
    //happy
    result = true;
    
bail:
    
    return result;
}

//broadcast an event to user mode
bool broadcastEvent(int type, socket_t so, const struct sockaddr *to)
{
    //return var
    bool result = false;
    
    //kernel event message
    struct kev_msg kEventMsg = {0};
    
    //process id
    int processID = 0;
    
    //local socket address
    struct sockaddr_in6 localAddress = {0};
    
    //remote socket address
    struct sockaddr_in6 remoteAddress = {0};
    
    //socket type
    int socketType = 0;
    
    //length of socket type
    int socketTypeLength = 0;
    
    //zero out local socket address
    bzero(&localAddress, sizeof(localAddress));
    
    //zero out remote socket address
    bzero(&remoteAddress, sizeof(remoteAddress));
    
    //zero out kernel message
    bzero(&kEventMsg, sizeof(kEventMsg));
    
    //get pid
    processID = proc_selfpid();
    
    //get local address of a socket
    if(KERN_SUCCESS != sock_getsockname(so, (struct sockaddr *)&localAddress, sizeof(localAddress)))
    {
        //err msg
        IOLog("LULU ERROR: sock_getsockname() failed\n");
        
        //bail
        goto bail;
    }
    
    //UDP sockets destination socket might be null
    // ->so grab via 'getpeername' into remote socket
    if(NULL == to)
    {
        //copy into 'remote addr' for user mode
        if(0 != sock_getpeername(so, (struct sockaddr*)&remoteAddress, sizeof(remoteAddress)))
        {
            //err msg
            IOLog("LULU ERROR: sock_getpeername() failed\n");
            
            //bail
            goto bail;
        }
    }
    //copy remote socket for user mode
    else
    {
        //add remote (destination) socket addr
        memcpy(&remoteAddress, to, sizeof(remoteAddress));
    }
    
    //init length
    socketTypeLength = sizeof(socketType);
    
    //get socket type
    sock_getsockopt(so, SOL_SOCKET, SO_TYPE, &socketType, &socketTypeLength);
    
    //set vendor code
    kEventMsg.vendor_code = objSeeVendorID;
    
    //set class
    kEventMsg.kev_class = KEV_ANY_CLASS;
    
    //set subclass
    kEventMsg.kev_subclass = KEV_ANY_SUBCLASS;
    
    //set event code
    // ->connect, data out, etc,
    kEventMsg.event_code = type;
    
    //add pid
    kEventMsg.dv[0].data_length = sizeof(int);
    kEventMsg.dv[0].data_ptr = &processID;
    
    //add local socket
    kEventMsg.dv[1].data_length = sizeof(localAddress);
    kEventMsg.dv[1].data_ptr = &localAddress;
    
    //add remote socket
    kEventMsg.dv[2].data_length = sizeof(remoteAddress);
    kEventMsg.dv[2].data_ptr = &remoteAddress;
    
    //add socket type
    kEventMsg.dv[3].data_length = sizeof(int);
    kEventMsg.dv[3].data_ptr = &socketType;
    
    //dbg msg
    IOLog("LULU: broadcasting connection into to user mode\n");
    
    //broadcast msg to user-mode
    if(KERN_SUCCESS != kev_msg_post(&kEventMsg))
    {
        //err msg
        IOLog("LULU ERROR: kev_msg_post() failed\n");
        
        //bail
        goto bail;
    }
    
    //all happy
    result = true;
    
bail:
    
    return result;
}

/*
//broadcast an DNS reponse to user mode
bool broadcastDNSReponse(int type, void* packet, size_t length)
{
    //return var
    bool result = false;
    
    //kernel event message
    struct kev_msg kEventMsg = {0};
    
    //ignore packets that are too big
    // shouldn't happen to much, and just means won't have IP:URL for that connection
    if(length > (MAX_KEV_MSG - sizeof(struct kev_msg)))
    {
        //err msg
        IOLog("LULU ERROR: DNS response too long, won't broadcast to user-mode\n");
        
        //bail
        goto bail;
    }
    
    //zero out kernel message
    bzero(&kEventMsg, sizeof(kEventMsg));
    
    //set vendor code
    kEventMsg.vendor_code = objSeeVendorID;
    
    //set class
    kEventMsg.kev_class = KEV_ANY_CLASS;
    
    //set subclass
    kEventMsg.kev_subclass = KEV_ANY_SUBCLASS;
    
    //set event code
    kEventMsg.event_code = type;
    
    //add packet length
    kEventMsg.dv[0].data_length = (u_int32_t)length;
    
    //add packet bytes
    // DNS response packet
    kEventMsg.dv[0].data_ptr = packet;
    
    //dbg msg
    IOLog("LULU: broadcasting DNS response into to user mode (size: 0x%zx bytes)\n", length);
    
    //broadcast msg to user-mode
    if(KERN_SUCCESS != kev_msg_post(&kEventMsg))
    {
        //err msg
        IOLog("LULU ERROR: kev_msg_post() failed\n");
        
        //bail
        goto bail;
    }
    
    //all happy
    result = true;

bail:
    
    return result;
}
*/

