//
//  file: Utilities.h
//  project: lulu (shared)
//  description: various helper/utility functions (header)
//
//  created by Patrick Wardle
//  copyright (c) 2017 Objective-See. All rights reserved.
//

#ifndef Utilities_h
#define Utilities_h

#import <AppKit/AppKit.h>
#import <Foundation/Foundation.h>

/* FUNCTIONS */

//init crash reporting
void initCrashReporting(void);

//give path to app
// ->get full path to its binary
NSString* getAppBinary(NSString* appPath);

//get path to (main) app
// login item is in app bundle, so parse up to get main app
NSString* getMainAppPath(void);

//get app's version
// ->extracted from Info.plist
NSString* getAppVersion(void);

//find 'top-level' app of binary
// useful to determine if binary (or other app) is embedded in a 'parent' app bundle
NSString* topLevelApp(NSString* binaryPath);

//verify that an app bundle is
// a) signed
// b) signed with signing auth
OSStatus verifyApp(NSString* path, NSString* signingAuth);

//check if process is alive
BOOL isProcessAlive(pid_t processID);

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
// ->either via app bundle, or path
NSString* getProcessName(NSString* path);

//given a process path and user
// ->return array of all matching pids
NSMutableArray* getProcessIDs(NSString* processPath, int userID);

//given a pid, get its parent (ppid)
pid_t getParentID(int pid);

//enable/disable a menu
void toggleMenu(NSMenu* menu, BOOL shouldEnable);

//toggle login item
// either add (install) or remove (uninstall)
BOOL toggleLoginItem(NSURL* loginItem, int toggleFlag);

//get an icon for a process
// for apps, this will be app's icon, otherwise just a standard system one
NSImage* getIconForProcess(NSString* path);

//check if a kext is loaded
BOOL kextIsLoaded(NSString* kext);

//wait until kext is loaded
void wait4kext(NSString* kext);

//wait until a window is non nil
// then make it modal
void makeModal(NSWindowController* windowController);

//find a process by name
pid_t findProcess(NSString* processName);

//hash a file (sha256)
NSMutableString* hashFile(NSString* filePath);

//convert IP addr to (ns)string
NSString* convertIPAddr(unsigned char* ipAddr, __uint8_t socketFamily);

//convert socket numeric address to (ns)string
NSString* convertSocketAddr(struct sockaddr* socket);

//check if an instance of an app is already running
BOOL isAppRunning(NSString* bundleID);

//exec a process with args
// if 'shouldWait' is set, wait and return stdout/in and termination status
NSMutableDictionary* execTask(NSString* binaryPath, NSArray* arguments, BOOL shouldWait, BOOL grabOutput);

//extract a DNS url
// per spec, format is: [len]bytes[len][bytes]0x0
NSMutableString* extractDNSURL(unsigned char* dnsData, unsigned char* dnsDataEnd);

//determine what CS flags to use
// for massive bundles, won't validate resources, etc...
SecCSFlags determineCSFlags(NSString* path, NSBundle* bundle);

//loads a framework
// note: assumes is in 'Framework' dir
NSBundle* loadFramework(NSString* name);

//restart
void restart(void);

#endif
