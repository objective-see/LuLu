//
//  Preferences.m
//  launchDaemon
//
//  Created by Patrick Wardle on 2/22/18.
//  Copyright (c) 2018 Objective-See. All rights reserved.
//

#import "consts.h"
#import "BlockList.h"
#import "Preferences.h"

/* GLOBALS */

//log handle
extern os_log_t logHandle;

//block list
extern BlockList* blockList;

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
        //prefs exist?
        // load them from disk
        if(YES == [[NSFileManager defaultManager] fileExistsAtPath:[INSTALL_DIRECTORY stringByAppendingPathComponent:PREFS_FILE]])
        {
            //load
            if(YES != [self load])
            {
                //err msg
                os_log_error(logHandle, "failed to loads preferences from %@", PREFS_FILE);
                
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

//load prefs from disk
-(BOOL)load
{
    //flag
    BOOL loaded = NO;
    
    //load
    preferences = [NSMutableDictionary dictionaryWithContentsOfFile:[INSTALL_DIRECTORY stringByAppendingPathComponent:PREFS_FILE]];
    if(nil == self.preferences)
    {
        //err msg
        os_log_error(logHandle, "ERROR: failed to load preference from %{public}@", PREFS_FILE);
        
        //bail
        goto bail;
    }
    
    //dbg msg
    os_log_debug(logHandle, "loaded preferences: %{public}@", self.preferences);
    
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
    
    //(new) block list?
    // now, trigger reload
    if(0 != [updates[PREF_BLOCK_LIST] length])
    {
        //(re)load
        [blockList load];
    }
    
    //happy
    updated = YES;
    
bail:
    
    return updated;
}

//save to disk
-(BOOL)save
{
    //save
    return [self.preferences writeToFile:[INSTALL_DIRECTORY stringByAppendingPathComponent:PREFS_FILE] atomically:YES];
}

@end
