//
//  file: UserClientShared.h
//  project: lulu (shared)
//  description: dispatch selectors and data structs shared between user and kernel mode
//
//  created by Patrick Wardle
//  copyright (c) 2017 Objective-See. All rights reserved.
//

#ifndef userClientShared_h
#define userClientShared_h

#include <stdint.h>

#if defined (KERNEL)
extern "C" {
#endif

#include <sys/proc.h>
#include <netinet/in.h>
#include <sys/socket.h>
#include <sys/param.h>
   
#if defined (KERNEL)
}
#endif

//user client method dispatch selectors.
enum dispatchSelectors {
    
    kTestUserClientEnable,
    kTestUserClientDisable,
    kTestUserClientAddRule,
    kTestUserClientRemoveRule,
	kTestUserClientMethodCount
};

//type
struct genericEvent_s
{
    //type
    UInt32 type;
};

//network out event struct
struct networkOutEvent_s {
    
    //type
    UInt32 type;
    
    //process pid
    UInt32 pid;
    
    //socket type
    int socketType;
    
    //local socket address
    struct sockaddr_in6 localAddress;
    
    //remote socket address
    struct sockaddr_in6 remoteAddress;
};

//dns response out event struct
struct dnsResponseEvent_s {
    
    //type
    UInt32 type;
    
    //response
    unsigned char response[512];
};

//firewall event union
// holds various structs, but max size will be 'padding'
typedef union
{
    //generic event
    struct genericEvent_s genericEvent;
    
    //network out event
    struct networkOutEvent_s networkOutEvent;
    
    //dns response event
    struct dnsResponseEvent_s dnsResponseEvent;
    
    //padding
    unsigned char padding[sizeof(UInt32) + 512];
    
} firewallEvent;

//dns header struct
// from: http://www.nersc.gov/~scottc/software/snort/dns_head.html
#pragma pack(push,1)
struct dnsHeader {
    unsigned short id;
    unsigned short flags;
    unsigned short qdcount;
    unsigned short ancount;
    unsigned short nscount;
    unsigned short arcount;
};
#pragma pack(pop)

#endif
