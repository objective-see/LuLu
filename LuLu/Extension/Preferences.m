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
            self.preferences = [NSMutableDictionary dictionary];
        }
    }
    
bail:
    
    return self;
}

//get path to preferences
// either default, or in current profile directory
-(NSString*)path
{
    //current profile
    NSString* currentProfile = nil;
    
    //path
    // init with default
    NSString* path = [INSTALL_DIRECTORY stringByAppendingPathComponent:PREFS_FILE];
    
    //not found?
    // that ok, likely just first time
    if(YES != [NSFileManager.defaultManager fileExistsAtPath:path])
    {
        //dbg msg
        os_log_debug(logHandle, "default preferences file '%{public}@' not found ...first time?", path);
        goto bail;
    }
    
    //get current profile
    currentProfile = [self getCurrentProfile];
    if(nil != currentProfile)
    {
        //set
        path = currentProfile;
    }
    
bail:
    
    //dbg msg
    os_log_debug(logHandle, "using preferences file: %{public}@", path);
    
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
    self.preferences = [NSMutableDictionary dictionaryWithContentsOfFile:prefsFile];
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
-(BOOL)update:(NSDictionary*)updates replace:(BOOL)replace
{
    //flag
    BOOL updated = NO;
    
    //allow list
    NSString* allowListPath = nil;
    
    //block list
    NSString* blockListPath = nil;
    
    //sync
    @synchronized (self) {

    //replace?
    // e.g. new profile
    if(YES == replace)
    {
        //dbg msg
        os_log_debug(logHandle, "replacing preferences (%{public}@)", updates);
        
        //replace
        self.preferences = [updates mutableCopy];
    }
    //merge
    else
    {
        //dbg msg
        os_log_debug(logHandle, "updating preferences (%{public}@)", updates);
        
        //add in (new) prefs
        [self.preferences addEntriesFromDictionary:updates];
    }
        
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
    
    //init w/ default
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

//get current profile
// this is saved in the default preferences (and may be nil)
-(NSString*)getCurrentProfile
{
    //current
    NSString* currentProfile = nil;
    
    //dbg msg
    os_log_debug(logHandle, "method '%s' invoked", __PRETTY_FUNCTION__);
    
    //load *default* prefs
    NSDictionary* defaultPreferences = [NSDictionary dictionaryWithContentsOfFile:[INSTALL_DIRECTORY stringByAppendingPathComponent:PREFS_FILE]];
    
    //extract
    currentProfile = defaultPreferences[PREF_CURRENT_PROFILE];
    
    //dbg msg
    os_log_debug(logHandle, "returning current profile %{public}@", currentProfile);
    
    return currentProfile;
}

//set current profile
// this is saved in the default preferences (and may be nil)
-(void)setCurrentProfile:(NSString*)profilePath
{
    //default pref's file
    NSString* defaultPreferencesFile = [INSTALL_DIRECTORY stringByAppendingPathComponent:PREFS_FILE];
    
    //load *default* prefs
    NSMutableDictionary* defaultPreferences = [NSMutableDictionary dictionaryWithContentsOfFile:defaultPreferencesFile];
    
    //set
    defaultPreferences[PREF_CURRENT_PROFILE] = profilePath;
    
    //save
    [defaultPreferences writeToFile:defaultPreferencesFile atomically:YES];
    
    //dbg msg
    os_log_debug(logHandle, "set current profile to %{public}@", profilePath);
    
    return;
}

@end
