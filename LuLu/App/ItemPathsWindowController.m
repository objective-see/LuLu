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
#import "ItemPathsWindowController.h"

/* GLOBALS */

//log handle
extern os_log_t logHandle;


@implementation ItemPathsWindowController

@synthesize rule;

-(void)windowDidLoad {
    
    //super
    [super windowDidLoad];
    
    //items
    NSArray* items = nil;
    
    //item bundle id
    NSString* bundleID = nil;
    
    //signing info
    NSMutableDictionary* signingInfo = nil;
    
    //dbg msg
    os_log_debug(logHandle, "method '%s' invoked", __PRETTY_FUNCTION__);
    
    //grab bundle id
    bundleID = self.rule.csInfo[KEY_CS_ID];
    
    //budle id?
    if(nil != bundleID)
    {
        //dbg msg
        os_log_debug(logHandle, "looking up apps that match %{public}@", bundleID);
        
        //get matching apps
        items = (__bridge NSArray *)(LSCopyApplicationURLsForBundleIdentifier((__bridge CFStringRef _Nonnull)(bundleID), nil));
        if(0 == items.count)
        {
            //none found
            // default to rule's path
            self.itemPaths.stringValue = [NSString stringWithFormat:@"▪ %@", self.rule.path];
            
            //bail
            goto bail;
        }
        
        //dbg msg
        os_log_debug(logHandle, "matching apps: %{public}@", items);
        
        //add each to UI
        // note: check for cs match
        for(NSURL* item in items)
        {
            //path
            NSString* path = nil;
            
            //when it's an app
            // get path to app's binary
            if(YES == [item.path hasSuffix:@".app"])
            {
                //get path
                path = getAppBinary(item.path);
                if(nil == path) path = item.path;
            }
            
            //extract signing info
            signingInfo = extractSigningInfo(0, path, kSecCSDefaultFlags);
            
            //ingore if cs info doesn't match
            // can be multiple apps on the system w/ same bundle id
            if(YES != [self.rule.csInfo isEqualToDictionary:signingInfo])
            {
                //skip
                continue;
            }
            
            //1st one?
            // just add
            if(0 == self.itemPaths.stringValue.length)
            {
                self.itemPaths.stringValue = [NSString stringWithFormat:@"▪ %@", item.path];
            }
            //otherwise
            // append to existing
            else
            {
                self.itemPaths.stringValue = [NSString stringWithFormat:@"%@\r\n▪ %@", self.itemPaths.stringValue, item.path];
            }
        }
    }
    //no bundle id
    // just use path as is
    else
    {
        //add path
        self.itemPaths.stringValue = [NSString stringWithFormat:@"▪ %@", self.rule.path];
    }
    
bail:
    
    return;
}

//close
- (IBAction)closeButtonHandler:(id)sender {
    
    //dbg msg
    os_log_debug(logHandle, "user clicked: %{public}@", ((NSButton*)sender).title);
    
    //close & return NSModalResponseCancel
    [self.window.sheetParent endSheet:self.window returnCode:NSModalResponseOK];
    
    return;
}

@end
