//
//  file: utilities.m
//  project: lulu (shared)
//  description: various helper/utility functions
//
//  created by Patrick Wardle
//  copyright (c) 2017 Objective-See. All rights reserved.
//

#import "consts.h"
#import "utilities.h"
#import "AppDelegate.h"

@import OSLog;
@import Carbon;
@import Security;
@import Foundation;
@import CommonCrypto;
@import SystemConfiguration;

#import <netdb.h>
#import <dlfcn.h>
#import <signal.h>
#import <unistd.h>
#import <libproc.h>
#import <sys/stat.h>
#import <arpa/inet.h>
#import <sys/socket.h>
#import <sys/sysctl.h>

/* GLOBALS */

//log handle
extern os_log_t logHandle;

//get app's version
// extracted from Info.plist
NSString* getAppVersion(void)
{
    //read and return 'CFBundleVersion' from bundle
    return [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleVersion"];
}

//give path to bundle
// get full path to its binary
NSString* getBundleExecutable(NSString* appPath)
{
    //binary path
    NSString* binaryPath = nil;
    
    //app bundle
    NSBundle* appBundle = nil;
    
    //load app bundle
    appBundle = [NSBundle bundleWithPath:appPath];
    if(nil == appBundle)
    {
        //err msg
        os_log_error(logHandle, "ERROR: failed to load app bundle for %{public}@", appPath);
        
        //bail
        goto bail;
    }
    
    //extract executable
    binaryPath = [appBundle.executablePath stringByResolvingSymlinksInPath];
    
bail:
    
    return binaryPath;
}

#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wdeprecated-declarations"

//get (true) parent
NSDictionary* getRealParent(pid_t pid)
{
    //process info
    NSDictionary* processInfo = nil;
    
    //process serial number
    ProcessSerialNumber psn = {0, kNoProcess};
    
    //(parent) process serial number
    ProcessSerialNumber ppsn = {0, kNoProcess};
    
    //get process serial number from pid
    if(noErr != GetProcessForPID(pid, &psn))
    {
        //err
        goto bail;
    }
    
    //get process (carbon) info
    processInfo = CFBridgingRelease(ProcessInformationCopyDictionary(&psn, (UInt32)kProcessDictionaryIncludeAllInformationMask));
    if(nil == processInfo)
    {
        //err
        goto bail;
    }
    
    //extract/convert parent ppsn
    ppsn.lowLongOfPSN =  [processInfo[@"ParentPSN"] longLongValue] & 0x00000000FFFFFFFFLL;
    ppsn.highLongOfPSN = ([processInfo[@"ParentPSN"] longLongValue] >> 32) & 0x00000000FFFFFFFFLL;
    
    //get parent process (carbon) info
    processInfo = CFBridgingRelease(ProcessInformationCopyDictionary(&ppsn, (UInt32)kProcessDictionaryIncludeAllInformationMask));
    if(nil == processInfo)
    {
        //err
        goto bail;
    }
    
bail:
    
    return processInfo;
}

#pragma GCC diagnostic pop

//generate list of ancestors
NSMutableArray* generateProcessHierarchy(pid_t child)
{
    //ancestors
    NSMutableArray* ancestors = nil;
    
    //current process id
    pid_t currentPID = -1;
    
    //current path
    NSString* currentPath = nil;
    
    //current name
    NSString* currentName = nil;
    
    //parent pid
    pid_t parentPID = -1;
    
    //rpid function
    static pid_t (*getRPID)(pid_t pid) = NULL;
    
    //token
    static dispatch_once_t onceToken = 0;
    
    //init
    ancestors = [NSMutableArray array];
    
    //only once
    // init requirements
    dispatch_once(&onceToken, ^{
        
        //get function pointer
        getRPID = dlsym(RTLD_NEXT, "responsibility_get_pid_responsible_for_pid");
        
    });
    
    //start w/ self
    currentPID = child;
    
    do {
        
        //get path
        if(nil == (currentPath = getProcessPath(currentPID)))
        {
            //default
            currentPath = NSLocalizedString(@"unknown", @"unknown");
        }
        
        //get name
        currentName = getProcessName(0, currentPath);
        if(nil == currentName)
        {
            //default
            currentName = NSLocalizedString(@"unknown", @"unknown");
        }
        
        //add
        [ancestors insertObject:[@{KEY_PROCESS_ID:[NSNumber numberWithInt:currentPID], KEY_PROCESS_PATH:currentPath, KEY_PROCESS_NAME:currentName} mutableCopy] atIndex:0];
        
        //for apps (and if we're not root)
        // try application services pid via serial
        if(0 != getuid())
        {
            //real parent via serial
            parentPID = [getRealParent(currentPID)[@"pid"] intValue];
        }
        
        //not found
        // try via responsible pid
        if(0 == parentPID)
        {
            //for parent
            // first try via rPID
            if(NULL != getRPID)
            {
                //get rpid
                parentPID = getRPID(currentPID);
            }
        }
        
        //couldn't find/get rPID?
        // default back to using standard method
        if( (parentPID <= 0) ||
            (currentPID == parentPID) )
        {
            //get parent pid
            parentPID = getParent(currentPID);
        }
        
        //done?
        if( (parentPID <= 0) ||
            (currentPID == parentPID) )
        {
            //bail
            break;
        }
        
        //update
        currentPID = parentPID;
        
    } while(YES);
    
    //now, will all items added
    // add each item's index for UI purposes
    for(NSUInteger i = 0; i < ancestors.count; i++)
    {
        //set index
        ancestors[i][KEY_INDEX] = [NSNumber numberWithInteger:i];
    }

    return ancestors;
}

//get name of logged in user
NSString* getConsoleUser(void)
{
    //copy/return user
    return CFBridgingRelease(SCDynamicStoreCopyConsoleUser(NULL, NULL, NULL));
}

//get process name
// either via app bundle, or path
NSString* getProcessName(pid_t pid, NSString* path)
{
    //status
    int status = -1;
    
    //process name
    NSString* processName = nil;
    
    //app bundle
    NSBundle* appBundle = nil;
    
    //buffer for process path
    char nameBuffer[PROC_PIDPATHINFO_MAXSIZE] = {0};
    
    //clear
    memset(nameBuffer, 0x0, sizeof(nameBuffer));
    
    //via pid?
    if(pid != 0)
    {
        //get name
        status = proc_name(pid, &nameBuffer, sizeof(nameBuffer));
        if(status >= 0)
        {
            //init task's name
            processName = [NSString stringWithUTF8String:nameBuffer];
        }
    }
    
    //(still) nil
    // try via app bundle
    if(nil == processName)
    {
        //find app bundle
        appBundle = findAppBundle(path);
        if(nil != appBundle)
        {
            //grab name from app's bundle
            processName = [appBundle infoDictionary][@"CFBundleName"];
        }
    }
    
    //(still) nil
    // just grab from path
    if(nil == processName)
    {
        //from path
        processName = [path lastPathComponent];
    }
    
    return processName;
}

//given a path to binary
// parse it back up to find app's bundle
NSBundle* findAppBundle(NSString* path)
{
    //app's bundle
    NSBundle* appBundle = nil;
    
    //standarized path
    NSString* standardedPath = nil;
    
    //app's path
    NSString* appPath = nil;
    
    //standardize path
    standardedPath = [[path stringByStandardizingPath] stringByResolvingSymlinksInPath];
    
    //first just try full path
    appPath = standardedPath;
    
    //try to find the app's bundle
    do
    {
        //try to load app's bundle
        appBundle = [NSBundle bundleWithPath:appPath];
        
        //was an app passed in?
        if(YES == [appBundle.bundlePath isEqualToString:standardedPath])
        {
            //all done
            break;
        }
        
        //check for match
        // binary path's match
        if( (nil != appBundle) &&
            (YES == [appBundle.executablePath isEqualToString:standardedPath]))
        {
            //all done
            break;
        }
        
        //unset
        appBundle = nil;
        
        //remove last part
        // will try this next
        appPath = [appPath stringByDeletingLastPathComponent];
        
    //scan until we get to root
    // of course, loop will exit if app info dictionary is found/loaded
    } while( (nil != appPath) &&
             (YES != [appPath isEqualToString:@"/"]) &&
             (YES != [appPath isEqualToString:@""]) );
    
    return appBundle;
}

//get process's path
NSString* getProcessPath(pid_t pid)
{
    //task path
    NSString* processPath = nil;
    
    //cwd
    NSString* cwd = nil;
    
    //buffer for process path
    char pathBuffer[PROC_PIDPATHINFO_MAXSIZE] = {0};
    
    //status
    int status = -1;
    
    //'management info base' array
    int mib[3] = {0};
    
    //system's size for max args
    unsigned long systemMaxArgs = 0;
    
    //process's args
    char* taskArgs = NULL;
    
    //# of args
    int numberOfArgs = 0;
    
    //size of buffers, etc
    size_t size = 0;
    
    //reset buffer
    memset(pathBuffer, 0x0, PROC_PIDPATHINFO_MAXSIZE);
    
    //first attempt to get path via 'proc_pidpath()'
    status = proc_pidpath(pid, pathBuffer, sizeof(pathBuffer));
    if(0 != status)
    {
        //init task's name
        processPath = [NSString stringWithUTF8String:pathBuffer];
    }
    //otherwise
    // try via task's args ('KERN_PROCARGS2')
    else
    {
        //err msg
        os_log_error(logHandle, "ERROR: for process %d, 'proc_pidpath' failed with %d (errno: %d)", pid, status, errno);
        
        //init mib
        // want system's size for max args
        mib[0] = CTL_KERN;
        mib[1] = KERN_ARGMAX;
        
        //set size
        size = sizeof(systemMaxArgs);
        
        //get system's size for max args
        if(-1 == sysctl(mib, 2, &systemMaxArgs, &size, NULL, 0))
        {
            //bail
            goto bail;
        }
        
        //alloc space for args
        taskArgs = malloc(systemMaxArgs);
        if(NULL == taskArgs)
        {
            //bail
            goto bail;
        }
        
        //init mib
        // want process args
        mib[0] = CTL_KERN;
        mib[1] = KERN_PROCARGS2;
        mib[2] = pid;
        
        //set size
        size = (size_t)systemMaxArgs;
        
        //get process's args
        if(-1 == sysctl(mib, 3, taskArgs, &size, NULL, 0))
        {
            //bail
            goto bail;
        }
        
        //sanity check
        // ensure buffer is somewhat sane
        if(size <= sizeof(int))
        {
            //bail
            goto bail;
        }
        
        //extract number of args
        memcpy(&numberOfArgs, taskArgs, sizeof(numberOfArgs));
        
        //extract task's name
        // follows # of args (int) and is NULL-terminated
        processPath = [NSString stringWithUTF8String:taskArgs + sizeof(int)];
        
        //short path?
        // get cwd + to append
        if(YES == [processPath hasPrefix:@"./"])
        {
            //chop ./
            processPath = [processPath substringWithRange:NSMakeRange(2, [processPath length]-2)];
            cwd = getProcessCWD(pid);
            if(nil != cwd)
            {
                //append
                processPath = [cwd stringByAppendingPathComponent:processPath];
            }
        }
    }
    
bail:
    
    //free process args
    if(NULL != taskArgs)
    {
        //free
        free(taskArgs);
        taskArgs = NULL;
    }
    
    return processPath;
}

//get current working dir
NSString* getProcessCWD(pid_t pid)
{
    //cwd
    NSString* directory = nil;
    
    //status
    int status = -1;
    
    //path info
    struct proc_vnodepathinfo vpi = {0,};
    
    //init
    memset(&vpi, 0x0, sizeof(vpi));
    
    //get proc's cwd, via PROC_PIDVNODEPATHINFO
    status = proc_pidinfo(pid, PROC_PIDVNODEPATHINFO, 0, &vpi, sizeof(vpi));
    if(status > 0)
    {
        //convert to string
        directory = [NSString stringWithUTF8String:vpi.pvi_cdir.vip_path];
    }
    
    return directory;
}

//given a process path and user
// return array of all matching pids
NSMutableArray* getProcessIDs(NSString* processPath, int userID)
{
    //status
    int status = -1;
    
    //process IDs
    NSMutableArray* processIDs = nil;
    
    //# of procs
    int numberOfProcesses = 0;
        
    //array of pids
    pid_t* pids = NULL;
    
    //process info struct
    struct kinfo_proc procInfo = {0};
    
    //size of struct
    size_t procInfoSize = sizeof(procInfo);
    
    //mib
    int mib[4] = {CTL_KERN, KERN_PROC, KERN_PROC_PID, -1};
    
    //clear buffer
    memset(&procInfo, 0x0, procInfoSize);
    
    //get # of procs
    numberOfProcesses = proc_listallpids(NULL, 0);
    if(-1 == numberOfProcesses)
    {
        //bail
        goto bail;
    }
    
    //alloc buffer for pids
    pids = calloc((unsigned long)numberOfProcesses, sizeof(pid_t));
    
    //alloc
    processIDs = [NSMutableArray array];
    
    //get list of pids
    status = proc_listallpids(pids, numberOfProcesses * (int)sizeof(pid_t));
    if(status < 0)
    {
        //bail
        goto bail;
    }
        
    //iterate over all pids
    // get name for each process
    for(int i = 0; i < (int)numberOfProcesses; i++)
    {
        //skip blank pids
        if(0 == pids[i])
        {
            //skip
            continue;
        }
        
        //skip if path doesn't match
        if(YES != [processPath isEqualToString:getProcessPath(pids[i])])
        {
            //next
            continue;
        }
        
        //need to also match on user?
        // caller can pass in -1 to skip this check
        if(-1 != userID)
        {
            //init mib
            mib[0x3] = pids[i];
            
            //make syscall to get proc info for user
            if( (0 != sysctl(mib, 0x4, &procInfo, &procInfoSize, NULL, 0)) ||
                (0 == procInfoSize) )
            {
                //skip
                continue;
            }

            //skip if user id doesn't match
            if(userID != (int)procInfo.kp_eproc.e_ucred.cr_uid)
            {
                //skip
                continue;
            }
        }
        
        //got match
        // add to list
        [processIDs addObject:[NSNumber numberWithInt:pids[i]]];
    }
    
bail:
        
    //free buffer
    if(NULL != pids)
    {
        //free
        free(pids);
        
        //reset
        pids = NULL;
    }
    
    return processIDs;
}

//enable/disable a menu
void toggleMenu(NSMenu* menu, BOOL shouldEnable)
{
    //disable autoenable
    menu.autoenablesItems = NO;
    
    //iterate over
    // set state of each item
    for(NSMenuItem* item in menu.itemArray)
    {
        //set state
        item.enabled = shouldEnable;
    }
    
    return;
}

//get an icon for a process
// for apps (and their helpers), this will be app's icon, otherwise just a standard system one
NSImage* getIconForProcess(NSString* item)
{
    //icon's file name
    NSString* iconFile = nil;
    
    //icon's path
    NSString* iconPath = nil;
    
    //icon's path extension
    NSString* iconExtension = nil;
    
    //icon
    NSImage* icon = nil;
    
    //system's document icon
    static NSImage* documentIcon = nil;
    
    //bundle
    NSBundle* appBundle = nil;
    
    //path
    // might change if we find a parent
    NSString* path = item;
    
    //invalid path?
    // grab a default icon and bail
    if(YES != [NSFileManager.defaultManager fileExistsAtPath:path])
    {
        //set icon to system 'application' icon
        icon = [[NSWorkspace sharedWorkspace]
                iconForFileType: NSFileTypeForHFSTypeCode(kGenericApplicationIcon)];
        
        //set size to 64 @2x
        [icon setSize:NSMakeSize(128, 128)];
   
        //bail
        goto bail;
    }
    
    //helper?
    if( [path containsString:@"Helper"] &&
        [path.pathExtension isEqualToString:@"app"])
    {
        //dbg msg
        os_log_debug(logHandle, "%{public}@ appears to be a helper app", path);
        
        NSBundle* bundle = [NSBundle bundleWithPath:path];
        NSString* iconFile = [bundle objectForInfoDictionaryKey:@"CFBundleIconFile"];
        NSString* iconName = [bundle objectForInfoDictionaryKey:@"CFBundleIconName"];
        
        //no icon? find parent
        if(!(iconFile.length || iconName.length))
        {
            NSString *currentPath = path;
            
            //find parent
            while(currentPath.length > 1) {
                
                currentPath = [currentPath stringByDeletingLastPathComponent];
                
                if([currentPath.pathExtension isEqualToString:@"app"] && ![currentPath containsString:@"Helper"]) {
                    
                    //update
                    path = currentPath;
                    
                    //dbg msg
                    os_log_debug(logHandle, "will use parents path for icon: %{public}@", path);
                    
                    break;
                }
            }
        }
    }
    
    //first try grab bundle
    // then extact icon from this
    appBundle = findAppBundle(path);
    if(nil != appBundle)
    {
        //extract icon
        icon = [NSWorkspace.sharedWorkspace iconForFile:appBundle.bundlePath];
        if(nil != icon)
        {
            //done!
            goto bail;
        }
        
        //get file
        iconFile = appBundle.infoDictionary[@"CFBundleIconFile"];
        
        //get path extension
        iconExtension = [iconFile pathExtension];
        
        //if its blank (i.e. not specified)
        // go with 'icns'
        if(YES == [iconExtension isEqualTo:@""])
        {
            //set type
            iconExtension = @"icns";
        }
        
        //set full path
        iconPath = [appBundle pathForResource:[iconFile stringByDeletingPathExtension] ofType:iconExtension];
        
        //load it
        icon = [[NSImage alloc] initWithContentsOfFile:iconPath];
    }
    
    //process is not an app or couldn't get icon
    // try to get it via shared workspace
    if( (nil == appBundle) ||
        (nil == icon) )
    {
        //extract icon
        icon = [[NSWorkspace sharedWorkspace] iconForFile:path];
        
        //load system document icon
        // static var, so only load once
        if(nil == documentIcon)
        {
            //load
            documentIcon = [[NSWorkspace sharedWorkspace] iconForFileType:
                            NSFileTypeForHFSTypeCode(kGenericDocumentIcon)];
        }
        
        //if 'iconForFile' method doesn't find and icon, it returns the system 'document' icon
        // the system 'application' icon seems more applicable, so use that here...
        if(YES == [icon isEqual:documentIcon])
        {
            //set icon to system 'application' icon
            icon = [[NSWorkspace sharedWorkspace]
                    iconForFileType: NSFileTypeForHFSTypeCode(kGenericApplicationIcon)];
        }
        
        //'iconForFileType' returns small icons
        // so set size to 64 @2x
        [icon setSize:NSMakeSize(128, 128)];
    }
    
bail:
    
    return icon;
}

//wait till window non-nil
// then make that window modal
void makeModal(NSWindowController* windowController)
{
    //window
    __block NSWindow* window = nil;
    
    //wait till non-nil
    // then make window modal
    for(int i=0; i<20; i++)
    {
        //grab window
        dispatch_sync(dispatch_get_main_queue(), ^{
         
            //grab
            window = windowController.window;
            
        });
                      
        //nil?
        // nap
        if(nil == window)
        {
            //nap
            [NSThread sleepForTimeInterval:0.05f];
            
            //next
            continue;
        }
        
        //have window?
        // make it modal
        dispatch_sync(dispatch_get_main_queue(), ^{
            
            //modal
            [[NSApplication sharedApplication] runModalForWindow:windowController.window];
            
        });
        
        //done
        break;
    }
    
    return;
}

//find all processes by name
NSMutableArray* findProcesses(NSString* processName)
{
    //status
    int status = -1;
    
    //pids
    NSMutableArray* processes = nil;
    
    //# of procs
    int numberOfProcesses = 0;
    
    //array of pids
    pid_t* pids = NULL;
    
    //process path
    NSString* processPath = nil;
    
    //init
    processes = [NSMutableArray array];
    
    //get # of procs
    numberOfProcesses = proc_listpids(PROC_ALL_PIDS, 0, NULL, 0);
    if(-1 == numberOfProcesses)
    {
        //bail
        goto bail;
    }
    
    //alloc buffer for pids
    pids = calloc((unsigned long)numberOfProcesses, sizeof(pid_t));
    
    //get list of pids
    status = proc_listpids(PROC_ALL_PIDS, 0, pids, numberOfProcesses * (int)sizeof(pid_t));
    if(status < 0)
    {
        //bail
        goto bail;
    }
    
    //iterate over all pids
    // get name for each via helper function
    for(int i = 0; i < numberOfProcesses; ++i)
    {
        //skip blank pids
        if(0 == pids[i])
        {
            //skip
            continue;
        }
        
        //get path
        processPath = getProcessPath(pids[i]);
        if( (nil == processPath) ||
            (0 == processPath.length) )
        {
            //skip
            continue;
        }
        
        //no match?
        if(YES != [processPath.lastPathComponent isEqualToString:processName])
        {
            //skip
            continue;
        }
            
        //save
        [processes addObject:@{KEY_PROCESS_ID:[NSNumber numberWithInt:pids[i]], KEY_PATH:processPath}];
        
    }//all procs
    
bail:
    
    //free buffer
    if(NULL != pids)
    {
        //free
        free(pids);
        pids = NULL;
    }
    
    return processes;
}

//for login item enable/disable
// we use the launch services APIs, since replacements don't always work :(
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"

//toggle login item
// either add (install) or remove (uninstall)
BOOL toggleLoginItem(NSURL* loginItem, int toggleFlag)
{
    //flag
    BOOL wasToggled = NO;
    
    //status
    OSStatus status = !noErr;
    
    //login items ref
    LSSharedFileListRef loginItemsRef = NULL;
    
    //login item ref
    LSSharedFileListItemRef loginItemRef = NULL;
    
    //login items
    CFArrayRef loginItems = NULL;
    
    //current login item
    CFURLRef currentLoginItem = NULL;
    
    //get reference to login items
    loginItemsRef = LSSharedFileListCreate(NULL, kLSSharedFileListSessionLoginItems, NULL);
    
    //add (install)
    if(ACTION_INSTALL_FLAG == toggleFlag)
    {
        //dbg msg
        os_log_debug(logHandle, "adding login item: %{public}@", loginItem.path);
        
        //add
        loginItemRef = LSSharedFileListInsertItemURL(loginItemsRef, kLSSharedFileListItemLast, NULL, NULL, (__bridge CFURLRef)(loginItem), NULL, NULL);
        if(NULL != loginItemRef)
        {
            //dbg msg
            os_log_debug(logHandle, "login item added");
            
            //release
            CFRelease(loginItemRef);
            loginItemRef = NULL;
        }
        //failed
        else
        {
            //err msg
            os_log_error(logHandle, "ERROR: failed to add login item");
            
            //bail
            goto bail;
        }
        
        //happy
        wasToggled = YES;
    }
    //remove (uninstall)
    else
    {
        //dbg msg
        os_log_debug(logHandle, "removing login item: %{public}@", loginItem.path);
        
        //grab all login items
        loginItems = LSSharedFileListCopySnapshot(loginItemsRef, nil);
        
        //iterate over all login items
        // look for self(s), then remove it
        for(id item in (__bridge NSArray *)loginItems)
        {
            //get current login item
            currentLoginItem = LSSharedFileListItemCopyResolvedURL((__bridge LSSharedFileListItemRef)item, 0, NULL);
            if(NULL == currentLoginItem) continue;
            
            //current login item match self?
            if(YES == [(__bridge NSURL *)currentLoginItem isEqual:loginItem])
            {
                //dbg msg
                os_log_debug(logHandle, "found match");
                
                //remove
                if(noErr == (status = LSSharedFileListItemRemove(loginItemsRef, (__bridge LSSharedFileListItemRef)item)))
                {
                    //nap
                    // give some time for event to complete
                    [NSThread sleepForTimeInterval:1.0f];
                    
                    //dbg msg
                    os_log_debug(logHandle, "removed login item");
                    
                    //happy
                    wasToggled = YES;
                }
                else
                {
                    //err msg
                    os_log_error(logHandle, "ERROR: failed to remove login item (%x)", status);
                    
                    //keep trying though
                    // as might be multiple instances...
                }
            }
            
            //release
            CFRelease(currentLoginItem);
            currentLoginItem = NULL;
            
        }//all login items
        
    }//remove/uninstall
    
bail:
    
    //release login items
    if(NULL != loginItems)
    {
        //release
        CFRelease(loginItems);
        loginItems = NULL;
    }
    
    //release login ref
    if(NULL != loginItemsRef)
    {
        //release
        CFRelease(loginItemsRef);
        loginItemsRef = NULL;
    }
    
    return wasToggled;
}

//grab date added
// extracted via 'kMDItemDateAdded'
// or if that's NULL, then 'kMDItemFSCreationDate'
NSDate* dateAdded(NSString* file)
{
    //date added
    NSDate* date = nil;
    
    //item
    MDItemRef item = NULL;
    
    //attribute names
    CFArrayRef attributeNames = NULL;
    
    //attributes
    CFDictionaryRef attributes = NULL;
    
    //app bundle
    NSBundle* appBundle = nil;
    
    //dbg msg
    os_log_debug(logHandle, "extracting 'kMDItemDateAdded' for %{public}@", file);
    
    //try find an app bundle
    appBundle = findAppBundle(file);
    if(nil != appBundle)
    {
        //init item with app's path
        item = MDItemCreateWithURL(NULL, (__bridge CFURLRef)appBundle.bundleURL);
        if(NULL == item)
        {
            goto bail;
        }
    }
    //no app bundle
    // just use item/path as it
    else
    {
        //init item with path
        item = MDItemCreateWithURL(NULL, (__bridge CFURLRef)[NSURL fileURLWithPath:file]);
        if(NULL == item)
        {
            goto bail;
        }
    }
    
    //get attribute names
    attributeNames = MDItemCopyAttributeNames(item);
    if(NULL == attributeNames)
    {
        goto bail;
    }
    
    //get attributes
    attributes = MDItemCopyAttributes(item, attributeNames);
    if(NULL == attributes)
    {
        goto bail;
    }
    
    //grab date added
    date = CFBridgingRelease(MDItemCopyAttribute(item, kMDItemDateAdded));
    if(nil == date)
    {
        //dbg msg
        os_log_debug(logHandle, "'kMDItemDateAdded' is nil ...falling back to 'kMDItemFSCreationDate'");
        
        //grab date via 'kMDItemFSCreationDate'
        date = CFBridgingRelease(MDItemCopyAttribute(item, kMDItemFSCreationDate));
    }
    
    //dbg msg
    os_log_debug(logHandle, "extacted date, %{public}@, for %{public}@", date, file);

bail:
    
    //free attributes
    if(NULL != attributes)
    {
        CFRelease(attributes);
    }
    
    //free attribute names
    if(NULL != attributeNames)
    {
        CFRelease(attributeNames);
    }
    
    //free item
    if(NULL != item)
    {
        CFRelease(item);
    }
    
    return date;
}


#pragma clang diagnostic pop


//sha256
// as string
NSMutableString* hashFile(NSString* path) {
    
    NSData* contents = [NSData dataWithContentsOfFile:path];
    if (!contents)
    {
        os_log_error(logHandle, "ERROR: failed to read in %{public}@ for hashing", path);
        return nil;
    }
    
    unsigned char digest[CC_SHA256_DIGEST_LENGTH];
    CC_SHA256(contents.bytes, (CC_LONG)contents.length, digest);
    
    NSMutableString* hash = [NSMutableString stringWithCapacity:CC_SHA256_DIGEST_LENGTH * 2];
    for (int i = 0; i < CC_SHA256_DIGEST_LENGTH; i++) {
        [hash appendFormat:@"%02x", digest[i]];
    }
    
    return hash;
}

//get parent pid
pid_t getParent(int pid)
{
    //parent id
    pid_t parentID = -1;
    
    //kinfo_proc struct
    struct kinfo_proc processStruct;
    
    //size
    size_t procBufferSize = sizeof(processStruct);
    
    //mib
    const u_int mibLength = 4;
    
    //syscall result
    int sysctlResult = -1;
    
    //init mib
    int mib[mibLength] = {CTL_KERN, KERN_PROC, KERN_PROC_PID, pid};
    
    //clear buffer
    memset(&processStruct, 0x0, procBufferSize);
    
    //make syscall
    sysctlResult = sysctl(mib, mibLength, &processStruct, &procBufferSize, NULL, 0);
    
    //check if got ppid
    if( (noErr == sysctlResult) &&
        (0 != procBufferSize) )
    {
        //save ppid
        parentID = processStruct.kp_eproc.e_ppid;
        
        //dbg msg
        os_log_debug(logHandle, "extracted parent ID %d for process: %d", parentID, pid);
    }
    
    return parentID;
}


//loads a framework
// note: assumes it is in 'Framework' dir
NSBundle* loadFramework(NSString* name)
{
    //handle
    NSBundle* framework = nil;
    
    //framework path
    NSString* path = nil;
    
    //init path
    path = [NSString stringWithFormat:@"%@/../Frameworks/%@", [NSProcessInfo.processInfo.arguments.firstObject stringByDeletingLastPathComponent], name];
    
    //standardize path
    path = [path stringByStandardizingPath];
    
    //init framework (bundle)
    framework = [NSBundle bundleWithPath:path];
    if(NULL == framework)
    {
        //bail
        goto bail;
    }
    
    //load framework
    if(YES != [framework loadAndReturnError:nil])
    {
        //bail
        goto bail;
    }
    
bail:
    
    return framework;
}

//dark mode?
BOOL isDarkMode(void)
{
    //check 'AppleInterfaceStyle'
    return [[[NSUserDefaults standardUserDefaults] stringForKey:@"AppleInterfaceStyle"] isEqualToString:@"Dark"];
}

//check if something is nil
// if so, return a default ('unknown') value
NSString* valueForStringItem(NSString* item)
{
    return (nil != item) ? item : NSLocalizedString(@"unknown", @"unknown");
}

//show an alert
NSModalResponse showAlert(NSAlertStyle style, NSString* messageText, NSString* informativeText, NSArray* buttons)
{
    //alert
    NSAlert* alert = nil;
    
    //response
    NSModalResponse response = 0;
    
    //init alert
    alert = [[NSAlert alloc] init];
    
    //set style
    alert.alertStyle = style;
    
    //main text
    alert.messageText = messageText;
    
    //add details
    if(nil != informativeText)
    {
        //details
        alert.informativeText = informativeText;
    }
    
    //add buttons
    for(NSString* title in buttons)
    {
        //add button
        [alert addButtonWithTitle:title];
    }

    //make first button, first responder
    alert.buttons[0].keyEquivalent = @"\r";
    
    //center
    [alert.window center];
    
    //foreground
    [NSApp setActivationPolicy:NSApplicationActivationPolicyRegular];
    
    //activate
    if(@available(macOS 14.0, *)) {
        [NSApp activate];
    }
    else
    {
        [NSApp activateIgnoringOtherApps:YES];
    }
    
    //(re)make front
    [[NSRunningApplication currentApplication] activateWithOptions:(NSApplicationActivateAllWindows | NSApplicationActivateIgnoringOtherApps)];
    
    //show
    response = [alert runModal];
    
    //(re)set activation policy
    [((AppDelegate*)[[NSApplication sharedApplication] delegate]) setActivationPolicy];
    
    return response;
}

//get audit token for pid
NSData* tokenForPid(pid_t pid)
{
    //audit token
    NSData* token = nil;
    
    //task's token
    audit_token_t taskToken = {0};
    
    //task
    task_name_t task = 0;
    
    //status
    kern_return_t status = !KERN_SUCCESS;

    //size
    mach_msg_type_number_t size = TASK_AUDIT_TOKEN_COUNT;
    
    //clear
    memset(&taskToken, 0x0, sizeof(audit_token_t));
    
    //dbg msg
    os_log_debug(logHandle, "retrieving audit token for %d", pid);
    
    //get task for process
    status = task_name_for_pid(mach_task_self(), pid, &task);
    if(KERN_SUCCESS != status)
    {
        //err msg
        os_log_error(logHandle, "ERROR: 'task_name_for_pid' failed with %x", status);
        
        //bail
        goto bail;
    }
    
    //now get task's audit token
    status = task_info(task, TASK_AUDIT_TOKEN, (task_info_t)&taskToken, &size);
    if(KERN_SUCCESS != status)
    {
        //err msg
        os_log_error(logHandle, "ERROR: 'task_info' failed with %x", status);
        
        //bail
        goto bail;
    }
    
    //capture
    token = [NSData dataWithBytes:&taskToken length:sizeof(audit_token_t)];
    
    //dbg msg
    os_log_debug(logHandle, "retrieved audit token");
    
bail:
    
    //cleanup task
    if(0 != task)
    {
        //cleanup
        mach_port_deallocate(mach_task_self(), task);
        task = 0;
    }

    return token;
}

//given an ip address
// reverse resolves it
NSArray* resolveAddress(NSString* ipAddr)
{
    //hints
    struct addrinfo hints = {0};
    
    //result
    struct addrinfo *result = NULL;
    
    //address
    CFDataRef address = {0};
    
    //host
    CFHostRef host = NULL;
    
    //error
    CFStreamError streamError = {0};
    
    //(resolved) host names
    NSArray* hostNames = nil;
    
    //dbg msg
    os_log_debug(logHandle, "(attempting to) reverse resolve %{public}@", ipAddr);
    
    //clear hints
    memset(&hints, 0x0, sizeof(hints));
    
    //init flags
    hints.ai_flags = AI_NUMERICHOST;
    
    //init family
    hints.ai_family = PF_UNSPEC;
    
    //init type
    hints.ai_socktype = SOCK_STREAM;
    
    //init proto
    hints.ai_protocol = 0;
    
    //get addr info
    if(0 != getaddrinfo(ipAddr.UTF8String, NULL, &hints, &result))
    {
        goto bail;
    }
    
    //convert to data
    address = CFDataCreate(NULL, (UInt8 *)result->ai_addr, result->ai_addrlen);
    if(NULL == address)
    {
        goto bail;
    }
    
    //create host
    host = CFHostCreateWithAddress(kCFAllocatorDefault, address);
    if(host == nil)
    {
        goto bail;
    }
    
    //resolve
    if(YES != CFHostStartInfoResolution(host, kCFHostNames, &streamError))
    {
        goto bail;
    }
    
    //capture
    hostNames = (__bridge NSArray *)(CFHostGetNames(host, NULL));
    
bail:
    
    //free address
    if(NULL != address)
    {
        //free
        CFRelease(address);
        address = NULL;
    }
    
    //free host
    if(NULL != host)
    {
        //free
        CFRelease(host);
        host = NULL;
    }
    
    //free result
    if(NULL != result)
    {
        //free
        freeaddrinfo(result);
        result = NULL;
    }
    
    return hostNames;
}

//process alive?
BOOL isAlive(pid_t processID)
{
    //flag
    BOOL isAlive = YES;
    
    //reset errno
    errno = 0;
    
    //'management info base' array
    int mib[4] = {0};
    
    //kinfo proc
    struct kinfo_proc procInfo = {0};
    
    //try 'kill' with 0
    // no harm done, but will fail with 'ESRCH' if process is dead
    kill(processID, 0);
    
    //dead proc
    // 'ESRCH' ->'No such process'
    if(ESRCH == errno)
    {
        //dead
        isAlive = NO;
        
        //bail
        goto bail;
    }
    
    //size
    size_t size = 0;
    
    //init mib
    mib[0] = CTL_KERN;
    mib[1] = KERN_PROC;
    mib[2] = KERN_PROC_PID;
    mib[3] = processID;
    
    //init size
    size = sizeof(procInfo);

    //get task's flags
    // allows to check for zombies
    if(0 == sysctl(mib, sizeof(mib)/sizeof(*mib), &procInfo, &size, NULL, 0))
    {
        //check for zombies
        if(SZOMB == ((procInfo.kp_proc.p_stat) & SZOMB))
        {
            //dead
            isAlive = NO;
            
            //bail
            goto bail;
            
        }
    }
    
bail:
    
    return isAlive;
}

//check if app is an simulator app
// for now check 'iPhoneSimulator' and 'AppleTVSimulator'
BOOL isSimulatorApp(NSString* path)
{
    //flag
    BOOL simulatorApp = NO;
    
    //bundle
    NSBundle* bundle = nil;
    
    //supported platforms
    NSArray* supportedPlatforms = nil;
    
    //dbg msg
    os_log_debug(logHandle, "checking if %{public}@ is a simulator application", path);
    
    //get bundle
    bundle = findAppBundle(path);
    if(nil == bundle) goto bail;
    
    //get supported platforms
    supportedPlatforms = bundle.infoDictionary[@"CFBundleSupportedPlatforms"];
    if(YES != [supportedPlatforms isKindOfClass:[NSArray class]]) goto bail;
    
    //dbg msg
    os_log_debug(logHandle, "supported platforms: %{public}@", supportedPlatforms);
    
    //sanity check
    if(0 == supportedPlatforms.count) goto bail;
    
    //check if simulator app
    simulatorApp = [[NSSet setWithArray: supportedPlatforms] isSubsetOfSet: [NSSet setWithArray: @[@"iPhoneSimulator", @"AppleTVSimulator"]]];
    
bail:
    
    return simulatorApp;
}

//was app launched by user
BOOL launchedByUser(void)
{
    //flag
    BOOL byUser = NO;
    
    //parent
    NSDictionary* parent = nil;
    
    //get parent
    parent = getRealParent(getpid());
    
    //parent dock/finder/terminal
    // ...then assume its user launched
    if( (YES == [parent[@"CFBundleIdentifier"] isEqualTo:@"com.apple.dock"]) ||
        (YES == [parent[@"CFBundleIdentifier"] isEqualTo:@"com.apple.finder"]) ||
        (YES == [parent[@"CFBundleIdentifier"] isEqualTo:@"com.apple.Terminal"]) )
    {
        //set flag
        byUser = YES;
    }
    
    return byUser;
}

//fade out and close a window
void fadeOut(NSWindow* window, float duration)
{
    //animate fade out
    // and then also close
    [NSAnimationContext runAnimationGroup:^(NSAnimationContext *context) {
        
        //set duration
        context.duration = duration;
        
        //set final alpha
        [[window animator] setAlphaValue:0.0];
        
       } completionHandler:^{
           
           //close
           [window close];
           
       }];
    
    return;
}

//matches CS info?
// with some caveats (e.g. Apple App that was moved to App Store)
BOOL matchesCSInfo(NSDictionary* csInfo_1, NSDictionary* csInfo_2)
{
    //match
    BOOL matches = NO;
    
    //status
    int status_1 = -1;
    int status_2 = -1;
    
    //signer
    int signer_1 = -1;
    int signer_2 = -1;
    
    //signing ID
    NSString* signingID_1 = nil;
    NSString* signingID_2 = nil;
    
    //signing auths
    NSArray* signingAuths_1 = nil;
    NSArray* signingAuths_2 = nil;
    
    //extract status #1
    if(nil != csInfo_1[KEY_CS_STATUS])
    {
        //extract
        status_1 = [csInfo_1[KEY_CS_STATUS] intValue];
    }
    
    //extract status #2
    if(nil != csInfo_2[KEY_CS_STATUS])
    {
        //extract
        status_2 = [csInfo_2[KEY_CS_STATUS] intValue];
    }
    
    //check 0x1
    // signing status mismatch?
    if(status_1 != status_2)
    {
        //dbg msg
        os_log_error(logHandle, "ERROR: code signing mismatch (signing status): %{public}@ / %{public}@", csInfo_1, csInfo_2);
        
        //bail
        goto bail;
    }
    
    //extract signer #1
    if(nil != csInfo_1[KEY_CS_SIGNER])
    {
        //extract
        signer_1 = [csInfo_1[KEY_CS_SIGNER] intValue];
    }
    
    //extract signer #2
    if(nil != csInfo_2[KEY_CS_SIGNER])
    {
        //extract
        signer_2 = [csInfo_2[KEY_CS_SIGNER] intValue];
    }
    
    //check 0x2
    // signer mismatch?
    if(signer_1 != signer_2)
    {
        //but ingore apple apps that have moved
        if( (signer_1 == Apple && signer_2 == AppStore) ||
            (signer_1 == AppStore && signer_2 == Apple) )
        {
            //dbg msg
            os_log_error(logHandle, "ignoring case where Apple App moved to/from Mac App Store: %{public}@ / %{public}@", csInfo_1, csInfo_2);
        }
        //ok something really changed w/ signers
        else
        {
            //dbg msg
            os_log_error(logHandle, "ERROR: code signing mismatch (signer): %{public}@ / %{public}@", csInfo_1, csInfo_2);
            
            //bail
            goto bail;
        }
    }
    
    //extract signing ID #1
    if(nil != csInfo_1[KEY_CS_ID])
    {
        //extract
        signingID_1 = csInfo_1[KEY_CS_ID];
    }
    
    //extract signing ID #2
    if(nil != csInfo_2[KEY_CS_ID])
    {
        //extract
        signingID_2 = csInfo_2[KEY_CS_ID];
    }
    
    //check 0x3
    // signing ID mismatch?
    if( ((nil != signingID_1) || (nil != signingID_2)) &&
        (YES != [signingID_1 isEqualToString:signingID_2]) )
    {
        //dbg msg
        os_log_error(logHandle, "ERROR: code signing mismatch (signing ID): %{public}@ / %{public}@", csInfo_1, csInfo_2);
        
        //bail
        goto bail;
    }
    
    //extract signing auths #1
    if(nil != csInfo_1[KEY_CS_AUTHS])
    {
        //extract
        signingAuths_1 = csInfo_1[KEY_CS_AUTHS];
    }
    
    //extract match's signing auths #2
    if(nil != csInfo_2[KEY_CS_AUTHS])
    {
        //extract
        signingAuths_2 = csInfo_2[KEY_CS_AUTHS];
    }
    
    //check 0x4
    // signing auths mismatch?
    if( ((nil != signingAuths_1) || (nil != signingAuths_2)) &&
        (YES != [signingAuths_1 isEqualToArray:signingAuths_2]) )
    {
        //err msg
        os_log_error(logHandle, "ERROR: code signing mismatch (signing auths): %{public}@ / %{public}@", csInfo_1, csInfo_2);
        
        //bail
        goto bail;
    }
    
    //happy
    matches = YES;
    
bail:
    
    return matches;
    
}

//escape string
NSString* toEscapedJSON(NSString* input)
{
    NSData* data = nil;
    NSError* error = nil;
    NSString* output = nil;
    
    @try {
    
        data = [NSJSONSerialization dataWithJSONObject:input options:NSJSONWritingFragmentsAllowed error:&error];
        if( (nil == data) ||
            (nil != error) )
        {
            //err msg
            os_log_error(logHandle, "ERROR: failed to convert/escape %{public}@ to JSON (error: %{public}@)", input, error);
            
            goto bail;
        }
    }
    @catch(NSException* exception)
    {
        //err msg
        os_log_error(logHandle, "ERROR: failed to convert/escape %{public}@ to JSON (exception: %{public}@)", input, exception);
        goto bail;
    }
    
    output = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    
bail:
    return output;
}


//given HH:mm
// covert to absolute date, up to 24 hrs in the future
NSDate* absoluteDate(NSDate* date)
{
    NSDate* now = nil;
    NSDate *absoluteDate = nil;
    NSCalendar* calendar = nil;
    NSDateComponents* components = nil;
    NSDateComponents* nowComponents = nil;
    
    //dbg msg
    os_log_debug(logHandle, "function '%s' invoked with %{public}@", __PRETTY_FUNCTION__, date);
    
    //now
    now = [NSDate date];
    
    //init calendar
    calendar = [NSCalendar currentCalendar];
    
    //components from entereed date
    components = [calendar components:(NSCalendarUnitHour | NSCalendarUnitMinute) fromDate:date];
    
    //dbg msg
    os_log_debug(logHandle, "components %{public}@", components);

    //components from now
    nowComponents = [calendar components:(NSCalendarUnitYear | NSCalendarUnitMonth | NSCalendarUnitDay | NSCalendarUnitHour | NSCalendarUnitMinute) fromDate:now];
    
    //replace hour/minute
    nowComponents.hour = components.hour;
    nowComponents.minute = components.minute;
    
    //new date with the combined components
    absoluteDate = [calendar dateFromComponents:nowComponents];
    
    //in past?
    // add day ...needs to be future
    if([absoluteDate compare:now] == NSOrderedAscending) {
        
        //add day
        absoluteDate = [calendar dateByAddingUnit:NSCalendarUnitDay value:1 toDate:absoluteDate options:0];
    }

    return absoluteDate;
}

//is process on internal drive?
BOOL isInternalProcess(NSString *path)
{
    NSError* error = nil;
    NSNumber* isInternal = nil;
    
    if(YES != [[NSURL fileURLWithPath:path] getResourceValue:&isInternal forKey:NSURLVolumeIsInternalKey error:&error] || (nil != error))
    {
        //err msg
        os_log_error(logHandle, "ERROR: 'getResourceValue'/'NSURLVolumeIsInternalKey' failed with %@", error);
        
        goto bail;
    }
    
bail:
    
    return isInternal.boolValue;
}
