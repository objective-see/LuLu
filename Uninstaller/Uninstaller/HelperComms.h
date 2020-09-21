//
//  file: HelperComms.h
//  project: lulu (config)
//  description: interface to talk to blessed installer (header)
//
//  created by Patrick Wardle
//  copyright (c) 2018 Objective-See. All rights reserved.
//

@import OSLog;
@import Foundation;


#import "XPCProtocol.h"


@interface HelperComms : NSObject

//remote deamon proxy object
@property(nonatomic, retain) id <XPCProtocol> daemon;

//xpc connection
@property (atomic, strong, readwrite) NSXPCConnection* xpcServiceConnection;

/* METHODS */


//uninstall
// takes flag to indicate full/partial
-(void)uninstall:(BOOL)full reply:(void (^)(NSNumber*))reply;

//cleanup
// remove self
-(void)cleanup:(void (^)(NSNumber*))reply;

@end
