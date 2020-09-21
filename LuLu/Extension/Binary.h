//
//  Binary.h
//  LuLu
//
//  Created by Patrick Wardle on 8/27/20.
//  Copyright (c) 2020 Objective-See. All rights reserved.
//

#ifndef Binary_h
#define Binary_h

#import "Consts.h"
#import "Signing.h"
#import "utilities.h"

@import CommonCrypto;

@interface Binary : NSObject
{
    
}

/* PROPERTIES */

//path
@property(nonatomic, retain)NSString* _Nonnull path;

//name
@property(nonatomic, retain)NSString* _Nonnull name;

//icon
@property(nonatomic, retain)NSImage* _Nonnull icon;

//file attributes
@property(nonatomic, retain)NSDictionary* _Nullable attributes;

//spotlight meta data
@property(nonatomic, retain)NSDictionary* _Nullable metadata;

//bundle
// nil for non-apps
@property(nonatomic, retain)NSBundle* _Nullable bundle;

//signing info
@property(nonatomic, retain)NSMutableDictionary* _Nonnull csInfo;

//hash
@property(nonatomic, retain)NSMutableString* _Nonnull sha256;

/* METHODS */

//init w/ a path
-(id _Nonnull)init:(NSString* _Nonnull)path;

/* the following methods are rather CPU-intensive
   as such, if the proc monitoring is run with the 'goEasy' option, they aren't automatically invoked
*/
 
//get an icon for a process
// for apps, this will be app's icon, otherwise just a standard system one
-(void)getIcon;

//generate signing info (statically)
-(void)generateSigningInfo:(SecCSFlags)flags;

@end

#endif /* Binary_h */
