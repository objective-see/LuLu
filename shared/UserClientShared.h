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


//firewall event struct
typedef struct {
    
    //process pid
    UInt32        pid;
    
    //socket type
    int socketType;
    
    //local socket address
    struct sockaddr_in localAddress;
    
    //remote socket address
    struct sockaddr_in remoteAddress;
    
} firewallEvent;

//dns header
//http://www.nersc.gov/~scottc/software/snort/dns_head.html
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

//TODO
#pragma pack(push,1)
typedef struct {
    uint16_t type;
    uint16_t clas;
    uint32_t ttl;
    uint16_t rdlength;
} static_RR;
#pragma pack(pop)

#endif
