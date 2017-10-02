//
//  file: StatusBarMenu.h
//  project: lulu (login item)
//  description: menu handler for status bar icon (header)
//
//  created by Patrick Wardle
//  copyright (c) 2017 Objective-See. All rights reserved.
//

#import "DaemonComms.h"
#import <Cocoa/Cocoa.h>

@interface StatusBarMenu : NSObject
{

}

//status item
@property (nonatomic, strong, readwrite) NSStatusItem *statusItem;

//daemom comms object
@property (nonatomic, retain)DaemonComms* daemonComms;

//enabled flag
@property BOOL isEnabled;

/* METHODS */

//init
-(id)init:(NSMenu*)menu;

@end
