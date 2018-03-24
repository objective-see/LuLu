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

#define LULU_FLT_HANDLE_BASE 0x4c754c75

//socket filter handles
// inspired by 'peerguardian' ppfilter.c
#define FLT_TCPIPV4_HANDLE  (LULU_FLT_HANDLE_BASE - (AF_INET + IPPROTO_TCP))
#define FLT_UDPIPV4_HANDLE  (LULU_FLT_HANDLE_BASE - (AF_INET + IPPROTO_UDP))
#define FLT_TCPIPV6_HANDLE  (LULU_FLT_HANDLE_BASE - (AF_INET6 + IPPROTO_TCP))
#define FLT_UDPIPV6_HANDLE  (LULU_FLT_HANDLE_BASE - (AF_INET6 + IPPROTO_UDP))

//flag for socket filter registration
static boolean_t gRegisteredTCPIPV4 = FALSE;
static boolean_t gRegisteredUDPIPV4 = FALSE;
static boolean_t gRegisteredTCPIPV6 = FALSE;
static boolean_t gRegisteredUDPIPV6 = FALSE;

//flag for socket filter unregistration
static boolean_t gUnregisteringTCPIPV4 = FALSE;
static boolean_t gUnregisteringUDPIPV4 = FALSE;
static boolean_t gUnregisteringTCPIPV6 = FALSE;
static boolean_t gUnregisteringUDPIPV6 = FALSE;

/* FUNCTIONS */

//register socket filters
kern_return_t registerSocketFilters();

//process a socket
kern_return_t process(void *cookie, socket_t so, const struct sockaddr *to);

//queue event
// basically, send to user mode for alert/response, etc
void queueEvent(socket_t so, const struct sockaddr *to);

//unregister socket filters
kern_return_t unregisterSocketFilters();

#endif /* socketEvents_h */
