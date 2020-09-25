//
//  file: Alerts.h
//  project: lulu (launch daemon)
//  description: alert related logic/tracking (header)
//
//  created by Patrick Wardle
//  copyright (c) 2017 Objective-See. All rights reserved.
//


@import OSLog;
@import Foundation;
@import NetworkExtension;

#import "Process.h"
#import "XPCUserProto.h"
#import "XPCUserClient.h"

@interface Alerts : NSObject

/* PROPERTIES */

//shown alerts
@property(nonatomic, retain)NSMutableDictionary* shownAlerts;


//xpc client for talking to user (login item)
@property(nonatomic, retain)XPCUserClient* xpcUserClient;

//console user
@property(nonatomic, retain)NSString* consoleUser;

/* METHODS */

//create an alert object
-(NSMutableDictionary*)create:(NEFilterSocketFlow*)flow process:(Process*)process;

//via XPC, send an alert
-(BOOL)deliver:(NSDictionary*)alert reply:(void (^)(NSDictionary*))reply;

//is related to a shown alert?
// checks if path/signing info is same
-(BOOL)isRelated:(Process*)process;

//add an alert to 'shown'
-(void)addShown:(NSDictionary*)alert;

//remove an alert from 'shown'
-(void)removeShown:(NSDictionary*)alert;

@end
