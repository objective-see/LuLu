//
//  BlockList.m
//  Extension
//
//  Created by Patrick Wardle on 11/6/20.
//  Copyright © 2020 Objective-See. All rights reserved.
//

#import "consts.h"
#import "BlockList.h"
#import "Preferences.h"

/* GLOBALS */

//log handle
extern os_log_t logHandle;

//preferences
extern Preferences* preferences;

@implementation BlockList

-(id)init
{
    //init super
    self = [super init];
    if(nil != self)
    {
        //load block list
        // ok if fails ...no block list yet?
        [self load];
    }

    return self;
}

//(re)load from disk
-(void)load
{
    //path
    NSString* path = nil;
    
    //error
    NSError* error = nil;
    
    //extact path
    path = preferences.preferences[PREF_BLOCK_LIST];
    
    //check
    // is there a specified block list?
    if(0 == path.length)
    {
        //dbg msg
        os_log_debug(logHandle, "no block list specified...");
        
        //bail
        goto bail;
    }
    
    //check file exists?
    if(YES != [NSFileManager.defaultManager fileExistsAtPath:path])
    {
        //dbg msg
        os_log_error(logHandle, "ERROR: specified block list path, %{public}@ doesn't exist", path);
        
        //bail
        goto bail;
    }
    
    //dbg msg
    os_log_debug(logHandle, "loading block list, %{public}@", preferences.preferences[PREF_BLOCK_LIST]);
        
    //load
    self.blockList = [[NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:&error] componentsSeparatedByString:@"\n"];
    if(nil != error)
    {
        //err msg
        os_log_error(logHandle, "ERROR: failed to load block list, %{public}@ (error: %@)", path, error);
        
        //bail
        goto bail;
    }
        
    //dbg msg
    os_log_debug(logHandle, "loaded %lu block list items", (unsigned long)self.blockList.count);
    
bail:
    
    return;
}

//check if flow matches item on block list
-(BOOL)isMatch:(NEFilterSocketFlow*)flow
{
    //match
    BOOL isMatch = NO;
    
    //remote endpoint
    NWHostEndpoint* remoteEndpoint = nil;
    
    //extract remote endpoint
    remoteEndpoint = (NWHostEndpoint*)flow.remoteEndpoint;
    
    //check each item
    // do prefix check to make more robust
    for(NSString* item in self.blockList)
    {
        //sanity check
        if(0 == item.length) continue;
        
        //check host name and url
        if( (YES == [remoteEndpoint.hostname hasPrefix:item]) ||
            (YES == [flow.URL.absoluteString hasPrefix:item]) )
        {
            //dbg msg
            os_log_debug(logHandle, "block listed item %{public}@, matches flow hostname: %{public}@ / url: %{public}@", item, remoteEndpoint.hostname, flow.URL.absoluteString);
            
            //happy
            isMatch = YES;
            
            //done
            goto bail;
        }
    }
    
bail:
    
    return isMatch;
}



@end
