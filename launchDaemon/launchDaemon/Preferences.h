//
//  Preferences.h
//  launchDaemon
//
//  Created by Patrick Wardle on 2/22/18.
//  Copyright © 2018 Objective-See. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface Preferences : NSObject

/* PROPERTIES */

//preferences
@property(nonatomic, retain)NSMutableDictionary* preferences;

/* METHODS */

//load prefs from disk
-(BOOL)load;

//update prefs
// saves and handles logic for specific prefs
-(BOOL)update:(NSDictionary*)updates;

@end
