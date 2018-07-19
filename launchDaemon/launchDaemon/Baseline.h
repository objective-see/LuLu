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

//determine if a proc's binary was installed before lulu
// checks if path is in list and hash/signing ID matches
-(BOOL)wasInstalled:(Binary*)binary signingInfo:(NSDictionary*)signingInfo;

//determine if a child process has parent installed before lulu
// finds parent, and validates signing info and signing auths is #samesame!
-(BOOL)wasParentInstalled:(Process*)childProcess;

//remove preinstalled app
// when user deletes rule, also should delete from saved plist
//-(BOOL)removeItem:(NSString*)path;

@end
