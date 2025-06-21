//
//  Preferences.m
//  launchDaemon
//
//  Created by Patrick Wardle on 2/22/18.
//  Copyright (c) 2018 Objective-See. All rights reserved.
//

#import "consts.h"
#import "BlockOrAllowList.h"
#import "Preferences.h"

/* GLOBALS */

//log handle
extern os_log_t logHandle;

//allow list
extern BlockOrAllowList* allowList;

//block list
extern BlockOrAllowList* blockList;

@implementation Preferences

@synthesize preferences;

//init
// loads prefs
-(id)init
{
    //super
    self = [super init];
    if(nil != self)
    {
        //default prefs exist?
        // load them from disk
        if(YES == [NSFileManager.defaultManager fileExistsAtPath:[INSTALL_DIRECTORY stringByAppendingPathComponent:PREFS_FILE]])
        {
            //load
            if(YES != [self load])
            {
                //err msg
                os_log_error(logHandle, "ERROR: failed to loads preferences from %@", PREFS_FILE);
                
                //unset
                self = nil;
                
                //bail
                goto bail;
            }
            
        }
        //no prefs (yet)
        // just initialze empty dictionary
        else
        {
            //init
            preferences = [NSMutableDictionary dictionary];
        }
    }
    
bail:
    
    return self;
}

//get path to preferences
// either default, or in current profile directory
-(NSString*)path {
    
    //path
    NSString* path = nil;
    
    //first gotta load default preferences
    NSDictionary* defaultPreferences = [NSDictionary dictionaryWithContentsOfFile:[INSTALL_DIRECTORY stringByAppendingPathComponent:PREFS_FILE]];
    if(nil == defaultPreferences)
    {
        //err msg
        os_log_error(logHandle, "ERROR: failed to load default preference from %{public}@", PREFS_FILE);
        goto bail;
    }
    
    //init path to preferences file
    // which might be in a profile directory
    if(0 != defaultPreferences[PREF_CURRENT_PROFILE])
    {
        //set
        path = [PREF_CURRENT_PROFILE stringByAppendingPathComponent:PREFS_FILE];
        
        //dbg msg
        os_log_debug(logHandle, "using profile's preferences file: %{public}@", path);
    }
    //otherwise just use default
    else
    {
        //init w/ default
        path = [INSTALL_DIRECTORY stringByAppendingPathComponent:PREFS_FILE];
        
        //dbg msg
        os_log_debug(logHandle, "using default preferences file: %{public}@", path);
    }
    
bail:
    
    return path;
}

//load prefs from disk
-(BOOL)load
{
    //flag
    BOOL loaded = NO;
    
    //path
    NSString* prefsFile = [self path];
    
    //load
    preferences = [NSMutableDictionary dictionaryWithContentsOfFile:prefsFile];
    if(nil == self.preferences)
    {
        //err msg
        os_log_error(logHandle, "ERROR: failed to load preference from %{public}@", prefsFile);
        goto bail;
    }
    
    //dbg msg
    os_log_debug(logHandle, "from %{public}@, loaded preferences: %{public}@", prefsFile, self.preferences);
    
    //happy
    loaded = YES;
    
bail:
    
    return loaded;
}

//update prefs
// handles logic for specific prefs & then saves
-(BOOL)update:(NSDictionary*)updates
{
    //flag
    BOOL updated = NO;
    
    //allow list
    NSString* allowListPath = nil;
    
    //block list
    NSString* blockListPath = nil;
    
    //sync
    @synchronized (self) {

    //dbg msg
    os_log_debug(logHandle, "updating preferences (%{public}@)", updates);
    
    //add in (new) prefs
    [self.preferences addEntriesFromDictionary:updates];
    
    //save
    if(YES != [self save])
    {
        //err msg
        os_log_error(logHandle, "ERROR: failed to save preferences");
        
        //bail
        goto bail;
    }

    //extract any allow list
    allowListPath = updates[PREF_ALLOW_LIST];
    
    //extract any block list
    blockListPath = updates[PREF_BLOCK_LIST];
    
    //(new) allow list?
    // now, trigger reload
    if(0 != [allowListPath length])
    {
        //dbg msg
        os_log_debug(logHandle, "user specified new 'allow' list: %{public}@", allowListPath);
        
        //first time?
        if(nil == allowList)
        {
            //alloc/init/load block list
            allowList = [[BlockOrAllowList alloc] init:allowListPath];
        }
        //otherwise just reload
        else
        {
            //(re)load
            [allowList load:allowListPath];
        }
    }
    
    //(new) block list?
    // now, trigger reload
    if(0 != [blockListPath length])
    {
        //dbg msg
        os_log_debug(logHandle, "user specified new 'block' list: %{public}@", blockListPath);
        
        //first time?
        if(nil == blockList)
        {
            //alloc/init/load block list
            blockList = [[BlockOrAllowList alloc] init:blockListPath];
        }
        //otherwise just reload
        else
        {
            //(re)load
            [blockList load:blockListPath];
        }
    }
    
    //happy
    updated = YES;
        
    } //sync
    
bail:
    
    return updated;
}

//save to disk
-(BOOL)save
{
    //flag
    BOOL wasSaved = NO;
    
    //get path
    NSString* prefsFile = [self path];
    
    //write out preferences
    if(YES != [self.preferences writeToFile:prefsFile atomically:YES])
    {
        //err msg
        os_log_error(logHandle, "ERROR: failed to save preferences to: %{public}@", prefsFile);
        goto bail;
    }
    
    //dbg msg
    os_log_debug(logHandle, "saved preferences to %{public}@", prefsFile);
    
    //happy
    wasSaved = YES;
    
bail:
    
    return wasSaved;
}

@end
