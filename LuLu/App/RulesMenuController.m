//
//  RulesMenuController.m
//  LuLu
//
//  Created by Patrick Wardle on 1/30/24.
//  Copyright © 2024 Objective-See. All rights reserved.
//

#import "consts.h"
#import "utilities.h"
#import "AppDelegate.h"
#import "XPCDaemonClient.h"
#import "RulesMenuController.h"

/* GLOBALS */

//log handle
extern os_log_t logHandle;

//xpc for daemon comms
extern XPCDaemonClient* xpcDaemonClient;

@implementation RulesMenuController

//show rules
// call into app delegate to show rules window
-(void)showRules
{
    //show rules
    [((AppDelegate*)[[NSApplication sharedApplication] delegate]) showRules:nil];
    
    return;
}

//add rule
// show rules, then call into app delegate to open add rule window
-(void)addRule
{
    //add rules
    [((AppDelegate*)[[NSApplication sharedApplication] delegate]).rulesWindowController addRule:nil];
    
    return;
}

//export rules
// show panel then write out rules
-(void)exportRules
{
    //count
    __block NSUInteger count = 0;
    
    //rules
    NSDictionary* rules = nil;
    
    //error
    __block NSError* error = nil;
    
    //'browse' panel
    NSSavePanel *panel = nil;
    
    //dbg msg
    os_log_debug(logHandle, "exporting rules...");
    
    //get rules
    rules = [xpcDaemonClient getRules];
    
    //dbg msg
    os_log_debug(logHandle, "received %lu rules from daemon", (unsigned long)rules.count);
    
    //init panel
    panel = [NSSavePanel savePanel];
    
    //default to ~/Desktop
    panel.directoryURL = [NSURL fileURLWithPath:[NSSearchPathForDirectoriesInDomains (NSDesktopDirectory, NSUserDomainMask, YES) firstObject]];
    
    //suggest file name
    [panel setNameFieldStringValue:NSLocalizedString(@"rules.json", @"rules.json")];
    
    //customize w/ "user only" rules options
    NSButton *userRulesOnly = [[NSButton alloc] initWithFrame:NSMakeRect(0, 0, 200, 24)];
    [userRulesOnly setButtonType:NSButtonTypeSwitch];
    userRulesOnly.title = NSLocalizedString(@"Only export user created rules", @"Only export user created rules");
    userRulesOnly.state = NSControlStateValueOff;
    [userRulesOnly sizeToFit];
    
    panel.accessoryView = userRulesOnly;
    
    //show panel
    // completion handler will invoked when user clicks 'ok'
    [panel beginWithCompletionHandler:^(NSInteger result) {
        
        //only need to handle 'ok'
        if(NSModalResponseOK == result)
        {
            //only user rules?
            BOOL exportUserOnly = (NSControlStateValueOn == userRulesOnly.state);
            
            //rules (as JSON)
            NSMutableString* json = [NSMutableString string];
            
            //start
            [json appendString:@"{"];
            
            //covert each rule (set)
            for(NSString* key in rules.allKeys)
            {
                //flag
                BOOL hasPersistentRule = NO;
                
                //flag
                BOOL hasUserCreatedRule = NO;
                
                //rule set
                NSDictionary* ruleSet = nil;
                
                //extract
                ruleSet = rules[key];
                
                //for a given item
                // check all rules for persistent or user created
                for(Rule* rule in rules[key][KEY_RULES])
                {
                    //not temp?
                    if(!hasPersistentRule && ![rule isTemporary]) {
                        hasPersistentRule = YES;
                    }
                    
                    //user created (non temp rule)
                    if(!hasUserCreatedRule && [rule isUserCreated] && ![rule isTemporary]) {
                        hasUserCreatedRule = YES;
                    }
                }
                
                //skip if all item's rules are temp
                if(YES != hasPersistentRule) {
                    continue;
                }
                
                //when exporting only user rules
                //skip if all item's rules are *not* user created
                if(exportUserOnly && !hasUserCreatedRule) {
                    continue;
                }
                
                //add key
                [json appendFormat:@"\"%@\" : [", key];
                
                //covert each rule
                for(Rule* rule in rules[key][KEY_RULES])
                {
                    //skip temp
                    if(YES == [rule isTemporary]) {
                        continue;
                    }
                    
                    //skip non user created
                    if(exportUserOnly && ![rule isUserCreated]) {
                        continue;
                    }
                        
                    //append rule
                    [json appendFormat:@"{%@},", [rule toJSON]];
                    
                    //inc
                    count++;
                }
                
                //remove last ','
                if(YES == [json hasSuffix:@","])
                {
                    //remove
                    [json deleteCharactersInRange:NSMakeRange(json.length-1, 1)];
                }
                
                //end
                [json appendString:@"],"];
            }
            
            //remove last ','
            if(YES == [json hasSuffix:@","])
            {
                //remove
                [json deleteCharactersInRange:NSMakeRange(json.length-1, 1)];
            }
            
            //end
            [json appendString:@"}"];
            
            //write out (converted) rules
            // then activate Finder and select file
            if(YES == [json writeToURL:panel.URL atomically:NO encoding:NSUTF8StringEncoding error:&error])
            {
                //activate Finder
                [NSWorkspace.sharedWorkspace selectFile:panel.URL.path inFileViewerRootedAtPath:@""];
            }
            //error
            else
            {
                //err msg
                os_log_error(logHandle, "ERROR: failed to save rules: %{public}@", error);
                
                //show alert
                showAlert(NSAlertStyleWarning, NSLocalizedString(@"ERROR: Failed to export rules",@"ERROR: Failed to export rules"), NSLocalizedString(@"See log for (more) details",@"See log for (more) details"), @[NSLocalizedString(@"OK", @"OK")]);
            }
        }
    }];

    return;
}

//import rules
// show panel, read in rules, parse, send to daemon
-(BOOL)importRules
{
    //flag
    BOOL imported = NO;
    
    //flag
    __block BOOL userOnlyImport = YES;
    
    //error
    NSError* error = nil;
    
    //count
    NSUInteger count = 0;
    
    //rules data
    NSData* data = nil;
    
    //rules from disk
    NSDictionary* importedRules = nil;
    
    //rules, as rules
    NSMutableDictionary* newRules = nil;
    
    //archived rules
    NSData* archivedRules = nil;
    
    //'browse' panel
    NSOpenPanel *panel = nil;
    
    //response to 'browse' panel
    NSInteger response = 0;
    
    //init panel
    panel = [NSOpenPanel openPanel];
    
    //allow files
    panel.canChooseFiles = YES;
    
    //disallow directories
    panel.canChooseDirectories = NO;
    
    //start in ~/Desktop
    panel.directoryURL = [NSURL fileURLWithPath:[NSSearchPathForDirectoriesInDomains (NSDesktopDirectory, NSUserDomainMask, YES) firstObject]];
    
    //disable multiple selections
    panel.allowsMultipleSelection = NO;
    
    //show it
    response = [panel runModal];
    if(NSModalResponseCancel == response)
    {
        //bail
        goto bail;
    }
    
    //load rules from specified file
    data = [NSData dataWithContentsOfFile:panel.URL.path options:NSDataReadingMappedIfSafe | NSDataReadingUncached error:&error];
    if(nil == data)
    {
        //err msg
        os_log_error(logHandle, "ERROR: failed to load (imported) rules from %{public}@ (error: %{public}@)", panel.URL.path, error);
        goto bail;
    }
    
    //deserialize
    @try
    {
        //convert
        importedRules = [NSJSONSerialization JSONObjectWithData:data options:kNilOptions error:&error];
        if(nil == importedRules)
        {
            //error msg
            os_log_error(logHandle, "ERROR: failed to convert imported rules from JSON (error: %{public}@)", error);
            goto bail;
        }
    }
    @catch(NSException* exception)
    {
        //bail
        goto bail;
    }
    
    //sanity check
    if(YES != [importedRules isKindOfClass:[NSDictionary class]])
    {
        //err msg
        os_log_error(logHandle, "ERROR: invalid format for imported rules (should be a dictionary, not a %{public}@)", importedRules.className);
        goto bail;
    }
    
    //init
    newRules = [NSMutableDictionary dictionary];
    
    //add each
    for(NSString* key in importedRules)
    {
        //sanity check
        if(YES != [importedRules[key] isKindOfClass:[NSArray class]])
        {
            //err msg
            os_log_error(logHandle, "ERROR: invalid format for imported rules (should be an array, not a %{public}@)", [importedRules[key] className]);
            goto bail;
        }
        
        //create rule obj for each
        for(NSDictionary* importedRule in importedRules[key])
        {
            //rule obj
            Rule* rule = [[Rule alloc] initFromJSON:importedRule];
           
            //skip if invalid
            if(nil == rule)
            {
                //err msg
                os_log_error(logHandle, "ERROR: invalid format for imported rule: %{public}@", importedRule);
                
                //skip
                continue;
            }
            
            //found a non-user created rule
            // means we're going to do a full import
            if(userOnlyImport && ![rule isUserCreated]) {
                userOnlyImport = NO;
            }
            
            //inc
            count++;
            
            //first rule
            // init dictionary, array, etc...
            if(nil == newRules[key])
            {
                //init
                newRules[key] = [NSMutableDictionary dictionary];
                newRules[key][KEY_RULES] = [NSMutableArray array];
                
                //add cs info
                if(nil != rule.csInfo)
                {
                    //add
                    newRules[key][KEY_CS_INFO] = rule.csInfo;
                }
            }
            
            //add rule obj
            [newRules[key][KEY_RULES] addObject:rule];
        }
    }
    
    //archive rules
    archivedRules = [NSKeyedArchiver archivedDataWithRootObject:newRules requiringSecureCoding:YES error:&error];
    if(nil == archivedRules)
    {
        //err msg
        os_log_error(logHandle, "ERROR: failed to archive rules: %{public}@", error);
    }
    
    //dbg msg
    os_log_debug(logHandle, "serialized (imported) rules");
    
    //send to daemon
    if(YES != [xpcDaemonClient importRules:archivedRules userOnly:userOnlyImport])
    {
        //bail
        goto bail;
    }
    
    //happy
    imported = YES;
    
    //tell (any) windows rules changed
    [[NSNotificationCenter defaultCenter] postNotificationName:RULES_CHANGED object:nil userInfo:nil];
    
    //show alert
    showAlert(NSAlertStyleInformational, [NSString stringWithFormat:NSLocalizedString(@"Imported %ld rules",@"Imported %ld rules"), count], nil, @[NSLocalizedString(@"OK", @"OK")]);
    
bail:
    
    return imported;
}

//cleanup rules
-(NSInteger)cleanupRules
{
    //result
    NSInteger cleanedUp = -1;
    
    //dbg msg
    os_log_debug(logHandle, "method '%s' invoked", __PRETTY_FUNCTION__);
    
    //first show rules
    [self showRules];
    
    //show alert
    // if user cancels, just bail
    if(NSAlertSecondButtonReturn == showAlert(NSAlertStyleInformational, NSLocalizedString(@"Clean up rules referencing deleted, expired, or terminated items?", @"Clean up rules referencing deleted, expired, or terminated items?"), nil, @[NSLocalizedString(@"OK",@"OK"), NSLocalizedString(@"Cancel",@"Cancel")]))
    {
        //dbg msg
        os_log_debug(logHandle, "user cancelled rule cleanup");
        
        //not an error though
        cleanedUp = 0;
        
        //bail
        goto bail;
    }
    
    //call into daemon to cleanup
    // returns number or deleted rules
    cleanedUp = [xpcDaemonClient cleanupRules:YES];
    if(cleanedUp < 0)
    {
        //bail
        goto bail;
    }
    
    //tell (any) windows rules changed
    [[NSNotificationCenter defaultCenter] postNotificationName:RULES_CHANGED object:nil userInfo:nil];
    
    //share results w/ user
    showAlert(NSAlertStyleInformational, [NSString stringWithFormat:NSLocalizedString(@"Cleaned up %ld rules",@"Cleaned up %ld rules"), cleanedUp], nil, @[NSLocalizedString(@"OK",@"OK")]);
    
bail:
    
    return cleanedUp;
}

@end
