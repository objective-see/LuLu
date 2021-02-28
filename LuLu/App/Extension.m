//
//  Extension.m
//  LuLu
//
//  Created by Patrick Wardle on 9/11/20.
//  Copyright (c) 2020 Objective-See. All rights reserved.
//

#import "consts.h"
#import "Extension.h"
#import "utilities.h"
#import "AppDelegate.h"

/* GLOBALS */

//log handle
extern os_log_t logHandle;

@implementation Extension

//submit request to toggle system extension
-(void)toggleExtension:(NSUInteger)action reply:(void (^)(BOOL))reply
{
    //request
    OSSystemExtensionRequest* request = nil;
    
    //dbg msg
    os_log_debug(logHandle, "toggling extension (action: %lu)", (unsigned long)action);
    
    //save reply
    self.replyBlock = reply;
        
    //activation request
    if(ACTION_ACTIVATE == action)
    {
        //dbg msg
        os_log_debug(logHandle, "creating activation request");
        
        //init request
        request = [OSSystemExtensionRequest activationRequestForExtension:EXT_BUNDLE_ID queue:dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0)];
    }
    //deactivation request
    else
    {
        //dbg msg
        os_log_debug(logHandle, "creating deactivation request");
        
        //init request
        request = [OSSystemExtensionRequest deactivationRequestForExtension:EXT_BUNDLE_ID queue:dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0)];
    }
    
    //sanity check
    if(nil == request)
    {
        //err msg
        os_log_error(logHandle, "ERROR: failed to create request for extension");
        
        //bail
        goto bail;
    }
    
    //set delegate
    request.delegate = self;
    
    //dbg msg
    os_log_debug(logHandle, "submitting request");
       
    //submit request
    [OSSystemExtensionManager.sharedManager submitRequest:request];
    
    //dbg msg
    os_log_debug(logHandle, "submitting request returned...");
    
bail:
    
    return;
    
}

//check if extension is running
-(BOOL)isExtensionRunning
{
    return (-1 != (findProcess(EXT_BUNDLE_ID)));
}

//get network extension's status
-(BOOL)isNetworkExtensionEnabled
{
    return NEFilterManager.sharedManager.isEnabled;
}

//activate/deactive network extension
-(BOOL)toggleNetworkExtension:(NSUInteger)action
{
    //flag
    BOOL toggled = NO;
    
    //error
    __block BOOL wasError = NO;
    
    //config
    __block NEFilterProviderConfiguration* config = nil;
    
    //wait semaphore
    dispatch_semaphore_t semaphore = 0;
    
    //init wait semaphore
    semaphore = dispatch_semaphore_create(0);
    
    //dbg msg
    os_log_debug(logHandle, "toggling network extension: %lu", (unsigned long)action);
    
    //load prefs
    [NEFilterManager.sharedManager loadFromPreferencesWithCompletionHandler:^(NSError * _Nullable error) {
        
        //err?
        if(nil != error)
        {
            //set flag
            wasError = YES;
            
            //err msg
            os_log_error(logHandle, "ERROR: 'loadFromPreferencesWithCompletionHandler' failed with %{public}@", error);
        }
    
        //signal semaphore
        dispatch_semaphore_signal(semaphore);
        
    }];
    
    //dbg msg
    os_log_debug(logHandle, "waiting for network extension configuration...");
    
    //wait for request to complete
    dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);
      
    //error?
    if(YES == wasError) goto bail;
   
    //dbg msg
    os_log_debug(logHandle, "loaded current filter configuration for the network extension");

    //activate?
    if(ACTION_ACTIVATE == action)
    {
        //dbg msg
        os_log_debug(logHandle, "activating network extension...");
        
        //no config?
        // alloc/init/set one...
        // and then set 'enabled' flag
        if(nil == NEFilterManager.sharedManager.providerConfiguration)
        {
            //init config
            config = [[NEFilterProviderConfiguration alloc] init];
            
            //don't care about packets
            config.filterPackets = NO;
            
            //filter sockets!
            config.filterSockets = YES;
            
            //set config
            NEFilterManager.sharedManager.providerConfiguration = config;
        }
        
        //set flag
        NEFilterManager.sharedManager.enabled = YES;
    }
    
    //deactivate
    // just set 'enabled' flag
    else
    {
        //dbg msg
        os_log_debug(logHandle, "deactivating network extension...");
        
        //set flag
        NEFilterManager.sharedManager.enabled = NO;
    }
    
    //save preferences
    { [NEFilterManager.sharedManager saveToPreferencesWithCompletionHandler:^(NSError * _Nullable error) {
        
        //error?
        if(nil != error)
        {
            //set flag
            wasError = YES;
            
            //err msg
            os_log_error(logHandle, "ERROR: 'saveToPreferencesWithCompletionHandler' failed with %{public}@", error);
        }
        
        //signal semaphore
        dispatch_semaphore_signal(semaphore);
            
    }]; }
    
    //dbg msg
    os_log_debug(logHandle, "waiting for network extension configuration to save...");
    
    //wait for request to complete
    dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);
    
    //error?
    if(YES == wasError) goto bail;
    
    //dbg msg
    os_log_debug(logHandle, "saved current filter configuration for the network extension");
    
    //happy
    toggled = YES;
        
bail:
    
    return toggled;
}

#pragma mark -
#pragma mark OSSystemExtensionRequest delegate methods

//replace delegate method
// always replaces, so return 'OSSystemExtensionReplacementActionReplace'
-(OSSystemExtensionReplacementAction)request:(nonnull OSSystemExtensionRequest *)request actionForReplacingExtension:(nonnull OSSystemExtensionProperties *)existing withExtension:(nonnull OSSystemExtensionProperties *)ext
{
    //dbg msg
    os_log_debug(logHandle, "method '%s' invoked with %{public}@, %{public}@ -> %{public}@", __PRETTY_FUNCTION__, request.identifier, existing.bundleShortVersion, ext.bundleShortVersion);
    
    return OSSystemExtensionReplacementActionReplace;
}

//error delegate method
-(void)request:(nonnull OSSystemExtensionRequest *)request didFailWithError:(nonnull NSError *)error
{
    //err msg
    os_log_error(logHandle, "ERROR: method '%s' invoked with %{public}@, %{public}@", __PRETTY_FUNCTION__, request, error);
    
    //invoke reply
    self.replyBlock(NO);

    return;
}

//finish delegate method
// install request? now can activate network ext
// uninstall request? now can complete uninstall
-(void)request:(nonnull OSSystemExtensionRequest *)request didFinishWithResult:(OSSystemExtensionRequestResult)result {
    
    //happy
    BOOL completed = NO;
    
    //dbg msg
    os_log_debug(logHandle, "method '%s' invoked with %{public}@, %ld", __PRETTY_FUNCTION__, request, (long)result);
   
    //issue/error?
    if(OSSystemExtensionRequestCompleted != result)
    {
        //err msg
        os_log_error(logHandle, "ERROR: result %ld is an unexpected result for system extension request", (long)result);
        
        //bail
        goto bail;
    }
    
    //happy
    completed = YES;
    
bail:
    
    //reply
    self.replyBlock(completed);
    
    return;
}

//user approval delegate
// if this isn't the first time launch, will alert user to approve
-(void)requestNeedsUserApproval:(nonnull OSSystemExtensionRequest *)request {
    
    //dbg msg
    os_log_debug(logHandle, "method '%s' invoked with %{public}@", __PRETTY_FUNCTION__, request);
    
    //on main thread
    // check and invoke
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        
        //not first time?
        // show alert telling user to approve extension
        if(YES != [((AppDelegate*)[[NSApplication sharedApplication] delegate]) isFirstTime])
        {
            //show alert
            showAlert(@"LuLu's Network Extension Is Not Running", @"Extensions must be manually approved via\r\nSecurity & Privacy System Preferences.");
        }
    });
    
    return;
}

@end
