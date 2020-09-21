//
//  file: Update.h
//  project: lulu (shared)
//  description: checks for new versions of LuLu (header)
//
//  created by Patrick Wardle
//  copyright (c) 2017 Objective-See. All rights reserved.
//


#ifndef Update_h
#define Update_h

@import Cocoa;
@import Foundation;

@interface Update : NSObject

//check for an update
// will invoke app delegate method to update UI when check completes
-(void)checkForUpdate:(void (^)(NSUInteger result, NSString* latestVersion))completionHandler;

@end


#endif /* Update_h */
