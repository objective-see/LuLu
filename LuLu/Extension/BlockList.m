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
        //load
        [self load:preferences.preferences[PREF_BLOCK_LIST]];
    }

    return self;
}

//should reload
// checks file modification time
-(BOOL)shouldReload:(NSString*)path
{
    //flag
    BOOL shouldReload = NO;
    
    //current mod. time
    NSDate* modified = nil;
    
    //get modified timestamp
    modified = [[NSFileManager.defaultManager attributesOfItemAtPath:path error:nil] objectForKey:NSFileModificationDate];

    //was file modified?
    if(NSOrderedDescending == [modified compare:self.lastModified])
    {
        //dbg msg
        os_log_debug(logHandle, "block list was modified ...will reload");
        
        //yes
        shouldReload = YES;
    }
    
    return shouldReload;
}

//load
// and listen
-(void)load:(NSString*)path
{
    //error
    NSError* error = nil;
    
    //check
    // path?
    if(0 == path.length)
    {
        //dbg msg
        os_log_debug(logHandle, "no block list specified...");
        
        //bail
        goto bail;
    }
    
    //check
    // file exists?
    if(YES != [NSFileManager.defaultManager fileExistsAtPath:path])
    {
        //dbg msg
        os_log_error(logHandle, "ERROR: specified block list path, %{public}@ doesn't exist", path);
        
        //bail
        goto bail;
    }
    
    //dbg msg
    os_log_debug(logHandle, "(re)loading block list, %{public}@", path);
        
    //load
    self.items = [[[NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:&error] componentsSeparatedByString:@"\n"] mutableCopy];
    if(nil != error)
    {
        //err msg
        os_log_error(logHandle, "ERROR: failed to load block list, %{public}@ (error: %@)", path, error);
        
        //bail
        goto bail;
    }
    
    //remove any rows that start w/ comments ('#')
    for(NSInteger i = self.items.count-1; i >= 0; i--)
    {
        //comment row?
        // remove from list
        if(YES == [self.items[i] hasPrefix:@"#"])
        {
            //remove
            [self.items removeObjectAtIndex:i];
        }
    }
    
    //dbg msg
    os_log_debug(logHandle, "loaded %lu block list items", (unsigned long)self.items.count);
    
    //save timestamp
    self.lastModified = [[NSFileManager.defaultManager attributesOfItemAtPath:path error:nil] objectForKey:NSFileModificationDate];

bail:
    
    return;
}

//check if flow matches item on block list
-(BOOL)isMatch:(NEFilterSocketFlow*)flow
{
    //match
    BOOL isMatch = NO;
    
    //path
    NSString* path = nil;
    
    //remote endpoint
    NWHostEndpoint* remoteEndpoint = nil;
    
    //extact path
    path = preferences.preferences[PREF_BLOCK_LIST];
    
    //extract remote endpoint
    remoteEndpoint = (NWHostEndpoint*)flow.remoteEndpoint;
    
    //need to reload list?
    // checks timestamp to see if modified
    if(YES == [self shouldReload:path])
    {
        //reload list
        [self load:path];
    }
    
    //check each item
    for(NSString* item in self.items)
    {
        //sanity check
        if(0 == item.length) continue;
        
        //check url host and flow's host name (IP)
        if( (YES == [item isEqualToString:flow.URL.host]) ||
            (YES == [item isEqualToString:remoteEndpoint.hostname]) )
        {
            //dbg msg
            os_log_debug(logHandle, "block listed item %{public}@, matches flow url host: %{public}@ or ip addr: %{public}@", item, flow.URL.host, remoteEndpoint.hostname);
            
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
