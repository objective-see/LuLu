//
//  file: socketEvents.cpp
//  project: lulu (kext)
//  description: socket filters and socket filter callbacks (header)
//
//  created by Patrick Wardle
//  copyright (c) 2017 Objective-See. All rights reserved.
//

#ifndef socketEvents_h
#define socketEvents_h


extern "C"
{
    
#include <sys/proc.h>
#include <netinet/in.h>
#include <sys/socket.h>
#include <sys/kpi_mbuf.h>
#include <sys/kpi_socket.h>
#include <sys/kpi_socketfilter.h>

}

//socket filter handles
#define FLT_TCPIPV4_HANDLE  'tcp4'
#define FLT_UDPIPV4_HANDLE  'udp4'

//flag for socket filter registration
static boolean_t gRegisteredTCPIPV4 = FALSE;
static boolean_t gRegisteredUDPIPV4 = FALSE;

//flag for socket filter unregistration
static boolean_t gUnregisteringTCPIPV4 = FALSE;
static boolean_t gUnregisteringUDPIPV4 = FALSE;


/* FUNCTIONS */

//register socket filters
kern_return_t registerSocketFilters();

//process a socket
kern_return_t process(void *cookie, socket_t so, const struct sockaddr *to);

//unregister socket filters
kern_return_t unregisterSocketFilters();


#endif /* socketEvents_h */
