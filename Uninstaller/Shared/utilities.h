//
//  file: utilities.h
//  project: lulu (shared)
//  description: various helper/utility functions (header)
//
//  created by Patrick Wardle
//  copyright (c) 2017 Objective-See. All rights reserved.
//

#ifndef Utilities_h
#define Utilities_h

@import OSLog;
@import Foundation;

/* FUNCTIONS */

//verify that an app bundle is
// a) signed
// b) signed with signing auth
OSStatus verifyApp(NSString* path, NSString* signingAuth);

//set dir's|file's group/owner
BOOL setFileOwner(NSString* path, NSNumber* groupID, NSNumber* ownerID, BOOL recursive);

//set permissions for file
BOOL setFilePermissions(NSString* file, int permissions, BOOL recursive);

//given a path to binary
// parse it back up to find app's bundle
NSBundle* findAppBundle(NSString* binaryPath);

//get process's path
NSString* getProcessPath(pid_t pid);

//get process name
// either via app bundle, or path
NSString* getProcessName(NSString* path);

//given a process path and user
// return array of all matching pids
NSMutableArray* getProcessIDs(NSString* processPath, int userID);

//exec a process with args
// if 'shouldWait' is set, wait and return stdout/in and termination status
NSMutableDictionary* execTask(NSString* binaryPath, NSArray* arguments, BOOL shouldWait, BOOL grabOutput);

//restart
void restart(void);

//check if (full) dark mode
// meaning, Mojave+ and dark mode enabled
BOOL isDarkMode(void);

//get (true) parent
NSDictionary* getRealParent(pid_t pid);

#endif
