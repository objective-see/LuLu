//
//  ItemPathsWindowController.m
//  LuLu
//
//  Created by Patrick Wardle on 9/19/20.
//  Copyright (c) 2020 Objective-See. All rights reserved.
//

#import "consts.h"
#import "signing.h"
#import "utilities.h"
#import "XPCDaemonClient.h"
#import "ItemPathsWindowController.h"

/* GLOBALS */

//log handle
extern os_log_t logHandle;

//xpc for daemon comms
extern XPCDaemonClient* xpcDaemonClient;

@implementation ItemPathsWindowController

@synthesize item;

//generate and show paths
-(void)windowDidLoad {
    
    //rule
    Rule* rule = nil;
    
    //super
    [super windowDidLoad];
    
    //unique paths
    NSMutableSet* paths = nil;
    
    //dbg msg
    os_log_debug(logHandle, "method '%s' invoked", __PRETTY_FUNCTION__);
    
    //extract (first) rule
    rule = [self.item[KEY_RULES] firstObject];
    
    //set heading if 'normal' rule
    if(!rule.isGlobal.boolValue &&
       !rule.isDirectory.boolValue) {
        
        //set heading
        self.heading.stringValue = [NSString stringWithFormat:NSLocalizedString(@"Path(s) for %@:", nil), rule.name];
    }
    //reset heading
    else {
        self.heading.stringValue = NSLocalizedString(@"Path(s):", nil);
    }
    
    //get paths
    paths = [self getPaths];
    
    //each rule's path
    for(NSString* path in paths)
    {
        if(0 == self.itemPaths.stringValue.length)
        {
            self.itemPaths.stringValue = [NSString stringWithFormat:@"▪ %@", path];
        }
        //otherwise
        // append to existing
        else
        {
            self.itemPaths.stringValue = [NSString stringWithFormat:@"%@\r\n▪ %@", self.itemPaths.stringValue, path];
        }
    }

    //make close button first responder
    [self.window makeFirstResponder:self.closeButton];

    return;
}

//get all unique paths for item
// both from rules, but also from system (via bundle ID)
-(NSMutableSet*)getPaths
{
    //(first) rule
    Rule* rule = nil;
    
    //items
    NSArray* items = nil;
    
    //paths
    NSMutableSet* paths = nil;
    
    //item bundle id
    NSString* bundleID = nil;
        
    //signing info
    NSMutableDictionary* signingInfo = nil;
    
    //init
    paths = [NSMutableSet set];
    
    //extract (first) rule
    rule = [self.item[KEY_RULES] firstObject];
    
    //global rule?
    if(YES == rule.isGlobal.boolValue)
    {
        //set message
        [paths addObject:NSLocalizedString(@"Global Rules apply to all paths", @"Global Rules apply to all paths")];
        
        //done
        goto bail;
    }
    
    //directory rule?
    if(YES == rule.isDirectory.boolValue)
    {
        //set message
        [paths addObject:NSLocalizedString(@"Directory Rules apply to all items within the directory", @"Directory Rules apply to all items within the directory")];
        
        //done
        goto bail;
    }
    
    //first add rule's path
    if(nil != rule.path)
    {
        //add
        [paths addObject:rule.path];
    }

    //add any external paths
    [paths unionSet:item[KEY_PATHS]];
    
    //grab bundle id
    bundleID = rule.csInfo[KEY_CS_ID];
    
    //add other items on system
    // with same bundle id *and* cs info, as these will match
    if(nil != bundleID)
    {
        //get matching apps
        items = (__bridge NSArray *)(LSCopyApplicationURLsForBundleIdentifier((__bridge CFStringRef _Nonnull)(bundleID), nil));
        
        //get each item's binary
        for(NSURL* item in items)
        {
            //path
            NSString* path = nil;
            
            //attempt to get path via bundle
            path = getBundleExecutable(item.path);
            
            //likely not bundle
            if(0 == path.length)
            {
                path = item.path;
            }
            
            //sanity check
            if(0 == path.length)
            {
                //skip
                continue;
            }
            
            //extract signing info and check
            // note: use item's path, to match rule
            signingInfo = extractSigningInfo(0, item.path, kSecCSDefaultFlags);
            if(YES != matchesCSInfo(self.item[KEY_CS_INFO], signingInfo))
            {
                //dbg msg
                os_log_debug(logHandle, "rule's code signing info %{public}@ doesn't match item's %{public}@", self.item[KEY_CS_INFO], signingInfo);
                
                //skip
                continue;
            }
            
            //add
            [paths addObject:path];
        }
    }
    
bail:
    
    return paths;
    
}

//close
-(IBAction)closeButtonHandler:(id)sender {
    
    //dbg msg
    os_log_debug(logHandle, "user clicked: %{public}@", ((NSButton*)sender).title);
    
    //close & return NSModalResponseCancel
    [self.window.sheetParent endSheet:self.window returnCode:NSModalResponseOK];
    
    return;
}

@end
