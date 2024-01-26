//
//  file: XPCDaemon.m
//  project: lulu (launch daemon)
//  description: interface for XPC methods, invoked by user
//
//  created by Patrick Wardle
//  copyright (c) 2017 Objective-See. All rights reserved.
//

#import "Rule.h"
#import "Rules.h"
#import "Alerts.h"
#import "consts.h"
#import "XPCDaemon.h"
#import "utilities.h"
#import "Preferences.h"

//global rules obj
extern Rules* rules;

//global alerts obj
extern Alerts* alerts;

//global prefs obj
extern Preferences* preferences;

//global log handle
extern os_log_t logHandle;

@implementation XPCDaemon

//send preferences to the client
-(void)getPreferences:(void (^)(NSDictionary* preferences))reply
{
    //dbg msg
    os_log_debug(logHandle, "XPC request: '%s'", __PRETTY_FUNCTION__);
    
    //reply w/ prefs
    reply(preferences.preferences);
    
    return;
}

//update preferences
// note: sends full preferences back to the client
-(void)updatePreferences:(NSDictionary *)updates reply:(void (^)(NSDictionary*))reply
{
    //dbg msg
    os_log_debug(logHandle, "XPC request: '%s' (%{public}@)", __PRETTY_FUNCTION__, updates);
    
    //call into prefs obj
    if(YES != [preferences update:updates])
    {
        //err msg
        os_log_error(logHandle, "ERROR: failed to updates to preferences");
    }
    
    //reply w/ prefs
    reply(preferences.preferences);
    
    return;
}

//send rules to the client
-(void)getRules:(void (^)(NSData*))reply
{
    //archived rules
    NSData* archivedRules = nil;
    
    //error
    NSError* error = nil;
    
    //dbg msg
    os_log_debug(logHandle, "XPC request: '%s'", __PRETTY_FUNCTION__);
    
    //archive rules
    archivedRules = [NSKeyedArchiver archivedDataWithRootObject:rules.rules requiringSecureCoding:YES error:&error];
    if(nil == archivedRules)
    {
        //err msg
        os_log_error(logHandle, "ERROR: failed to archive rules: %{public}@", error);
            
    } else os_log_debug(logHandle, "archived %lu rules, and sending to user...", (unsigned long)rules.rules.count);

    //reply w/ rules
    reply(archivedRules);
           
    return;
}

//add a rule
-(void)addRule:(NSDictionary*)info
{
    //binary obj
    Binary* binary = nil;
    
    //rule info
    NSMutableDictionary* ruleInfo = nil;
    
    //default cs flags
    SecCSFlags flags = kSecCSDefaultFlags | kSecCSCheckNestedCode | kSecCSDoNotValidateResources | kSecCSCheckAllArchitectures;
    
    //dbg msg
    os_log_debug(logHandle, "XPC request: '%s' with info: %{public}@", __PRETTY_FUNCTION__, info);
    
    //make copy
    ruleInfo = [info mutableCopy];
    
    //non-specific path
    // init binary and cs info
    if(YES != [info[KEY_PATH] hasSuffix:VALUE_ANY])
    {
        //init binary obj w/ path
        binary = [[Binary alloc] init:info[KEY_PATH]];
        if(nil == binary)
        {
            //err msg
            os_log_error(logHandle, "ERROR: failed init binary object for %@", info[KEY_PATH]);
            
            //bail
            goto bail;
        }
        
        //generate cs info
        [binary generateSigningInfo:flags];
        
        //add any code signing info
        if(nil != binary.csInfo) ruleInfo[KEY_CS_INFO] = binary.csInfo;
    }
    
    //create and add rule
    if(YES != [rules add:[[Rule alloc] init:ruleInfo] save:YES])
    {
        //err msg
        os_log_error(logHandle, "ERROR: failed to add rule for %{public}@", ruleInfo[KEY_PATH]);
         
        //bail
        goto bail;
    }
    
    //dbg msg
    os_log_debug(logHandle, "added rule");
    
bail:
    
    return;
}

//delete rule
-(void)deleteRule:(NSString*)key rule:(NSString*)uuid
{
    //dbg msg
    os_log_debug(logHandle, "XPC request: '%s' with key: %{public}@, rule id: %{public}@", __PRETTY_FUNCTION__, key, uuid);

    //delete rule
    if(YES != [rules delete:key rule:uuid])
    {
        //err msg
        os_log_error(logHandle, "ERROR: failed to delete rule");
        
        //bail
        goto bail;
    }
    
    //dbg msg
    os_log_debug(logHandle, "deleted rule");
    
bail:
    
    return;
}

//import rules
-(void)importRules:(NSData*)importedRules result:(void (^)(BOOL))reply
{
    //dbg msg
    os_log_debug(logHandle, "XPC request: '%s'", __PRETTY_FUNCTION__);
    
    //import rules
    reply([rules import:importedRules]);

    return;
}

//cleanup rules
-(void)cleanupRules
{
    //dbg msg
    os_log_debug(logHandle, "XPC request: '%s'", __PRETTY_FUNCTION__);

    return;
}

//uninstall
-(void)uninstall:(void (^)(BOOL))reply
{
    //flag
    BOOL uninstalled = NO;
    
    //directory
    NSString* path = nil;

    //error
    NSError* error = nil;
    
    //dbg msg
    os_log_debug(logHandle, "XPC request: '%s'", __PRETTY_FUNCTION__);
    
    //init path w/ install dir
    path = INSTALL_DIRECTORY;
    
    //remove install directory
    if(YES != [NSFileManager.defaultManager removeItemAtPath:path error:&error])
    {
        //err msg
        os_log_error(logHandle, "ERROR: failed to remove %{public}@ (error: %{public}@)", path, error);
        
    }
    else
    {
        //dbg msg
        os_log_debug(logHandle, "removed %{public}@", path);
        
        //happy
        uninstalled = YES;
    }
    
    //up to Obj-See's install dir
    path = [path stringByDeletingLastPathComponent];
    
    //no other Obj-See tools?
    // remove the Obj-See directory too
    if( (0 == [[NSFileManager.defaultManager contentsOfDirectoryAtPath:path error:&error] count]) &&
        (nil == error) )
    {
        //remove
        if(YES != [NSFileManager.defaultManager removeItemAtPath:path error:&error])
        {
            //err msg
            os_log_error(logHandle, "ERROR: failed to delete %{public}@ (error: %{public}@)", path, error);
        }
        else
        {
            //dbg msg
            os_log_debug(logHandle, "removed %{public}@", path);
            
            //happy
            uninstalled = YES;
        }
    }
    
    //return result
    reply(uninstalled);
    
    return;
}

@end
