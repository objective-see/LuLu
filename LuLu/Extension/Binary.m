//
//  File: Binary.m
//  Project: Lulu
//
//  Created by: Patrick Wardle
//  Copyright:  2017 Objective-See
//

#import "Binary.h"

@implementation Binary

@synthesize icon;
@synthesize name;
@synthesize path;
@synthesize bundle;
@synthesize metadata;
@synthesize attributes;

/* GLOBALS */

//log handle
extern os_log_t logHandle;

//init binary object
// note: CPU-intensive logic (code signing, etc) called manually
-(id)init:(NSString*)binaryPath
{
    //init super
    self = [super init];
    if(nil != self)
    {
        //save path
        self.path = binaryPath;
        
        //remove symlinks
        self.path = [self.path stringByResolvingSymlinksInPath];
        
        //try load app bundle
        // will be nil for non-apps
        [self getBundle];
        
        //get name
        [self getName];
        
        //get file attributes
        [self getAttributes];
        
        //get meta data (spotlight)
        [self getMetadata];
    }

    return self;
}

//try load app bundle
// will be nil for non-apps
-(void)getBundle
{
    //first try just with path
    self.bundle = [NSBundle bundleWithPath:path];
    
    //that failed?
    // try find it dynamically
    if(nil == self.bundle)
    {
        //find bundle
        self.bundle = findAppBundle(path);
    }
    
    return;
}

//figure out binary's name
// either via app bundle, or from path
-(void)getName
{
    //first try get name from app bundle
    // specifically, via grab name from 'CFBundleName'
    if(nil != self.bundle)
    {
        //extract name
        self.name = [self.bundle infoDictionary][@"CFBundleName"];
    }
    
    //no app bundle || no 'CFBundleName'
    // just use last component from path
    if(nil == self.name)
    {
        //set name
        self.name = [self.path lastPathComponent];
    }
    
    return;
}

//get file attributes
-(void)getAttributes
{
    //grab (file) attributes
    self.attributes = [[NSFileManager defaultManager] attributesOfItemAtPath:self.path error:nil];
    
    return;
}

//get (spotlight) meta data
-(void)getMetadata
{
    //md item ref
    MDItemRef mdItem = nil;
    
    //attributes names
    CFArrayRef attributeNames = nil;

    //create
    mdItem = MDItemCreate(kCFAllocatorDefault, (CFStringRef)self.path);
    if(nil == mdItem)
    {
        //bail
        goto bail;
    }
    
    //copy names
    attributeNames = MDItemCopyAttributeNames(mdItem);
    if(nil == attributeNames)
    {
        //bail
        goto bail;
    }
    
    //get metadata
    self.metadata = CFBridgingRelease(MDItemCopyAttributes(mdItem, attributeNames));
    
bail:
    
    //release names
    if(NULL != attributeNames)
    {
        //release
        CFRelease(attributeNames);
        attributeNames = NULL;
    }
    
    //release md item
    if(NULL != mdItem)
    {
        //release
        CFRelease(mdItem);
        mdItem = NULL;
    }

    return;
}

//get an icon for a process
// for apps, this will be app's icon, otherwise just a standard system one
-(void)getIcon
{
    //icon's file name
    NSString* iconFile = nil;
    
    //icon's path
    NSString* iconPath = nil;
    
    //icon's path extension
    NSString* iconExtension = nil;
    
    //skip 'short' paths
    // otherwise system logs an error
    if( (YES != [self.path hasPrefix:@"/"]) &&
        (nil == self.bundle) )
    {
        //bail
        goto bail;
    }
    
    //for app's
    // extract their icon
    if(nil != self.bundle)
    {
        //get file
        iconFile = self.bundle.infoDictionary[@"CFBundleIconFile"];
        
        //get path extension
        iconExtension = [iconFile pathExtension];
        
        //if its blank (i.e. not specified)
        // go with 'icns'
        if(YES == [iconExtension isEqualTo:@""])
        {
            //set type
            iconExtension = @"icns";
        }
        
        //set full path
        iconPath = [self.bundle pathForResource:[iconFile stringByDeletingPathExtension] ofType:iconExtension];
        
        //load it
        self.icon = [[NSImage alloc] initWithContentsOfFile:iconPath];
    }
    
    //process is not an app or couldn't get icon
    // try to get it via shared workspace
    if( (nil == self.bundle) ||
        (nil == self.icon) )
    {
        //extract icon
        self.icon = [[NSWorkspace sharedWorkspace] iconForFile:self.path];
    }
    
    //make standard size...
    [self.icon setSize:NSMakeSize(128, 128)];
    
bail:
    
    return;
}

//statically, generate signing info
-(void)generateSigningInfo:(SecCSFlags)flags
{
    //signing info
    NSMutableDictionary* extractedSigningInfo = nil;
    
    //extract signing info
    extractedSigningInfo = extractSigningInfo(0, self.path, flags);
    
    //valid?
    // save into iVar
    if( (nil != extractedSigningInfo[KEY_CS_STATUS]) &&
        (noErr == [extractedSigningInfo[KEY_CS_STATUS] intValue]))
    {
        //save
        self.csInfo = extractedSigningInfo;
    }
    //dbg msg
    else os_log_debug(logHandle, "invalid code signing information for %{public}@: %{public}@", self.path, extractedSigningInfo);
    
    return;
}

//for pretty printing
-(NSString *)description
{
    //pretty print
    return [NSString stringWithFormat: @"name: %@\npath: %@\nattributes: %@\nsigning info: %@\nmetadata: %@", self.name, self.path, self.attributes, self.metadata, self.csInfo];
}

@end
