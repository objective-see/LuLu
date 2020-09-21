//
//  file: Rules.h
//  project: BlockBlock (launch daemon)
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


@interface Rules : NSObject
{
    
}

/* PROPERTIES */

//rules
@property(nonatomic, retain)NSMutableDictionary* rules;

//xpc client for talking to login item
@property(nonatomic, retain)XPCUserClient* xpcUserClient;


/* METHODS */

//prepare
// first time? generate defaults rules
// upgrade (v1.0)? convert to new format
-(BOOL)prepare;

//load from disk
-(BOOL)load;

//add a rule
-(BOOL)add:(Rule*)rule save:(BOOL)save;

//find (matching) rule
-(Rule*)find:(Process*)process flow:(NEFilterSocketFlow*)flow;

//delete rule
-(BOOL)delete:(NSString*)key rule:(NSString*)uuid;

@end


#endif /* Rules_h */
