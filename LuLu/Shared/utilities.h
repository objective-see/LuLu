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

@import AppKit;
@import Foundation;

/* FUNCTIONS */

//give path to app
// get full path to its binary
NSString* getAppBinary(NSString* appPath);

//get app's version
// extracted from Info.plist
NSString* getAppVersion(void);

//get (true) parent
NSDictionary* getRealParent(pid_t pid);

//get name of logged in user
NSString* getConsoleUser(void);

//given a path to binary
// parse it back up to find app's bundle
NSBundle* findAppBundle(NSString* binaryPath);

//get process's path
NSString* getProcessPath(pid_t pid);

//get process name
// either via app bundle, or path
NSString* getProcessName(pid_t pid, NSString* path);

//get current working dir
NSString* getProcessCWD(pid_t pid);

//given a process path and user
// return array of all matching pids
NSMutableArray* getProcessIDs(NSString* processPath, int userID);

//get parent pid
pid_t getParent(int pid);

//enable/disable a menu
void toggleMenu(NSMenu* menu, BOOL shouldEnable);

//toggle login item
// either add (install) or remove (uninstall)
BOOL toggleLoginItem(NSURL* loginItem, int toggleFlag);

//get an icon for a process
// for apps, this will be app's icon, otherwise just a standard system one
NSImage* getIconForProcess(NSString* path);

//wait until a window is non nil
// then make it modal
void makeModal(NSWindowController* windowController);

//find a process by name
pid_t findProcess(NSString* processName);

//hash a file (sha256)
NSMutableString* hashFile(NSString* filePath);

//loads a framework
// note: assumes is in 'Framework' dir
NSBundle* loadFramework(NSString* name);

//check if (full) dark mode
// meaning, Mojave+ and dark mode enabled
BOOL isDarkMode(void);

//check if something is nil
// if so, return a default ('unknown') value
NSString* valueForStringItem(NSString* item);

//grab date added
// extracted via 'kMDItemDateAdded'
NSDate* dateAdded(NSString* file);

//show an alert
NSModalResponse showAlert(NSString* messageText, NSString* informativeText, NSArray* buttons);

//get audit token for pid
NSData* tokenForPid(pid_t pid);

//given an ip address
// reverse resolves it
NSArray* resolveAddress(NSString * address);

//process alive?
BOOL isAlive(pid_t processID);

//check if app is an simulator app
// for now check 'iPhoneSimulator' and 'AppleTVSimulator'
BOOL isSimulatorApp(NSString* path);

//was app launched by user
BOOL launchedByUser(void);

//fade out a window
void fadeOut(NSWindow* window, float duration);

//matches CS info?
BOOL matchesCSInfo(NSDictionary* csInfo_1, NSDictionary* csInfo_2);

#endif
