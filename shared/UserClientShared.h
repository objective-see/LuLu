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

#endif
