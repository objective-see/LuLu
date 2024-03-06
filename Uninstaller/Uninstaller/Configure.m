//
//  file: Configure.m
//  project: lulu (config)
//  description: install/uninstall logic
//
//  created by Patrick Wardle
//  copyright (c) 2018 Objective-See. All rights reserved.
//

#import "consts.h"
#import "Configure.h"
#import "utilities.h"

@import Foundation;
@import ServiceManagement;

/* GLOBALS */

//log handle
extern os_log_t logHandle;

@implementation Configure

@synthesize gotHelp;
@synthesize xpcComms;

//init helper tool
// install and establish XPC connection
-(BOOL)initHelper
{
    //bail if we're already G2G
    if(YES == self.gotHelp)
    {
        //all set
        goto bail;
    }
    
    //install
    if(YES != [self blessHelper])
    {
        //err msg
        os_log_error(logHandle, "ERROR: failed to install helper tool");
        
        //bail
        goto bail;
    }
    
    //init XPC comms
    xpcComms = [[HelperComms alloc] init];
    if(nil == xpcComms)
    {
        //err msg
        os_log_error(logHandle, "ERROR: failed to connect to helper tool");
        
        //bail
        goto bail;
    }
    
    //happy
    self.gotHelp = YES;
    
bail:
    
    return self.gotHelp;
}

//install helper tool
// sets 'wasBlessed' iVar
-(BOOL)blessHelper
{
    //flag
    BOOL wasBlessed = NO;
    
    //auth ref
    AuthorizationRef authRef = NULL;
    
    //error
    CFErrorRef error = NULL;
    
    //auth item
    AuthorizationItem authItem = {};
    
    //auth rights
    AuthorizationRights authRights = {};
    
    //auth flags
    AuthorizationFlags authFlags = 0;
    
    //create auth
    if(errAuthorizationSuccess != AuthorizationCreate(NULL, kAuthorizationEmptyEnvironment, kAuthorizationFlagDefaults, &authRef))
    {
        //err msg
        os_log_error(logHandle, "ERROR: failed to create authorization");
        
        //bail
        goto bail;
    }
    
    //init auth item
    memset(&authItem, 0x0, sizeof(authItem));
    
    //set name
    authItem.name = kSMRightBlessPrivilegedHelper;
    
    //set auth count
    authRights.count = 1;
    
    //set auth items
    authRights.items = &authItem;
    
    //init flags
    authFlags =  kAuthorizationFlagDefaults | kAuthorizationFlagInteractionAllowed | kAuthorizationFlagPreAuthorize | kAuthorizationFlagExtendRights;
    
    //get auth rights
    if(errAuthorizationSuccess != AuthorizationCopyRights(authRef, &authRights, kAuthorizationEmptyEnvironment, authFlags, NULL))
    {
        //err msg
        os_log_error(logHandle, "ERROR: failed to copy authorization rights");
        
        //bail
        goto bail;
    }
    
    //bless
    if(YES != (BOOL)SMJobBless(kSMDomainSystemLaunchd, (__bridge CFStringRef)(CONFIG_HELPER_ID), authRef, &error))
    {
        //err msg
        os_log_error(logHandle, "ERROR: failed to bless job (%{public}@)", error);
        
        //bail
        goto bail;
    }
    
    //happy
    wasBlessed = YES;
    
bail:
    
    //free auth ref
    if(NULL != authRef)
    {
        //free
        AuthorizationFree(authRef, kAuthorizationFlagDefaults);
        
        //unset
        authRef = NULL;
    }
    
    //free error
    if(NULL != error)
    {
        //release
        CFRelease(error);
        
        //unset
        error = NULL;
    }
    
    return wasBlessed;
}

//remove helper (daemon)
-(BOOL)removeHelper
{
    //return/status var
    __block BOOL wasRemoved = NO;
    
    //wait semaphore
    dispatch_semaphore_t semaphore = 0;
    
    //init sema
    semaphore = dispatch_semaphore_create(0);
    
    //if needed
    // tell helper to remove itself
    if(YES == self.gotHelp)
    {
        //cleanup
        [self.xpcComms cleanup:^(NSNumber *result)
        {
            //save result
            wasRemoved = (BOOL)(result.intValue == 0);
            
            //unset var
            if(YES == wasRemoved)
            {
                //unset
                self.gotHelp = NO;
            }
            
            //signal sema
            dispatch_semaphore_signal(semaphore);
            
        }];
        
        //wait for installer logic to be completed by XPC
        dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);
    }
    //didn't need to remove
    // just set ret var to 'ok'
    else
    {
        //set
        wasRemoved = YES;
    }
    
    return wasRemoved;
}

//uninstall
-(BOOL)uninstall:(NSInteger)action
{
    //return/status var
    __block BOOL wasUninstalled = NO;
    
    //wait semaphore
    dispatch_semaphore_t semaphore = 0;
    
    //init sema
    semaphore = dispatch_semaphore_create(0);
    
    //define block
    void (^block)(NSNumber *) = ^(NSNumber *result)
    {
        //save result
        wasUninstalled = (BOOL)(result.intValue == 0);
        
        //signal sema
        dispatch_semaphore_signal(semaphore);
    };
    
    //uninstall login item, first
    // can't do this in script since it needs to be executed as logged in user (not r00t)
    if(YES != [self removeLoginItem:action])
    {
        //err msg
        os_log_error(logHandle, "ERROR: failed to uninstall login item(s)");
        
        //keep going though...
    }
    
    //make sure helper was init'd
    if(YES == [self initHelper])
    {
        //uninstall
        // also sets return/var flag
        [xpcComms uninstall:!action reply:block];
    }
    
    //error
    else
    {
        //err msg
        os_log_error(logHandle, "ERROR: failed to initialized helper tool");
        
        //bail
        goto bail;
    }
        
    //dbg msg
    os_log_debug(logHandle, "waiting for XPC to set completion semaphore...");
    
    //wait for install to be completed by XPC
    dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);

bail:
    
    return wasUninstalled;
}

//for login item enable/disable
// we use the launch services APIs, since replacements don't always work :(
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"

//toggle login item(s)
// if action is full uninstall
-(BOOL)removeLoginItem:(NSInteger)action
{
    //flag
    BOOL wasRemoved = NO;
    
    //login item ref
    LSSharedFileListRef loginItemsRef = NULL;
    
    //login items
    CFArrayRef loginItems = NULL;
    
    //current login item
    CFURLRef currentLoginItem = NULL;
    
    //bundle id
    NSString* bundleID = nil;
        
    //get reference to login items
    loginItemsRef = LSSharedFileListCreate(NULL, kLSSharedFileListSessionLoginItems, NULL);
    
    //dbg msg
    os_log_debug(logHandle, "removing login item(s)");
        
    //grab existing login items
    loginItems = LSSharedFileListCopySnapshot(loginItemsRef, nil);
    
    //iterate over all login items
    // look for self(s), then remove it
    for(id item in (__bridge NSArray *)loginItems)
    {
        //get current login item
        currentLoginItem = LSSharedFileListItemCopyResolvedURL((__bridge LSSharedFileListItemRef)item, 0, NULL);
        if(NULL == currentLoginItem)
        {
            //skip
            continue;
        }
        
        //full?
        // remove anything both app and login item
        if(ACTION_UNINSTALL_FLAG == action)
        {
            //extract bundle ID
            bundleID = [[NSBundle bundleWithURL:(__bridge NSURL *)currentLoginItem] bundleIdentifier];
            
            //check for LuLu*
            if( (YES == [bundleID isEqualToString:HELPER_ID]) ||
                (YES == [bundleID isEqualToString:MAIN_APP_ID]) )
            {
                //dbg msg
                os_log_debug(logHandle, "removing login item: %{public}@", currentLoginItem);
                
                //remove
                LSSharedFileListItemRemove(loginItemsRef, (__bridge LSSharedFileListItemRef)item);
                
                //set flag
                wasRemoved = YES;
            }
        }
        //just remove v1.0 login item
        else if(YES == [((__bridge NSURL *)currentLoginItem).path containsString:LOGIN_ITEM_NAME])
        {
            //dbg msg
            os_log_debug(logHandle, "removing login item: %{public}@", currentLoginItem);
            
            //remove
            LSSharedFileListItemRemove(loginItemsRef, (__bridge LSSharedFileListItemRef)item);
            
            //set flag
            wasRemoved = YES;
        }
        
        //release
        CFRelease(currentLoginItem);
        
        //reset
        currentLoginItem = NULL;
        
    }//all login items
        
    //release login items
    if(NULL != loginItems)
    {
        //release
        CFRelease(loginItems);
        
        //reset
        loginItems = NULL;
    }
    
    //release login ref
    if(NULL != loginItemsRef)
    {
        //release
        CFRelease(loginItemsRef);
        
        //reset
        loginItemsRef = NULL;
    }
    
    return wasRemoved;
}

#pragma clang diagnostic pop

@end
