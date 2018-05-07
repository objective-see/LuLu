//
//  file: Baseline.h
//  project: lulu (launch daemon)
//  description: enumeration/processing of (pre)installed applications (header)
//
//  created by Patrick Wardle
//  copyright (c) 2018 Objective-See. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface Baseline : NSObject

/* PROPERTIES */

//pre-installed 3rd-party apps
@property(nonatomic, retain)NSMutableDictionary* preInstalledApps;

/* METHODS */

//invoke system profiler to get installed apps
// then process each, saving info about 3rd-party ones
-(BOOL)processAppData:(NSString*)path;

//load (pre)installed apps from file
-(BOOL)load;

//determine if a binary was installed before lulu
// checks if path is in list and hash/signing ID matches
-(BOOL)wasInstalled:(Binary*)binary;

//determine if a binary has parent installed before lulu
// checks if path is in list and hash/signing ID matches
-(BOOL)wasParentInstalled:(Binary*)childBinary;

//remove preinstalled app
// when user deletes rule, also should delete from saved plist
//-(BOOL)removeItem:(NSString*)path;

@end
