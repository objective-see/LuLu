//
//  file: Baseline.m
//  project: lulu (launch daemon)
//  description: enumeration/processing of (pre)installed applications (header)
//
//  created by Patrick Wardle
//  copyright (c) 2018 Objective-See. All rights reserved.
//

#import "consts.h"
#import "logging.h"
#import "procInfo.h"
#import "Baseline.h"
#import "utilities.h"

@implementation Baseline

@synthesize preInstalledApps;

//process output from 'system_profiler'
// serialized, and saving info about (only) 3rd-party ones
-(BOOL)processAppData:(NSString*)path
{
    //flag
    BOOL processed = NO;
    
    //app data
    NSArray* appData = nil;

    //name
    NSString* name = nil;
    
    //signing info
    NSArray* signedBy = nil;
    
    //hash
    NSString* hash = nil;
    
    //LuLu app
    Binary* lulu = nil;
    
    //dbg msg
    logMsg(LOG_DEBUG, @"processing (pre)installed app list from 'system_profiler'");
    
    //alloc dictionary
    self.preInstalledApps = [NSMutableDictionary dictionary];
    
    //load app data
    appData = [NSArray arrayWithContentsOfFile:path];
    
    //sanity check(s)
    if( (nil == appData) ||
        (YES != [appData.firstObject isKindOfClass:[NSDictionary class]]) )
    {
        //bail
        goto bail;
    }
    
    //process installed apps
    // save any 3rd-party ones into array
    for(NSDictionary* installedApp in appData.firstObject[@"_items"])
    {
        //sanity check
        if(nil == installedApp[@"path"])
        {
            //skip
            continue;
        }
        
        //get full path to app's binary
        path = getAppBinary(installedApp[@"path"]);
        if(nil == path)
        {
            //skip
            continue;
        }
        
        //grab signing info
        signedBy = installedApp[@"signed_by"];
        
        //skip apple (proper) signed apps
        if( (YES == [signedBy.lastObject isEqualToString:@"Apple Root CA"]) &&
            (YES == [signedBy.firstObject isEqualToString:@"Software Signing"]) )
        {
            //skip
            continue;
        }
        
        //extract name
        name = installedApp[@"_name"];
        
        //add w/ blank dictionary
        self.preInstalledApps[path] = [NSMutableDictionary dictionary];
        
        //add name
        if(nil != name)
        {
            //add
            self.preInstalledApps[path][KEY_NAME] = name;
        }
        
        //signed?
        // add signing info
        if(nil != signedBy)
        {
            //add
            self.preInstalledApps[path][KEY_SIGNATURE_AUTHORITIES] = signedBy;
        }
        //unsigned
        // generate and save hash
        else
        {
            //hash
            hash = hashFile(path);
            if(nil != hash)
            {
                //add
                self.preInstalledApps[path][KEY_HASH] = hash;
            }
        }
        
        //dbg msg
        logMsg(LOG_DEBUG, [NSString stringWithFormat:@"added: %@ / %@", path, self.preInstalledApps[path]]);
    }
    
    //init binary obj for LuLu app
    // then add it to list of preinstalled apps
    lulu = [[Binary alloc] init:[NSString pathWithComponents:@[@"/", @"Applications", APP_NAME, @"Contents", @"MacOS", @"LuLu"]]];
    if(nil != lulu)
    {
        //generate signing info
        [lulu generateSigningInfo:kSecCSDefaultFlags];
        
        //add LuLu
        self.preInstalledApps[lulu.path] = @{KEY_NAME:lulu.name, KEY_SIGNATURE_AUTHORITIES:lulu.signingInfo[KEY_SIGNATURE_AUTHORITIES]};
    }
    
    //dbg msg
    logMsg(LOG_DEBUG, [NSString stringWithFormat:@"found %ld (pre)installed 3rd-party apps", preInstalledApps.count]);
    
    //save
    if(YES != [self save])
    {
        //err msg
        logMsg(LOG_ERR, @"failed to save installed (pre)installed apps");
        
        //bail
        goto bail;
    }
    
    //dbg msg
    logMsg(LOG_DEBUG, @"saved processed list of (pre)installed applications");
    
    //happy
    processed = YES;
    
bail:
    
    return processed;
}

//load (pre)installed apps from file
-(BOOL)load
{
    //flag
    BOOL loaded = NO;
    
    //path
    NSString* path = nil;
    
    //init path
    path = [INSTALL_DIRECTORY stringByAppendingPathComponent:[NSString stringWithFormat:@"%@.plist", INSTALLED_APPS]];
    
    //load
    self.preInstalledApps = [NSMutableDictionary dictionaryWithContentsOfFile:path];
    if(nil == self.preInstalledApps)
    {
        //err msg
        logMsg(LOG_ERR, [NSString stringWithFormat:@"failed to load (pre)installed apps from %@", path]);
        
        //bail
        goto bail;
    }
    
    //dbg msg
    logMsg(LOG_DEBUG, [NSString stringWithFormat:@"loaded %lu (pre)installed apps", self.preInstalledApps.count]);
    
    //happy
    loaded = YES;
    
bail:
    
    return loaded;
}

//determine if a proc's binary was installed before lulu
// checks if path is in list and hash/signing ID matches
// note: pass in signing info, since can called for process or binary
-(BOOL)wasInstalled:(Binary*)binary signingInfo:(NSDictionary*)signingInfo
{
    //flag
    BOOL preInstalled = NO;
    
    //preinstalled binary
    NSDictionary* preInstalledBinary = nil;
    
    //thread priority
    double threadPriority = 0.0f;
    
    //dbg msg
    logMsg(LOG_DEBUG, [NSString stringWithFormat:@"checking if %@ is in (pre)installed apps", binary.path]);
    
    //lookup preinstalled binary
    preInstalledBinary = self.preInstalledApps[binary.path];
    if(nil == preInstalledBinary)
    {
        //dbg msg
        logMsg(LOG_DEBUG, @"not found in list of (pre)installed apps");
        
        //bail
        goto bail;
    }
    
    //dbg msg
    logMsg(LOG_DEBUG, @"found in list of (pre)installed apps, will check signing info/hash");
    
    //check signing info
    // all signing auths should match
    if( (nil != preInstalledBinary[KEY_SIGNATURE_AUTHORITIES]) &&
        (nil != signingInfo) )
    {
        //signing error?
        if(noErr != [signingInfo[KEY_SIGNATURE_STATUS] intValue])
        {
            //err msg
            logMsg(LOG_ERR, [NSString stringWithFormat:@"%@ has a signing error (%@)", binary.path, signingInfo[KEY_SIGNATURE_STATUS]]);
            
            //bail
            goto bail;
        }
        
        //compare all signing auths
        if(YES != [[NSCountedSet setWithArray:preInstalledBinary[KEY_SIGNATURE_AUTHORITIES]] isEqualToSet: [NSCountedSet setWithArray:signingInfo[KEY_SIGNATURE_AUTHORITIES]]] )
        {
            //err msg
            logMsg(LOG_ERR, [NSString stringWithFormat:@"signing authority mismatch between %@/%@", preInstalledBinary[KEY_SIGNATURE_AUTHORITIES], signingInfo[KEY_SIGNATURE_AUTHORITIES]]);
            
            //bail
            goto bail;
        }
        
        //dbg msg
        logMsg(LOG_DEBUG, @"signing info matches with (pre)installed binary");
        
        //happy
        preInstalled = YES;
    }
    
    //check hash
    // any unsigned app should have this...
    else if(nil != preInstalledBinary[KEY_HASH])
    {
        //need hash?
        if(nil == binary.sha256)
        {
            //save thread priority
            threadPriority = [NSThread threadPriority];
            
            //reduce CPU
            [NSThread setThreadPriority:0.25];
            
            //hash binary
            [binary generateHash];

            //reset thread priority
            [NSThread setThreadPriority:threadPriority];
        }
        
        //match?
        if(YES != [preInstalledBinary[KEY_HASH] isEqualToString:binary.sha256])
        {
            //err msg
            logMsg(LOG_ERR, @"unsigned app binary, hash does not match");
            
            //bail
            goto bail;
        }
        
        //dbg msg
        logMsg(LOG_DEBUG, @"unsigned app binary, but hash matches with (pre)installed binary");
        
        //happy
        preInstalled = YES;
    }
    
bail:
    
    return preInstalled;
}

//determine if a child process has parent installed before lulu
// finds parent, and validates signing info and signing auths is #samesame!
-(BOOL)wasParentInstalled:(Process*)childProcess
{
    //flag
    BOOL preInstalled = NO;
    
    //parent binary (obj)
    Binary* parentBinary = nil;
    
    //parent app
    NSString* parentAppPath = nil;
    
    //parent binary
    NSString* parentBinaryPath = nil;
    
    //thread priority
    double threadPriority = 0.0f;
    
    //default cs flags
    SecCSFlags flags = kSecCSDefaultFlags | kSecCSCheckNestedCode | kSecCSDoNotValidateResources | kSecCSCheckAllArchitectures;
    
    //dbg msg
    logMsg(LOG_DEBUG, [NSString stringWithFormat:@"checking if %@ has a (pre)installed parent app", childProcess.binary.path]);
    
    //get parent
    parentAppPath = topLevelApp(childProcess.binary.path);
    if(nil == parentAppPath)
    {
        //dbg msg
        logMsg(LOG_DEBUG, @"no top-level/parent app found");
        
        //bail
        goto bail;
    }
    
    //dbg msg
    logMsg(LOG_DEBUG, [NSString stringWithFormat:@"top-level app: %@", parentAppPath]);
    
    //get top level's app binary
    parentBinaryPath = getAppBinary(parentAppPath);
    if(nil == parentBinaryPath)
    {
        //dbg msg
        logMsg(LOG_DEBUG, @"no parent app binary found");
        
        //bail
        goto bail;
    }
    
    //dbg msg
    logMsg(LOG_DEBUG, [NSString stringWithFormat:@"parent (top-level app binary): %@", parentBinaryPath]);

    //make sure binary isn't top level
    // already checked that this *is not* (pre)installed
    if(YES == [parentBinaryPath isEqualToString:childProcess.binary.path])
    {
        //dbg msg
        logMsg(LOG_DEBUG, [NSString stringWithFormat:@"%@ has no parent", childProcess.binary.path]);
        
        //bail
        goto bail;
    }
    
    //generate binary obj for parent
    parentBinary = [[Binary alloc] init:parentBinaryPath];
    if(nil == parentBinary)
    {
        //err msg
        logMsg(LOG_ERR, @"failed to create parent binary object");
        
        //bail
        goto bail;
    }
    
    //save thread priority
    threadPriority = [NSThread threadPriority];
        
    //reduce CPU
    [NSThread setThreadPriority:0.25];
        
    //dbg msg
    logMsg(LOG_DEBUG, [NSString stringWithFormat:@"generating code signing info for %@ with flags: %d", parentBinary.name, flags]);
        
    //generate signing info
    [parentBinary generateSigningInfo:flags];
    
    //reset thread priority
    [NSThread setThreadPriority:threadPriority];
    
    //on error bail
    // can only check if child was pre-installed based on signing auths...
    if( (nil == parentBinary.signingInfo) ||
        (errSecSuccess != [parentBinary.signingInfo[KEY_SIGNATURE_STATUS] intValue]) )
    {
        //dbg msg
        logMsg(LOG_DEBUG, [NSString stringWithFormat:@"parent %@ isn't signed, or cannot be validated", parentBinary.path]);
        
        //bail
        goto bail;
    }

    //dbg msg
    logMsg(LOG_DEBUG, @"done generating code signing info for parent");

    //now, check if parent is (pre)installed
    if(YES != [self wasInstalled:parentBinary signingInfo:parentBinary.signingInfo])
    {
        //dbg msg
        logMsg(LOG_DEBUG, @"parent not found in list of (pre)installed apps");
        
        //bail
        goto bail;
    }
    
    //dbg msg
    logMsg(LOG_DEBUG, @"parent is a pre-installed application");

    //compare all signing auths
    // child has to match all of these to be allowed
    if(YES != [[NSCountedSet setWithArray:childProcess.signingInfo[KEY_SIGNATURE_AUTHORITIES]] isEqualToSet: [NSCountedSet setWithArray:parentBinary.signingInfo[KEY_SIGNATURE_AUTHORITIES]]] )
    {
        //dbg msg
        logMsg(LOG_DEBUG, [NSString stringWithFormat:@"signing authority mismatch between %@/%@", childProcess.signingInfo[KEY_SIGNATURE_AUTHORITIES], parentBinary.signingInfo[KEY_SIGNATURE_AUTHORITIES]]);
        
        //bail
        goto bail;
    }
    
    //dbg msg
    logMsg(LOG_DEBUG, [NSString stringWithFormat:@"signing info for child %@ matches with pre-installed parent %@", childProcess.binary.name, parentBinary.name]);
    
    //happy
    preInstalled = YES;
    
bail:
    
    return preInstalled;
}

//save to disk
-(BOOL)save
{
    //flag
    BOOL saved = NO;
    
    //path
    NSString* path = nil;
    
    //init path
    path = [INSTALL_DIRECTORY stringByAppendingPathComponent:[NSString stringWithFormat:@"%@.plist", INSTALLED_APPS]];
    
    //save results to disk
    if(YES != [self.preInstalledApps writeToFile:path atomically:YES])
    {
        //err msg
        logMsg(LOG_ERR, [NSString stringWithFormat:@"failed to save installed (pre)installed (3rd-party) apps to %@", path]);
        
        //bail
        goto bail;
    }
    
    //dbg msg
    logMsg(LOG_DEBUG, [NSString stringWithFormat:@"saved list of installed (pre)installed 3rd-party apps to %@", path]);
    
    //happy
    saved = YES;
    
bail:
    
    return saved;
}

@end
