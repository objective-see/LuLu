//
//  Extension.h
//  LuLu
//
//  Created by Patrick Wardle on 9/11/20.
//  Copyright (c) 2020 Objective-See. All rights reserved.
//

@import OSLog;
@import Foundation;
@import NetworkExtension;
@import SystemExtensions;

typedef void(^replyBlockType)(BOOL);

@interface Extension : NSObject <OSSystemExtensionRequestDelegate>

/* PROPERTIES */

//action
@property NSUInteger requestedAction;

//reply
@property(nonatomic, copy)replyBlockType replyBlock;


/* METHODS */

//submit request to toggle extension
-(void)toggleExtension:(NSUInteger)action reply:(replyBlockType)reply;

//check if extension is running
-(BOOL)isExtensionRunning;

//activate/deactive network extension
-(BOOL)toggleNetworkExtension:(NSUInteger)action;

//get network extension's status
-(BOOL)isNetworkExtensionEnabled;

@end

