//
//  file: XPCProtocol.h
//  project: lulu (shared)
//  description: protocol for talking to the daemon
//
//  created by Patrick Wardle
//  copyright (c) 2017 Objective-See. All rights reserved.
//

#ifndef userCommsInterface_h
#define userCommsInterface_h

@import Foundation;

@protocol XPCProtocol

//uninstall
-(void)uninstall:(NSString*)app full:(BOOL)full reply:(void (^)(NSNumber*))reply;

//cleanup
// remove self
-(void)cleanup:(void (^)(NSNumber*))reply;

@end

#endif
