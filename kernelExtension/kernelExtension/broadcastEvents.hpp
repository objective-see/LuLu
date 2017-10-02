//
//  file: broadcastEvents.hpp
//  project: lulu (kext)
//  description: broadcasts socket events to user mode (header)
//
//  created by Patrick Wardle
//  copyright (c) 2017 Objective-See. All rights reserved.
//

#ifndef broadcastEvents_h
#define broadcastEvents_h

extern "C" {

#include <sys/proc.h>
#include <netinet/in.h>
#include <sys/socket.h>
#include <sys/kpi_mbuf.h>
#include <sys/kern_event.h>
#include <sys/kpi_socket.h>

}

#include <IOKit/IOLib.h>


/* FUNCTIONS */

//init
bool initBroadcast();

//broadcast an event to user mode
bool broadcastEvent(int type, socket_t so, const struct sockaddr *to);

//broadcast an DNS reponse to user mode
//bool broadcastDNSReponse(int type, void* packet, size_t length);

#endif
