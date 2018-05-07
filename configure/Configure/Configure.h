//
//  file: Configure.h
//  project: lulu (config)
//  description: install/uninstall logic (header)
//
//  created by Patrick Wardle
//  copyright (c) 2018 Objective-See. All rights reserved.
//

#ifndef LuLu_Configure_h
#define LuLu_Configure_h

#import "HelperComms.h"
#import <Foundation/Foundation.h>

@interface Configure : NSObject
{
    
}

/* PROPERTIES */

//helper installed & connected
@property(nonatomic) BOOL gotHelp;

//daemom comms object
@property(nonatomic, retain) HelperComms* xpcComms;

/* METHODS */

//determine if LuLu is installed
-(BOOL)isInstalled;

//invokes appropriate install || uninstall logic
-(BOOL)configure:(NSInteger)parameter;

//install
-(BOOL)install;

//uninstall
-(BOOL)uninstall:(BOOL)full;

//remove helper (daemon)
-(BOOL)removeHelper;

@end

#endif
