//
//  file: KextComms.h
//  project: lulu (launch daemon)
//  description: interface to kernel extension (header)
//
//  created by Patrick Wardle
//  copyright (c) 2017 Objective-See. All rights reserved.
//

#ifndef KextComms_h
#define KextComms_h

@interface KextComms : NSObject
{
    
}

/* PROPERTIES */

//connection to kext
@property io_connect_t connection;

/* METHODS */

//connect to the firewall kext
-(BOOL)connect;

//enable socket filtering in kernel
-(kern_return_t)enable;

//disable socket filtering in kernel
-(kern_return_t)disable:(BOOL)shouldUnregister;

//add a rule by pid/action
-(kern_return_t)addRule:(uint32_t)pid action:(uint32_t)action;

//remove a rule by pid
-(kern_return_t)removeRule:(uint32_t)pid;

@end

#endif /* KextComms_h */
