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

//give path to bundle
// get full path to its binary
NSString* getBundleExecutable(NSString* appPath);

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

//find all processes by name
NSMutableArray* findProcesses(NSString* processName);

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
NSModalResponse showAlert(NSAlertStyle style, NSString* messageText, NSString* informativeText, NSArray* buttons);

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

//escape string
NSString* toEscapedJSON(NSString* input);

//convert date to absolute
NSDate* absoluteDate(NSDate* date);

//generate list of ancestors
NSMutableArray* generateProcessHierarchy(pid_t child);

//is process on internal drive?
BOOL isInternalProcess(NSString *path);

//parse a CIDR ("a.b.c.d/n" or IPv6) or range ("ipA - ipB") into numeric bounds
// on success: returns YES, sets *family (AF_INET|AF_INET6), fills lo/hi (16-byte buffers, network order), sets *length (4|16)
BOOL parseAddressRange(NSString* spec, int* family, uint8_t* lo, uint8_t* hi, int* length);

//check if a numeric IP string falls within [lo, hi] (inclusive) for the given family
BOOL addressInRange(NSString* address, int family, const uint8_t* lo, const uint8_t* hi, int length);

//is a string a valid CIDR or IP range?
BOOL isAddressRange(NSString* spec);

//convert a simple glob (using '*' wildcards) to an anchored regular expression
// e.g. '85.140.*.*' -> '^85\.140\..*\..*$' : literal chars are regex-escaped, '*' -> '.*', anchored
NSString* regexFromGlob(NSString* glob);

//check if a binary was built for a simulator platform
// via 'LC_BUILD_VERSION' load command (in any slice); always NO pre-macOS 13
BOOL isSimulatorBinary(NSString* path);

#endif
