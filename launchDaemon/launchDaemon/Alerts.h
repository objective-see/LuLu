//
//  file: Alerts.h
//  project: lulu (launch daemon)
//  description: alert related logic/tracking (header)
//
//  created by Patrick Wardle
//  copyright (c) 2017 Objective-See. All rights reserved.
//

#import "procInfo.h"
#import "UserClientShared.h"

#import <Foundation/Foundation.h>

@interface Alerts : NSObject

/* PROPERTIES */

//shown alerts
@property(nonatomic, retain)NSMutableDictionary* shownAlerts;

//related alerts
@property(nonatomic, retain)NSMutableDictionary* relatedAlerts;

//undeliveryed alerts
@property(nonatomic, retain)NSMutableDictionary* undelivertedAlerts;

/* METHODS */

//create an alert object
// note: can treat sockaddr_in and sockaddr_in6 as 'same same' for family, port, etc
-(NSMutableDictionary*)create:(struct networkOutEvent_s*)event process:(Process*)process;

//is related to a shown alert?
// a) for a given pid
// b) for this path, if signing info/hash matches
-(BOOL)isRelated:(pid_t)pid process:(Process*)process;

//add a related rule
-(void)addRelated:(pid_t)pid process:(Process*)process;

//process related alerts
// adds each to kext, and removes
-(void)processRelated:(NSDictionary*)alert;

//add an alert to 'shown'
-(void)addShown:(NSDictionary*)alert;

//remove an alert from 'shown'
-(void)removeShown:(NSDictionary*)alert;

//add an alert 'undelivered'
-(void)addUndeliverted:(struct networkOutEvent_s*)event process:(Process*)process;

//process undelivered alerts
-(void)processUndelivered;

@end
