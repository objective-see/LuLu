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
        
        //set current path
        self.current = preferences.preferences[PREF_CURRENT_PROFILE];
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

//add new profile
// and then set it to default
-(BOOL)add:(NSString*)name preferences:(NSDictionary*)newPreferences
{
    BOOL wasAdded = NO;
    NSError* error = nil;
    NSString *newProfilePath = nil;

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
    newProfilePath = [[[self.directory stringByAppendingPathComponent:name.lastPathComponent] stringByStandardizingPath] stringByResolvingSymlinksInPath];
    
    //sanity check
    if(YES != [newProfilePath hasPrefix:[self.directory stringByAppendingString:@"/"]]) {
        
        //error
        os_log_error(logHandle, "ERROR: created path '%{public}@' isn't in the profile directory %{public}@",
                     newProfilePath, self.directory);
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
    
    //set as current
    [self set:newProfilePath];
    
    //save prefs
    // replacing all
    [preferences update:newPreferences replace:YES];
    
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
    //flag
    BOOL useDefault = YES;
    
    //set current
    self.current = profilePath;
    
    //set
    // if nil, is a remove!
    preferences.preferences[PREF_CURRENT_PROFILE] = self.current;
    
    //save
    // but use defaults
    [preferences save:useDefault];
    
    return;
    
}

//delete a profile
// delete folder matching name and reset default if needed
-(BOOL)delete:(NSString*)name
{
    //flag
    BOOL wasDeleted = NO;
    
    //error
    NSError* error = nil;
    
    //path
    NSString* profile = [self.directory stringByAppendingPathComponent:name];
    
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
    
    //was current?
    if(YES == [profile isEqualToString:self.current])
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
