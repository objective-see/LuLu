//
//  file: Rules.h
//  project: LuLu (launch daemon)
//  description: handles rules & actions such as add/delete (header)
//
//  created by Patrick Wardle
//  copyright (c) 2017 Objective-See. All rights reserved.
//


#ifndef Rules_h
#define Rules_h

#import "Process.h"
#import "XPCUserClient.h"

@import OSLog;
@import Foundation;
@import NetworkExtension;

@class Rule;
@class ProcessTreeTracker;


@interface Rules : NSObject
{
    
}

/* PROPERTIES */

//rules
@property(nonatomic, retain)NSMutableDictionary* rules;

//kernel-observed ancestry for explicitly selected strict policies
@property(nonatomic, retain)ProcessTreeTracker* processTreeTracker;

//xpc client for talking to login item
@property(nonatomic, retain)XPCUserClient* xpcUserClient;

/* METHODS */

//prepare
// first time? generate defaults rules
// upgrade (v1.0)? convert to new format
-(BOOL)prepare;

//load from disk
-(BOOL)load;

//generate default rules
-(BOOL)generateDefaultRules;

//add a rule
-(BOOL)add:(Rule*)rule save:(BOOL)save;

//find (matching) rule
-(Rule*)find:(Process*)process flow:(NEFilterSocketFlow*)flow;

//nil means this flow has no observed strict owner
-(NSNumber*)strictDecisionForAuditToken:(NSData*)token process:(Process*)process flow:(NEFilterSocketFlow*)flow;

//whether paused flows need a fresh root lookup
-(BOOL)hasActiveStrictRules;

//disable (or re-enable)
-(BOOL)toggleRule:(NSString*)key rule:(NSString*)uuid state:(NSNumber*)state;

//delete rule
-(BOOL)delete:(NSString*)key rule:(NSString*)uuid;

//save
-(BOOL)save;

//import rules
-(BOOL)import:(NSData*)rules userOnly:(BOOL)userOnly;

//number of rules for a given key
-(NSUInteger)ruleCountForKey:(NSString*)key;

//add an (external) path to an item's paths
-(void)addPath:(NSString*)path forKey:(NSString*)key;

//cleanup rules
-(NSUInteger)cleanup:(BOOL)full;

@end

#endif /* Rules_h */
