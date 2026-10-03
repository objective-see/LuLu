//
//  FilterDataProvider.h
//  LuLu
//
//  Created by Patrick Wardle on 8/1/20.
//  Copyright (c) 2020 Objective-See. All rights reserved.
//

#import <bsm/libbsm.h>

@import OSLog;
@import NetworkExtension;

#import "GrayList.h"

@interface FilterDataProvider : NEFilterDataProvider

/* PROPERTIES */

//(process) cache
@property(atomic, retain)NSCache* cache;

//graylist obj
@property(nonatomic, retain)GrayList* grayList;

//related flows
@property(nonatomic, retain)NSMutableDictionary* relatedFlows;

//timer to reap flows whose process has terminated
@property(nonatomic, strong)dispatch_source_t reapTimer;

/* METHODS */

//get best hostname from flow
// prioritizes domain names over IP addresses
-(NSString*)getBestHostnameFromFlow:(NEFilterSocketFlow*)flow;

//resume flows + drop their key(s)
// pass a (process) key to resume just that one; pass nil to resume all keys
-(void)resumeFlowsForKey:(NSString*)key verdict:(NEFilterNewFlowVerdict*)verdict;

//remove a single (specific) flow from a key's queue
-(void)removeRelatedFlow:(NEFilterSocketFlow*)flow forKey:(NSString*)key;

//reap flows whose process has terminated
// invoked periodically (timer) so paused flows of dead processes aren't held forever
-(void)reapDeadFlows;

//delegate (e.g. mDNSResponder) that created flow on behalf of its (exited) app
-(NSData* _Nullable)delegateToken:(NEFilterFlow* _Nonnull)flow;
-(Process* _Nullable)delegateProcess:(NEFilterFlow* _Nonnull)flow;

@end
