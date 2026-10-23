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

#import "consts.h"

@interface Update : NSObject

//check for an update
// stable channel: products.json (website), latest channel: GitHub's latest release
// will invoke completion handler (on main thread) w/ result, version, and URL (for the user to visit)
-(void)checkForUpdate:(UpdateChannel)channel completionHandler:(void (^)(NSUInteger result, NSString* latestVersion, NSString* url))completionHandler;

@end


#endif /* Update_h */
