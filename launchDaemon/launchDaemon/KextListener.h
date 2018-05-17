//
//  file: KextListener.h
//  project: lulu (launch daemon)
//  description: listener for events from kernel (header)
//
//  created by Patrick Wardle
//  copyright (c) 2017 Objective-See. All rights reserved.
//

@import Foundation;

#import <sys/ioctl.h>
#import <sys/types.h>
#import <sys/socket.h>
#import <sys/kern_event.h>

#import "procInfo.h"
#import "GrayList.h"
#import "UserClientShared.h"

//custom struct for network events
// format of data that's broadcast from kext
struct connectionEvent
{
    //process pid
    pid_t pid;

    //local socket address
    struct sockaddr localAddress;
    
    //remote socket address
    struct sockaddr remoteAddress;
    
    //socket type
    int socketType;
};


@interface KextListener : NSObject
{
    
}

/* PROPERTIES */

//graylist obj
@property(nonatomic, retain)GrayList* grayList;

//DNS 'cache'
// mappings of IP:URL
@property(nonatomic, retain)NSMutableDictionary* dnsCache;

//processes allowed due to 'passive' mode
// save and reset these if user toggles off this mode
@property(nonatomic, retain)NSMutableArray* passiveProcesses;

//observer for process end events
@property(nonatomic, retain)id processEndObvserver;

/* METHODS */

//init
-(id)init;

//kick off threads to monitor for kext events
-(void)monitor;

//process events from the kernel (queue)
-(void)processEvents;

@end
