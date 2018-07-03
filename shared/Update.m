//
//  file: Update.m
//  project: lulu (shared)
//  description: checks for new versions of LuLu
//
//  created by Patrick Wardle
//  copyright (c) 2017 Objective-See. All rights reserved.
//

#import "consts.h"
#import "Update.h"
#import "logging.h"
#import "utilities.h"
#import "AppDelegate.h"


@implementation Update

//check for an update
// ->will invoke app delegate method to update UI when check completes
-(void)checkForUpdate:(void (^)(NSUInteger result, NSString* latestVersion))completionHandler
{
    //latest version
    __block NSString* latestVersion = nil;
    
    //result
    __block NSInteger result = -1;

    //get latest version in background
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        
        //grab latest version
        latestVersion = [self getLatestVersion];
        if(nil != latestVersion)
        {
            //check
            result = (NSOrderedAscending == [getAppVersion() compare:latestVersion options:NSNumericSearch]);
        }
        
        //invoke app delegate method
        // ->will update UI/show popup if necessart
        dispatch_async(dispatch_get_main_queue(),
        ^{
            completionHandler(result, latestVersion);
        });
        
    });
    
    return;
}

//query interwebz to get latest version
-(NSString*)getLatestVersion
{
    //product version(s) data
    NSData* productsVersionData = nil;
    
    //version dictionary
    NSDictionary* productsVersionDictionary = nil;
    
    //latest version
    NSString* latestVersion = nil;
    
    //get version from remote URL
    productsVersionData = [[NSData alloc] initWithContentsOfURL:[NSURL URLWithString:PRODUCT_VERSIONS_URL]];
    if(nil == productsVersionData)
    {
        //bail
        goto bail;
    }
    
    //convert JSON to dictionary
    // ->wrap as may throw exception
    @try
    {
        //convert
        productsVersionDictionary = [NSJSONSerialization JSONObjectWithData:productsVersionData options:0 error:nil];
        if(nil == productsVersionDictionary)
        {
            //bail
            goto bail;
        }
    }
    @catch(NSException* exception)
    {
        //bail
        goto bail;
    }
    
    //extract latest version
    latestVersion = [[productsVersionDictionary objectForKey:@"LuLu"] objectForKey:@"version"];
    
    //dbg msg
    logMsg(LOG_DEBUG, [NSString stringWithFormat:@"latest version: %@", latestVersion]);
    
bail:
    
    return latestVersion;
}




@end
