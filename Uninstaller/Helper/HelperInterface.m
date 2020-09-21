//
//  file: HelperInterface.m
//  project: (open-source) installer
//  description: interface for app installer comms
//
//  created by Patrick Wardle
//  copyright (c) 2018 Objective-See. All rights reserved.
//

#import "consts.h"
#import "utilities.h"

//#define CONF_SCRIPT @"configure.sh"

#import "HelperInterface.h"

#import <signal.h>

//script name
#define CONF_SCRIPT @"configure.sh"

//installer (helper) ID
#define CONFIG_HELPER_ID @"com.objective-see.lulu.configHelper"

//signing auth
#define SIGNING_AUTH @"Developer ID Application: Objective-See, LLC (VBG97UB4TA)"

/* GLOBALS */

//log handle
extern os_log_t logHandle;

//dispatch source for SIGTERM
dispatch_source_t dispatchSource = nil;

@implementation HelperInterface

//uninstall
// do uninstall logic and return result
-(void)uninstall:(NSString*)app full:(BOOL)full reply:(void (^)(NSNumber*))reply;
{
    //results
    int result = -1;
    
    //valdiated (copy) of app
    NSString* validatedApp = nil;
    
    //dbg msg
    os_log_debug(logHandle, "method '%s' invoked", __PRETTY_FUNCTION__);

    //validate app
    validatedApp = [self validateApp:app];
    if(nil == validatedApp)
    {
        //err msg
        os_log_error(logHandle, "ERROR: failed to validate copy of app");
        
        //bail
        goto bail;
    }
    
    //dbg msg
    os_log_debug(logHandle, "validated %{public}@", app);
    
    //exec script
    result = [self execScript:validatedApp arguments:@[CMD_UNINSTALL, [NSNumber numberWithBool:full].stringValue]];
    if(noErr != result)
    {
        //err msg
        os_log_error(logHandle, "ERROR: failed to execute config script %{public}@ (%d)", CONF_SCRIPT, result);
        
        //bail
        goto bail;
    }
        
    //happy
    result = 0;
        
bail:
        
    //always try to remove validated app
    if(YES != [[NSFileManager defaultManager] removeItemAtPath:validatedApp error:nil])
    {
        //err msg
        os_log_error(logHandle, "ERROR: failed to remove validated app %@", validatedApp);
        
        //set err
        result = -1;
    }
        
    //reply to client
    reply([NSNumber numberWithInt:result]);
    
    return;
}

//cleanup by removing self
// since system install/launches us as root, client can't directly remove us
-(void)cleanup:(void (^)(NSNumber*))reply
{
    //results
    __block NSNumber* result = nil;
    
    //flag
    __block BOOL noErrors = YES;
    
    //helper plist
    __block NSString* helperPlist = nil;
    
    //binary
    __block NSString* helperBinary = nil;
    
    //error
    __block NSError* error = nil;
    
    //dbg msg
    os_log_debug(logHandle, "method '%s' invoked", __PRETTY_FUNCTION__);
    
    //init
    result = @-1;
    
    //ignore sigterm
    // handling it via GCD dispatch
    signal(SIGTERM, SIG_IGN);
    
    //init dispatch source for SIGTERM
    dispatchSource = dispatch_source_create(DISPATCH_SOURCE_TYPE_SIGNAL, SIGTERM, 0, dispatch_get_main_queue());
    
    //set handler
    // deletes plist and self
    dispatch_source_set_event_handler(dispatchSource, ^{
        
        //dbg msg
        os_log_debug(logHandle, "XPC: got SIGTERM, deleting plist & self");
        
        //init path to plist
        helperPlist = [@"/Library/LaunchDaemons" stringByAppendingPathComponent:[NSString stringWithFormat:@"%@.plist", CONFIG_HELPER_ID]];
        
        //delete plist
        if(YES != [[NSFileManager defaultManager] removeItemAtPath:helperPlist error:&error])
        {
            //err msg
            os_log_error(logHandle, "ERROR: failed to delete %{public}@ (%{public}@)", helperPlist, error.description);
            
            //set error
            noErrors = NO;
        }
        
        //init path to binary
        helperBinary = [@"/Library/PrivilegedHelperTools" stringByAppendingPathComponent:CONFIG_HELPER_ID];
        
        //delete self
        if(YES != [[NSFileManager defaultManager] removeItemAtPath:helperBinary error:&error])
        {
            //err msg
            os_log_error(logHandle, "ERROR: failed to delete %{public}@ (%{public}@)", helperBinary, error.description);
            
            //set error
            noErrors = NO;
        }
        
        //no errors?
        // display dbg msg
        if(YES == noErrors)
        {
            //happy
            result = @0;
            
            //dbg msg
            os_log_debug(logHandle, "removed %{public}@ and %{public}@", helperPlist, helperBinary);
        }
        
        //reply to client
        reply(result);
        
        //bye!
        exit(SIGTERM);
        
    });
    
    //resume
    dispatch_resume(dispatchSource);
    
    //init path to plist
    helperPlist = [@"/Library/LaunchDaemons" stringByAppendingPathComponent:[NSString stringWithFormat:@"%@.plist", CONFIG_HELPER_ID]];
    
    //unload
    // will trigger sigterm
    execTask(@"/bin/launchctl", @[@"unload", helperPlist], YES, NO);
    
    return;
}

//make copy of app and validate
-(NSString*)validateApp:(NSString*)app
{
    //copy of app
    NSString* appCopy = nil;
    
    //file manager
    NSFileManager* defaultManager = nil;
    
    //path to (now) validated app
    NSString* validatedApp = nil;
    
    //error
    NSError* error = nil;
    
    //grab default file manager
    defaultManager = [NSFileManager defaultManager];
    
    //init path to app copy
    // *root-owned* tmp directory
    appCopy = [NSTemporaryDirectory() stringByAppendingPathComponent:app.lastPathComponent];
    
    //dbg msg
    os_log_debug(logHandle, "validating %{public}@", appCopy);
    
    //delete if old copy is there
    if(YES == [defaultManager fileExistsAtPath:appCopy])
    {
        //delete
        if(YES != [defaultManager removeItemAtPath:appCopy error:&error])
        {
            //err msg
            os_log_error(logHandle, "ERROR: failed to delete %{public}@ (error: %{public}@)", appCopy, error.description);
        }
    }
    
    //copy app bundle to *root-owned* directory
    if(YES != [defaultManager copyItemAtPath:app toPath:appCopy error:&error])
    {
        //err msg
        os_log_error(logHandle, "ERROR: failed to copy %{public}@ to %{public}@ (error: %{public}@)", app, appCopy, error.description);
        
        //bail
        goto bail;
    }
    
    //set group/owner to root/wheel
    if(YES != setFileOwner(appCopy, @0, @0, YES))
    {
        //err msg
        os_log_error(logHandle, "ERROR: failed to set %{public}@ to be owned by root", appCopy);
        
        //bail
        goto bail;
    }
    
    //verify app
    // make sure it's signed, and by our signing auth
    if(noErr != verifyApp(appCopy, SIGNING_AUTH))
    {
        //err msg
        os_log_error(logHandle, "ERROR: failed to validate %{public}@", appCopy);
        
        //bail
        goto bail;
    }
    
    //happy
    validatedApp = appCopy;
    
bail:
    
    return validatedApp;
}

//execute config script
-(int)execScript:(NSString*)validatedApp arguments:(NSArray*)arguments
{
    //result
    int result = -1;
    
    //results
    NSDictionary* results = nil;
    
    //script
    NSString* script = nil;
    
    //app bundle
    NSBundle* appBundle = nil;
    
    //file manager
    NSFileManager* fileManager = nil;
    
    //current working directory
    NSString* currentWorkingDir = nil;
    
    //init file manager
    fileManager = [NSFileManager defaultManager];

    //load app bundle
    appBundle = [NSBundle bundleWithPath:validatedApp];
    if(nil == appBundle)
    {
        //err msg
        os_log_error(logHandle, "ERROR: failed to load app bundle for %{public}@", validatedApp);
        
        //bail
        goto bail;
    }
    
    //get path to config script
    script = [[appBundle resourcePath] stringByAppendingPathComponent:CONF_SCRIPT];
    if(nil == script)
    {
        //err msg
        os_log_error(logHandle, "ERROR: failed to find config script %{public}@", CONF_SCRIPT);
        
        //bail
        goto bail;
    }
    
    //get current working directory
    currentWorkingDir = [fileManager currentDirectoryPath];
    
    //change working directory
    // set it to (validated) app path's resources
    [fileManager changeCurrentDirectoryPath:[NSString stringWithFormat:@"%@/Contents/Resources/", validatedApp]];
    

    //exec script
    // wait, but don't grab output
    results = execTask(script, arguments, YES, NO);
    
    //exit code?
    if(nil != results[EXIT_CODE])
    {
        //grab
        result = [results[EXIT_CODE] intValue];
    }
    
    //(re)set current working directory
    [fileManager changeCurrentDirectoryPath:currentWorkingDir];

bail:
    
    return result;
}

@end
