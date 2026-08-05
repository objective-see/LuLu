//
//  Profiles.m
//
//  Created by Patrick Wardle on 06/21/25.
//  Copyright (c) 2025 Objective-See. All rights reserved.
//

#import "Rules.h"
#import "consts.h"
#import "Profiles.h"
#import "Preferences.h"

/* GLOBALS */

//log handle
extern os_log_t logHandle;

//rules
extern Rules* rules;

//preferences
extern Preferences* preferences;

@implementation Profiles

//init
// loads profiles
-(id)init
{
    //super
    self = [super init];
    if(nil != self)
    {
        //set (base) directory
        self.directory = [INSTALL_DIRECTORY stringByAppendingPathComponent:PROFILE_DIRECTORY];
    }
        
    return self;
}

//enumerate
// return list of just profile *names*
-(NSMutableArray*)enumerate
{
    //list
    NSMutableArray* profiles = [NSMutableArray array];
    
    //no profiles?
    // not problem, but just bail here
    if(![NSFileManager.defaultManager fileExistsAtPath:self.directory])
    {
        //dbg msg
        os_log_debug(logHandle, "no profiles? didn't find profiles directory %{public}@", self.directory);
        goto bail;
    }

    //grab all items, saving only names of directories
    for(NSString* name in [NSFileManager.defaultManager contentsOfDirectoryAtPath:self.directory error:nil])
    {
        BOOL isDir = NO;
        NSString* fullPath = [self.directory stringByAppendingPathComponent:name];
        
        //add if directory
        if([NSFileManager.defaultManager fileExistsAtPath:fullPath isDirectory:&isDir] && isDir)
        {
            //add
            [profiles addObject:name];
        }
    }
    
    //sort for UI
    [profiles sortUsingSelector:@selector(localizedCaseInsensitiveCompare:)];

    //dbg msg
    os_log_debug(logHandle, "profiles: %{public}@", profiles);
    
bail:
    
    return profiles;
}

//resolve a (client-supplied) profile name into a path within the profiles directory
// returns nil if the name is invalid, or if the resolved path escapes the profiles directory
-(NSString*)resolve:(NSString*)name
{
    //resolved path
    NSString* resolvedPath = nil;

    //sanitized name
    // just use last path component (e.g. strips any '../')
    NSString* sanitizedName = name.lastPathComponent;

    //sanity check
    if(0 == sanitizedName.length)
    {
        //err msg
        os_log_error(logHandle, "ERROR: profile name '%{public}@' is invalid", name);
        goto bail;
    }

    //init path
    // ...also standardize and resolve any symlinks
    resolvedPath = [[[self.directory stringByAppendingPathComponent:sanitizedName] stringByStandardizingPath] stringByResolvingSymlinksInPath];

    //sanity check
    // must (still) be within the profiles directory
    if(YES != [resolvedPath hasPrefix:[self.directory stringByAppendingString:@"/"]])
    {
        //err msg
        os_log_error(logHandle, "ERROR: resolved path '%{public}@' isn't in the profile directory %{public}@",
                     resolvedPath, self.directory);

        //unset
        resolvedPath = nil;
        goto bail;
    }

bail:

    return resolvedPath;
}

//add new profile
// and then set it to default
-(BOOL)add:(NSString*)name preferences:(NSDictionary*)newPreferences
{
    BOOL wasAdded = NO;
    NSError* error = nil;
    NSString *newProfilePath = nil;
    
    //dbg msg
    os_log_debug(logHandle, "method '%s' invoked with %{public}@ / %{public}@", __PRETTY_FUNCTION__, name, newPreferences);

    //create base profiles directory if needed
    if(YES != [NSFileManager.defaultManager fileExistsAtPath:self.directory])
    {
        //create
        if(YES != [NSFileManager.defaultManager createDirectoryAtPath:self.directory withIntermediateDirectories:YES attributes:nil error:&error])
        {
            //error
            os_log_error(logHandle, "ERROR: failed to create profiles directory '%{public}@': %{public}@",
                         self.directory, error.localizedDescription);
            goto bail;
        }
    }
    
    //init path for new profile directory
    // note: resolves name, ensuring the result is within the profiles directory
    newProfilePath = [self resolve:name];
    if(nil == newProfilePath)
    {
        //err msg
        os_log_error(logHandle, "ERROR: failed to resolve profile name '%{public}@'", name);
        goto bail;
    }
    
    //if already exists, delete it
    if(YES == [NSFileManager.defaultManager fileExistsAtPath:newProfilePath]) {
        
        //remove install directory
        if(YES != [NSFileManager.defaultManager removeItemAtPath:newProfilePath error:&error])
        {
            //err msg
            os_log_error(logHandle, "ERROR: failed to remove existing profile %{public}@ (error: %{public}@)", newProfilePath, error);
        }
        else
        {
            //dbg msg
            os_log_debug(logHandle, "removed existing profile %{public}@", newProfilePath);
        }
    }
    
    //create directory for new profile
    if(YES != [NSFileManager.defaultManager createDirectoryAtPath:newProfilePath withIntermediateDirectories:NO attributes:nil error:&error])
    {
        //err msg
        os_log_error(logHandle, "ERROR: Failed to create new profile directory '%{public}@': %{public}@",
                     newProfilePath, error.localizedDescription);
        goto bail;
    }
    
    //dbg msg
    os_log_debug(logHandle, "created profile directory: %{public}@", newProfilePath);
    
    //set as current
    [self set:newProfilePath];
    
    //save new prefs
    // replacing all
    [preferences update:newPreferences replace:YES];
    
    //clear out all rules
    @synchronized (rules) {
        
        [rules.rules removeAllObjects];
    }
    
    //generate default rules
    if(YES != [rules generateDefaultRules])
    {
        //err msg
        os_log_error(logHandle, "ERROR: failed to generate default rules");
        
        //bail
        goto bail;
    }
    
    //save
    [rules save];
    
    //reload rules
    [rules load];
    
    //reload prefs
    [preferences load];

    //happy
    wasAdded = YES;
    
bail:
    
    return wasAdded;
}

//set current profile path in *default* prefs
// note: can be called with nil to reset back to default profile
-(void)set:(NSString*)profilePath
{
    //set
    [preferences setCurrentProfile:profilePath];
    
    return;
}

//delete a profile
// delete folder matching name and reset to default if needed
-(BOOL)delete:(NSString*)name
{
    //flag
    BOOL wasDeleted = NO;
    
    //error
    NSError* error = nil;
    
    //current
    NSString* current = nil;
    
    //path
    // note: resolves (client-supplied) name, ensuring it's within the profiles directory
    NSString* profile = [self resolve:name];
    if(nil == profile)
    {
        //err msg
        os_log_error(logHandle, "ERROR: failed to resolve profile name '%{public}@'", name);
        goto bail;
    }

    //dbg msg
    os_log_debug(logHandle, "deleting profile directory: %{public}@", profile);
    
    //flag
    if(YES != [NSFileManager.defaultManager removeItemAtPath:profile error:&error])
    {
        //err msg
        os_log_error(logHandle, "ERROR: Failed to delete profile directory '%{public}@': %{public}@",
                     profile, error.localizedDescription);
        goto bail;
    }
    
    //dbg msg
    os_log_debug(logHandle, "deleted profile directory: %{public}@", profile);
    
    //get current
    current = [preferences getCurrentProfile];
    
    //dbg msg
    os_log_debug(logHandle, "checking if %{public}@ matches current %{public}@", profile, current);
    
    //was current?
    if(YES == [profile isEqualToString:current])
    {
        //dbg msg
        os_log_debug(logHandle, "'%{public}@' was current profile, so will reset back to default", profile);
        
        //unset path
        [self set:nil];
        
        //reload rules
        [rules load];
        
        //reload prefs
        [preferences load];
    }
    
    //happy
    wasDeleted = YES;
    
bail:
    
    return wasDeleted;
}

@end
