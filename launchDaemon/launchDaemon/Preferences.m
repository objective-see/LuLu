//
//  Preferences.m
//  launchDaemon
//
//  Created by Patrick Wardle on 2/22/18.
//  Copyright © 2018 Objective-See. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "consts.h"
#import "logging.h"
#import "KextComms.h"
#import "Preferences.h"
#import "KextListener.h"

/* GLOBALS */

//kext comms obj
extern KextComms* kextComms;

//kext listener object
extern KextListener* kextListener;

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
                logMsg(LOG_ERR, [NSString stringWithFormat:@"failed to loads preferences from %@", PREFS_FILE]);
                
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
        //bail
        goto bail;
    }
    
    //dbg msg
    logMsg(LOG_DEBUG, [NSString stringWithFormat:@"loaded preferences: %@", self.preferences]);
    
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
    logMsg(LOG_DEBUG, [NSString stringWithFormat:@"updating preferences (%@)", updates]);
    
    //user setting state?
    if(nil != updates[PREF_IS_DISABLED])
    {
        //dbg msg
        logMsg(LOG_DEBUG, [NSString stringWithFormat:@"client toggling firewall state: %@", updates[PREF_IS_DISABLED]]);
        
        //disable?
        if(YES == [updates[PREF_IS_DISABLED] boolValue])
        {
            //dbg msg
            // and log to file
            logMsg(LOG_DEBUG|LOG_TO_FILE, @"disabling firewall");
            
            //disable firewall
            // ...but don't unregister socket filters
            [kextComms disable:NO];
        }
        
        //enable?
        else
        {
            //dbg msg
            // and log to file
            logMsg(LOG_DEBUG|LOG_TO_FILE, @"enabling firewall");
            
            //enable firewall
            [kextComms enable];
        }
    }

    //add in (new) prefs
    [self.preferences addEntriesFromDictionary:updates];
    
    //now, did user turn off passive mode?
    // remove all 'allow' rules for procs passively allowed
    if( (nil != updates[PREF_PASSIVE_MODE]) &&
        (YES != [updates[PREF_PASSIVE_MODE] boolValue]) &&
        (0 != kextListener.self.passiveProcesses.count) )
    {
        //dbg msg
        logMsg(LOG_DEBUG, [NSString stringWithFormat:@"removing (kernel) rules for passively allowed procs: %@", kextListener.self.passiveProcesses]);
        
        //sync
        @synchronized(kextListener.self.passiveProcesses)
        {
            //reset
            for(NSNumber* allowedProcess in kextListener.self.passiveProcesses)
            {
                //delete rule
                [kextComms removeRule:allowedProcess.unsignedShortValue];
            }
            
            //remove all
            [kextListener.self.passiveProcesses removeAllObjects];
        }
    }
        
    //save
    if(YES != [self save])
    {
        //err msg
        logMsg(LOG_ERR, @"failed to save preferences");
        
        //bail
        goto bail;
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
