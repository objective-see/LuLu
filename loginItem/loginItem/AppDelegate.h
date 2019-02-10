//
//  file: AppDelegate.h
//  project: lulu (login item)
//  description: app delegate for login item (header)
//
//  created by Patrick Wardle
//  copyright (c) 2017 Objective-See. All rights reserved.
//

@import Cocoa;

#import "StatusBarItem.h"
#import "XPCDaemonClient.h"
#import "UpdateWindowController.h"

@interface AppDelegate : NSObject <NSApplicationDelegate>


/* PROPERTIES */

//status bar menu
@property(strong) IBOutlet NSMenu* statusMenu;

//status bar menu controller
@property(nonatomic, retain)StatusBarItem* statusBarItemController;

//update window controller
@property(nonatomic, retain)UpdateWindowController* updateWindowController;

//xpc for daemon comms
@property(nonatomic, retain)XPCDaemonClient* xpcDaemonClient;

//(main) app observer
@property(nonatomic, retain)NSObject* appObserver;

//alert windows
@property(nonatomic, retain)NSMutableDictionary* alerts;

//notifcation changed observer
@property(nonatomic, retain)id prefsChanged;

/* METHODS */


@end

