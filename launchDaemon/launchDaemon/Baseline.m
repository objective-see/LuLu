//
//  Baseline.m
//  launchDaemon
//
//  Created by Patrick Wardle on 2/21/18.
//  Copyright © 2018 Objective-See. All rights reserved.
//

#import "consts.h"
#import "logging.h"
#import "procInfo.h"
#import "Baseline.h"
#import "utilities.h"

@implementation Baseline

//@synthesize appQuery;
//@synthesize operationQueue;

/*
//init method
-(id)init
{
    //init super
    self = [super init];
    if(nil != self)
    {
        //alloc queue
        operationQueue = [[NSOperationQueue alloc] init];
        
        //set concurrency count
        self.operationQueue.maxConcurrentOperationCount = 8;
        
        //set QoS to background
        self.operationQueue.qualityOfService = NSQualityOfServiceUtility;
        
        //init list
        self.installedApps = [NSMutableArray array];
    }

    return self;
}
*/


//invoke 'system profiler' to get installed apps
// then process each, saving info about 3rd-party ones
-(void)baseline
{
    //3rd-party apps
    NSMutableDictionary* thirdPartyApps = nil;
    
    //all installed apps
    NSArray* installedApps = nil;

    //path
    NSString* path = nil;
    
    //name
    NSString* name = nil;
    
    //signing info
    NSArray* signedBy = nil;
    
    //hash
    NSString* hash = nil;
    
    //alloc dictionary
    thirdPartyApps = [NSMutableDictionary dictionary];
    
    //enumerate all install apps
    installedApps = enumerateInstalledApplications();
    
    //dbg msg
    logMsg(LOG_DEBUG, [NSString stringWithFormat:@"found %ld installed apps", installedApps.count]);

    //process installed apps
    // save any 3rd-party ones into array
    for(NSDictionary* installedApp in installedApps)
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
        
        //skip apple signed apps
        if( (YES == [signedBy.lastObject isEqualToString:@"Apple Root CA"]) &&
            (YES == [signedBy.firstObject isEqualToString:@"Software Signing"]) )
        {
            //skip
            continue;
        }
        
        //skip lulu
        // it's already baselined via rules.plist file
        if(YES == [path containsString:@"LuLu"])
        {
            //skip
            continue;
        }
        
        //extract name
        name = installedApp[@"_name"];
        
        //add w/ blank dictionary
        thirdPartyApps[path] = [NSMutableDictionary dictionary];
        
        //add name
        if(nil != name)
        {
            //add
            thirdPartyApps[path][KEY_NAME] = name;
        }
        
        //signed?
        // add signing info
        if(nil != signedBy)
        {
            //add
            thirdPartyApps[path][KEY_SIGNING_INFO] = signedBy;
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
                thirdPartyApps[path][KEY_HASH] = hash;
            }
        }
    }
    
    //dbg msg
    logMsg(LOG_DEBUG, [NSString stringWithFormat:@"found %ld installed 3rd-party apps", thirdPartyApps.count]);
    
    //save results to disk
    if(YES != [thirdPartyApps writeToFile:[INSTALL_DIRECTORY stringByAppendingPathComponent:INSTALLED_APPS] atomically:YES])
    {
        //err msg
        logMsg(LOG_ERR, [NSString stringWithFormat:@"failed to save installed 3rd-party apps to %@", INSTALLED_APPS]);
        
        //bail
        goto bail;
    }
    
    //dbg msg
    logMsg(LOG_DEBUG, [NSString stringWithFormat:@"saved list of installed 3rd-party apps to %@", INSTALLED_APPS]);

bail:
    
    return;
}
@end
