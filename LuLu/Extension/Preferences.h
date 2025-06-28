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
-(BOOL)update:(NSDictionary*)updates replace:(BOOL)replace;

//save to disk
-(BOOL)save;

//get current profile
// this is saved in the default preferences (and may be nil)
-(NSString*)getCurrentProfile;

//set current profile
// this is saved in the default preferences (and may be nil)
-(void)setCurrentProfile:(NSString*)profilePath;

@end
