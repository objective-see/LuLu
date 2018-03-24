//
//  file: HelperInterface.m
//  project: (open-source) installer
//  description: interface for app installer comms
//
//  created by Patrick Wardle
//  copyright (c) 2018 Objective-See. All rights reserved.
//

#import "consts.h"
#import "logging.h"
#import "utilities.h"
#import "HelperInterface.h"

#import <signal.h>

//script name
#define CONF_SCRIPT @"configure.sh"

//signing auth
#define SIGNING_AUTH @"Developer ID Application: Objective-See, LLC (VBG97UB4TA)"

//dispatch source for SIGTERM
dispatch_source_t dispatchSource = nil;

@implementation HelperInterface

//install
// do install logic and return result
-(void)install:(NSString*)app reply:(void (^)(NSNumber*))reply;
{
    //results
    NSNumber* result = nil;
    
    //dbg msg
    logMsg(LOG_NOTICE, [NSString stringWithFormat:@"XPC-request: install (%@)", app]);
    
    //configure
    // pass in 'install' flag
    result = [NSNumber numberWithInt:[self configure:app arguements:@[@"-install"]]];

    //reply to client
    reply(result);

    return;
}

//uninstall
// do uninstall logic and return result
-(void)uninstall:(NSString*)app full:(BOOL)full reply:(void (^)(NSNumber*))reply;
{
    //results
    NSNumber* result = nil;
    
    //dbg msg
    logMsg(LOG_DEBUG, @"XPC-request: uninstall");

    //configure
    // pass in 'uninstall' flag
    result = [NSNumber numberWithInt:[self configure:app arguements:@[@"-uninstall", [NSNumber numberWithBool:full].stringValue]]];
    
    //reply to client
    reply(result);
    
    return;
}

//configure
// install or uninstall
-(int)configure:(NSString*)app arguements:(NSArray*)args
{
    //result
    int result = -1;
    
    //valdiated (copy) of app
    NSString* validatedApp = nil;
    
    //validate app
    validatedApp = [self validateApp:app];
    if(nil == validatedApp)
    {
        //err msg
        logMsg(LOG_ERR, @"failed to validate copy of app");
        
        //bail
        goto bail;
    }
    
    //dbg msg
    logMsg(LOG_DEBUG, [NSString stringWithFormat:@"validated %@", app]);

    //exec script
    result = [self execScript:validatedApp arguments:args];
    if(noErr != result)
    {
        //err msg
        logMsg(LOG_ERR, [NSString stringWithFormat:@"failed to execute config script %@ (%d)", CONF_SCRIPT, result]);
        
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
        logMsg(LOG_ERR, [NSString stringWithFormat:@"failed to remove validated app %@", validatedApp]);
        
        //set err
        result = -1;
    }
    
    return result;
}

//remove self
// since system install/launches us as root, client can't directly remove us
-(void)remove
{
    //flag
    __block BOOL noErrors = YES;
    
    //helper plist
    __block NSString* helperPlist = nil;
    
    //binary
    __block NSString* helperBinary = nil;
    
    //error
    __block NSError* error = nil;
    
    //dbg msg
    logMsg(LOG_DEBUG, @"XPC-request: remove (self!)");
    
    //ignore sigterm
    // handling it via GCD dispatch
    signal(SIGTERM, SIG_IGN);
    
    //init dispatch source for SIGTERM
    dispatchSource = dispatch_source_create(DISPATCH_SOURCE_TYPE_SIGNAL, SIGTERM, 0, dispatch_get_main_queue());
    
    //set handler
    // disable kext & close logging
    dispatch_source_set_event_handler(dispatchSource, ^{
        
        //dbg msg
        logMsg(LOG_DEBUG, @"XPC: got SIGTERM, deleting plist & self!");
        
        //init path to plist
        helperPlist = [@"/Library/LaunchDaemons" stringByAppendingPathComponent:[NSString stringWithFormat:@"%@.plist", CONFIG_HELPER_ID]];
        
        //delete plist
        if(YES != [[NSFileManager defaultManager] removeItemAtPath:helperPlist error:&error])
        {
            //err msg
            logMsg(LOG_ERR, [NSString stringWithFormat:@"ERROR: failed to delete %@ (%@)", helperPlist, error.description]);
            
            //set error
            noErrors = NO;
        }
        
        //init path to binary
        helperBinary = [@"/Library/PrivilegedHelperTools" stringByAppendingPathComponent:CONFIG_HELPER_ID];
        
        //delete self
        if(YES != [[NSFileManager defaultManager] removeItemAtPath:helperBinary error:&error])
        {
            //err msg
            logMsg(LOG_ERR, [NSString stringWithFormat:@"ERROR: failed to delete %@ (%@)", helperBinary, error.description]);
            
            //set error
            noErrors = NO;
        }
        
        //no errors?
        // display dbg msg
        if(YES == noErrors)
        {
            //dbg msg
            logMsg(LOG_DEBUG, [NSString stringWithFormat:@"removed %@ and %@", helperPlist, helperBinary]);
        }
        
        //bye!
        exit(SIGTERM);
    });
    
    //resume
    dispatch_resume(dispatchSource);
    
    //init path to plist
    helperPlist = [@"/Library/LaunchDaemons" stringByAppendingPathComponent:[NSString stringWithFormat:@"%@.plist", CONFIG_HELPER_ID]];
    
    //unload
    execTask(@"/bin/launchctl", @[@"unload", helperPlist], YES);
    
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
    
    //dbg msg
    logMsg(LOG_DEBUG, [NSString stringWithFormat:@"validating %@", app]);
    
    //grab default file manager
    defaultManager = [NSFileManager defaultManager];
    
    //init path to app copy
    // *root-owned* tmp directory
    appCopy = [NSTemporaryDirectory() stringByAppendingPathComponent:app.lastPathComponent];
    
    //delete if old copy is there
    if(YES == [defaultManager fileExistsAtPath:appCopy])
    {
        //delete
        if(YES != [defaultManager removeItemAtPath:appCopy error:&error])
        {
            //err msg
            logMsg(LOG_ERR, [NSString stringWithFormat:@"failed to delete %@ (error: %@)", appCopy, error.description]);
        }
    }
    
    //copy app bundle to *root-owned* directory
    if(YES != [defaultManager copyItemAtPath:app toPath:appCopy error:&error])
    {
        //err msg
        logMsg(LOG_ERR, [NSString stringWithFormat:@"failed to copy %@ to %@ (error: %@)", app, appCopy, error.description]);
        
        //bail
        goto bail;
    }
    
    //set group/owner to root/wheel
    if(YES != setFileOwner(appCopy, @0, @0, YES))
    {
        //err msg
        logMsg(LOG_ERR, [NSString stringWithFormat:@"failed to set %@ to be owned by root", appCopy]);
        
        //bail
        goto bail;
    }
    
    //verify app
    // make sure it's signed, and by our signing auth
    if(noErr != verifyApp(appCopy, SIGNING_AUTH))
    {
        //err msg
        logMsg(LOG_ERR, [NSString stringWithFormat:@"failed to validate %@", appCopy]);
        
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
        logMsg(LOG_ERR, [NSString stringWithFormat:@"failed to load app bundle for %@", validatedApp]);
        
        //bail
        goto bail;
    }
    
    //get path to config script
    script = [[appBundle resourcePath] stringByAppendingPathComponent:CONF_SCRIPT];
    if(nil == script)
    {
        //err msg
        logMsg(LOG_ERR, [NSString stringWithFormat:@"failed to find config script %@", CONF_SCRIPT]);
        
        //bail
        goto bail;
    }
    
    //get current working directory
    currentWorkingDir = [fileManager currentDirectoryPath];
    
    //change working directory
    // set it to (validated) app path's resources
    [fileManager changeCurrentDirectoryPath:[NSString stringWithFormat:@"%@/Contents/Resources/", validatedApp]];
    
    //exec script
    results = execTask(script, arguments, YES);
    
    //grab result
    if(nil != results)
    {
        //grab
        result = [results[EXIT_CODE] intValue];
    }
    
    //no output means error
    // i.e. task exception, etc
    else
    {
        result = -1;
    }
    
    //(re)set current working directory
    [fileManager changeCurrentDirectoryPath:currentWorkingDir];

bail:
    
    return result;
}

@end
