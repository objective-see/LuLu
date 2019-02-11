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
#import "logging.h"
#import "KextComms.h"
#import "XPCDaemon.h"
#import "utilities.h"
#import "Preferences.h"
#import "KextListener.h"
#import "UserClientShared.h"

//signing auth
#define SIGNING_AUTH @"Developer ID Application: Objective-See, LLC (VBG97UB4TA)"

//global rules obj
extern Rules* rules;

//global kext comms obj
extern KextComms* kextComms;

//global alerts obj
extern Alerts* alerts;

//global prefs obj
extern Preferences* preferences;

//global kext listener object
extern KextListener* kextListener;

@implementation XPCDaemon

//load kext
-(void)loadKext
{
    //dbg msg
    logMsg(LOG_DEBUG, [NSString stringWithFormat:@"XPC request: '%s'", __PRETTY_FUNCTION__]);
    
    //if already loaded?
    if(YES == kextIsLoaded([NSString stringWithUTF8String:LULU_SERVICE_NAME]))
    {
        //bail
        goto bail;
    }
    
    //load kext
    execTask(KEXT_LOAD, @[[NSString pathWithComponents:@[@"/", @"Library", @"Extensions", @"LuLu.kext"]]], YES, NO);
    
bail:
    
    return;
}

//load preferences and send them back to client
-(void)getPreferences:(void (^)(NSDictionary* preferences))reply
{
    //dbg msg
    logMsg(LOG_DEBUG, @"XPC request: get preferences");
    
    //preference obj has em
    reply(preferences.preferences);
    
    return;
}

//update preferences
-(void)updatePreferences:(NSDictionary *)prefs
{
    //dbg msg
    logMsg(LOG_DEBUG, [NSString stringWithFormat:@"XPC request: update preferences (%@)", preferences]);
    
    //call into prefs obj
    if(YES != [preferences update:prefs])
    {
        //err msg
        logMsg(LOG_ERR, [NSString stringWithFormat:@"failed to save preferences to %@", PREFS_FILE]);
    }
    
    return;
}

//get rules
// optionally wait (blocks) for change
-(void)getRules:(void (^)(NSDictionary*))reply
{
    //dbg msg
    logMsg(LOG_DEBUG, @"XPC request: GET RULES");
    
    //return rules
    reply([rules serialize]);
    
    return;
}

//add rule
-(void)addRule:(NSString*)path action:(NSUInteger)action user:(NSUInteger)user
{
    //binary obj
    Binary* binary = nil;
    
    //default cs flags
    SecCSFlags flags = kSecCSDefaultFlags | kSecCSCheckNestedCode | kSecCSDoNotValidateResources | kSecCSCheckAllArchitectures;
    
    //dbg msg
    logMsg(LOG_DEBUG, [NSString stringWithFormat:@"XPC request: ADD RULE (%@/%lu)", path, action]);
    
    //init binary obj w/ path
    binary = [[Binary alloc] init:path];
    if(nil == binary)
    {
        //err msg
        logMsg(LOG_ERR, [NSString stringWithFormat:@"failed init binary object for %@", path]);
        
        //bail
        goto bail;
    }
    
    //generate signing info
    [binary generateSigningInfo:flags];
    
    //log to file
    logMsg(LOG_TO_FILE, [NSString stringWithFormat:@"adding rule (path: %@ / action: %lu)", path, action]);
    
    //add
    // type is 'user'
    if(YES != [rules add:path signingInfo:binary.signingInfo action:action type:RULE_TYPE_USER user:user])
    {
        //err msg
        logMsg(LOG_ERR, [NSString stringWithFormat:@"failed to add rule for %@", path]);
        
        //bail
        goto bail;
    }

bail:
    
    return;
}

//update rule
-(void)updateRule:(NSString*)path action:(NSUInteger)action user:(NSUInteger)user
{
    //dbg msg
    logMsg(LOG_DEBUG, [NSString stringWithFormat:@"XPC request: UPDATE RULE (%@/%lu)", path, action]);
    
    //log to file
    logMsg(LOG_TO_FILE, [NSString stringWithFormat:@"updating rule (path: %@ / action: %lu)", path, action]);
    
    //update
    if(YES != [rules update:path action:action user:user])
    {
        //err msg
        logMsg(LOG_ERR, [NSString stringWithFormat:@"failed to update rule for %@", path]);
        
        //bail
        goto bail;
    }
    
bail:
    
    return;
}

//delete rule
-(void)deleteRule:(NSString*)path
{
    //dbg msg
    logMsg(LOG_DEBUG, [NSString stringWithFormat:@"XPC request: DELETE RULE (%@)", path]);
    
    //log to file
    logMsg(LOG_TO_FILE, [NSString stringWithFormat:@"deleting rule (path: %@)", path]);
    
    //remove row
    if(YES != [rules delete:path])
    {
        //err msg
        logMsg(LOG_ERR, [NSString stringWithFormat:@"failed to delete rule for %@", path]);
        
        //bail
        goto bail;
    }
    
bail:
    
    return;
}

//import rules
-(void)importRules:(NSString*)rulesFile reply:(void (^)(BOOL))reply
{
    //error
    NSError* error = nil;
    
    //flag
    BOOL importedRules = NO;
    
    //dbg msg
    logMsg(LOG_DEBUG, [NSString stringWithFormat:@"XPC request: IMPORT RULES (%@)", rulesFile]);
    
    //delete all
    if(YES != [rules deleteAll])
    {
        //err msg
        logMsg(LOG_ERR, @"failed to delete existing rules");
        
        //bail
        goto bail;
    }

    //save new rules
    if(YES != [[NSFileManager defaultManager] copyItemAtPath:rulesFile toPath:[INSTALL_DIRECTORY stringByAppendingPathComponent:RULES_FILE] error:&error])
    {
        //err msg
        logMsg(LOG_ERR, [NSString stringWithFormat:@"failed to save imported rules file %@ (error: %@)", RULES_FILE, error]);
        
        //bail
        goto bail;
    }
    
    //load rules
    if(YES != [rules load])
    {
        //err msg
        logMsg(LOG_ERR, [NSString stringWithFormat:@"failed to load rules from %@", RULES_FILE]);
        
        //bail
        goto bail;
    }
    
    //add all rules to kernel
    @synchronized(rules.rules)
    {
        //iterate & add all
        for(NSString* rulePath in rules.rules)
        {
            //add
            [rules addToKernel:rules.rules[rulePath]];
        }
    }
    
    //happy
    importedRules = YES;

bail:
    
    //return rules
    reply(importedRules);
    
    return;
}

//handle client response to alert
// tells kext/update rules/etc...
-(void)alertReply:(NSMutableDictionary*)alert
{
    //path
    NSString* path = nil;
    
    //pid
    uint32_t pid = 0;
    
    //action
    uint32_t action = 0;
    
    //user
    uint32 user = 0;
    
    //log to file
    logMsg(LOG_DEBUG|LOG_TO_FILE, [NSString stringWithFormat:@"alert reply: %@", alert]);
    
    //extract path
    path = alert[ALERT_PATH];
    
    //extract pid
    pid = [alert[ALERT_PID] unsignedIntValue];
    
    //extact user
    user = [alert[ALERT_USER] unsignedIntValue];
    
    //extract action
    action = [alert[ALERT_ACTION] unsignedIntValue];
    
    //tell kext
    [kextComms addRule:pid action:action];
    
    //not temp?
    // save rule and process related
    if(YES != [alert[ALERT_TEMPORARY] boolValue])
    {
        //update rules
        // type of rule is 'user'
        [rules add:path signingInfo:alert[ALERT_SIGNINGINFO] action:action type:RULE_TYPE_USER user:user];
    }
    
    //process (any) related alerts
    // add to kext, etc...
    [alerts processRelated:alert];
    
    //remove from 'shown'
    [alerts removeShown:alert];
    
bail:
    
    return;
}

@end
