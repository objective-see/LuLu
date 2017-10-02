//
//  file: DaemonComms.h
//  project: lulu (shared)
//  description: talk to daemon (header)
//
//  created by Patrick Wardle
//  copyright (c) 2017 Objective-See. All rights reserved.
//

@import Foundation;

#import "UserCommsInterface.h"


@interface DaemonComms : NSObject

//remote deamon proxy object
@property(nonatomic, retain) id <UserProtocol> daemon;

//xpc connection
@property (atomic, strong, readwrite) NSXPCConnection* xpcServiceConnection;

//set client status
-(void)setClientStatus:(NSInteger)status;

//ask daemon for rules
-(void)getRules:(BOOL)wait4Change reply:(void (^)(NSDictionary*))reply;

//add rule
-(void)addRule:(NSString*)processPath action:(NSUInteger)action;

//delete rule
-(void)deleteRule:(NSString*)processPath;

//import rules
-(BOOL)importRules:(NSString*)rulesFile;

//ask for alert
-(void)alertRequest:(void (^)(NSDictionary* alert))reply;

//respond to alert
-(void)alertResponse:(NSDictionary*)alert;


@end
