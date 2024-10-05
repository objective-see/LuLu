//
//  BlockOrAllowList.h
//  Extension
//
//  Created by Patrick Wardle on 11/6/20.
//  Copyright © 2020 Objective-See. All rights reserved.
//

@import Cocoa;
@import OSLog;
@import NetworkExtension;

NS_ASSUME_NONNULL_BEGIN

@interface BlockOrAllowList : NSObject

/* PROPERTIES */

//path
@property(nonatomic, retain)NSString* path;

//block list
@property(nonatomic, retain)NSMutableArray* items;

//modification time
@property(nonatomic, retain)NSDate* lastModified;


/* METHODS */

//init
// with a path
-(id)init:(NSString*)path;

//(re)load from disk
-(void)load:(NSString*)path;

//should reload
// checks file modification time
-(BOOL)shouldReload;

//check if flow matches item on block list
-(BOOL)isMatch:(NEFilterSocketFlow*)flow;

@end

NS_ASSUME_NONNULL_END
