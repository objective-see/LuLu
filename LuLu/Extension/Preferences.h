//
//  Preferences.h
//  launchDaemon
//
//  Created by Patrick Wardle on 2/22/18.
//  Copyright (c) 2018 Objective-See. All rights reserved.
//

@import OSLog;
@import Foundation;

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

//save to disk
-(BOOL)save;

@end
