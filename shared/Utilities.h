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

//build an array of processes ancestry
// ->start with process and go 'back' till initial ancestor
NSMutableArray* generateProcessHierarchy(pid_t pid);

//give path to app
// ->get full path to its binary
NSString* getAppBinary(NSString* appPath);

//get app's version
// ->extracted from Info.plist
NSString* getAppVersion();

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
NSMutableArray* getProcessIDs(NSString* processPath, uid_t userID);

//get an icon for a process
// ->for apps, this will be app's icon, otherwise just a standard system one
NSImage* getIconForProcess(NSString* path);

//wait until a window is non nil
// ->then make it modal
void makeModal(NSWindowController* windowController);

//find a process by name
pid_t findProcess(NSString* processName);

//hash a file (sha1)
NSMutableString* hashFile(NSString* filePath);

//convert IP addr to (ns)string
NSString* convertIPAddr(unsigned char* ipAddr, __uint8_t socketFamily);

//convert socket numeric address to (ns)string
NSString* convertSocketAddr(struct sockaddr* socket);

//check if an instance of an app is already running
BOOL isAppRunning(NSString* bundleID);

//extract a DNS url
// per spec, format is: [len]bytes[len][bytes]0x0
NSMutableString* extractDNSURL(unsigned char* dnsData, unsigned char* dnsDataEnd);

#endif
