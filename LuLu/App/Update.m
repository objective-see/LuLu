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
#import "utilities.h"
#import "AppDelegate.h"

/* GLOBALS */

//log handle
extern os_log_t logHandle;

@implementation Update

//check for an update
// will invoke app delegate method to update UI when check completes
-(void)checkForUpdate:(void (^)(NSUInteger result, NSString* latestVersion))completionHandler
{
    //get latest version in background
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        
        //result
        NSInteger result = Update_None;

        //product info
        NSDictionary* productInfo = nil;
        
        //latest version
        NSString* latestVersion = nil;
        
        //major/minor
        NSNumber* osMajor = nil;
        NSNumber* osMinor = nil;
        
        //get product info
        productInfo = [self getProductInfo:PRODUCT_NAME];
        if(nil != productInfo)
        {
            //first check if there is a new version
            latestVersion = productInfo[LATEST_VERSION];
            if(YES == [latestVersion isKindOfClass:[NSString class]])
            {
                //trim
                latestVersion = [latestVersion stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
                
                //check current version with latest
                if(NSOrderedAscending == [getAppVersion() compare:latestVersion options:NSNumericSearch])
                {
                    //update available
                    result = Update_Available;
                }
            }
            
            //then check if new version is compatible w/ user version of macOS
            if(result == Update_Available)
            {
                osMajor = productInfo[SUPPORTED_OS_MAJOR];
                osMinor = productInfo[SUPPORTED_OS_MINOR];
                
                if( (YES == [osMajor isKindOfClass:[NSNumber class]]) &&
                    (YES == [osMinor isKindOfClass:[NSNumber class]]) )
                {
                    //init
                    NSOperatingSystemVersion supportedOS = {
                        .majorVersion = osMajor.intValue,
                        .minorVersion = osMinor.intValue,
                        .patchVersion = 0
                    };
                    
                    //user's version of macOS supported?
                    if(YES != [NSProcessInfo.processInfo isOperatingSystemAtLeastVersion:supportedOS])
                    {
                        //dbg mdg
                        os_log_debug(logHandle, "Latest version requires macOS %ld.%ld, but current macOS is %{public}@", supportedOS.majorVersion, supportedOS.minorVersion, NSProcessInfo.processInfo.operatingSystemVersionString);
                        
                        //not supported
                        result = Update_NotSupported;
                    }
                }
            }
        }
        //error
        else
        {
            //err msg
            os_log_error(logHandle, "ERROR: Failed to retrieve product info (for update check) from %{public}@", PRODUCT_VERSIONS_URL);
            
            result = Update_Error;
        }
         
        //invoke app delegate method
        // will update UI/show popup if necessary
        dispatch_async(dispatch_get_main_queue(),
        ^{
            completionHandler(result, latestVersion);
        });
    });
    
    return;
}

//read JSON file w/ products
// return dictionary w/ info about this product
-(NSDictionary*)getProductInfo:(NSString*)product
{
    //product version(s) data
    NSData* json = nil;
    NSError* error = nil;
    NSDictionary* products = nil;
    NSDictionary* productInfo = nil;

    //get json file (products) from remote URL
    @try
    {
        //get JSON
        json = [[NSData alloc] initWithContentsOfURL:[NSURL URLWithString:PRODUCT_VERSIONS_URL]];
        if(nil == json)
        {
            //err msg
            os_log_error(logHandle, "ERROR: failed to download product info from %{public}@", PRODUCT_VERSIONS_URL);
            goto bail;
        }
        
        //convert
        products = [NSJSONSerialization JSONObjectWithData:json options:0 error:&error];
        if(nil != error)
        {
            //err msg
            os_log_error(logHandle, "ERROR: Failed to convert 'products' to JSON (error: %{public}@)", error);
            goto bail;
        }
        
        //extract product info
        if( (YES == [products isKindOfClass:[NSDictionary class]]) &&
            (YES == [products[product] isKindOfClass:[NSDictionary class]]) )
        {
            productInfo = products[product];
        }
    }
    @catch(NSException* exception)
    {
        //err msg
        os_log_error(logHandle, "ERROR: Failed to convert 'products' to JSON (exception: %{public}@)", exception);
    }

bail:
    
    return productInfo;
}

@end
