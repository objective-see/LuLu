//
//  file: AppDelegate.h
//  project: lulu (login item)
//  description: app delegate for login item (header)
//
//  created by Patrick Wardle
//  copyright (c) 2017 Objective-See. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import "StatusBarMenu.h"
#import "UpdateWindowController.h"

@interface AppDelegate : NSObject <NSApplicationDelegate>

/* PROPERTIES */

//status bar menu
@property (weak) IBOutlet NSMenu *statusMenu;

//status bar menu
@property(nonatomic, retain)StatusBarMenu* statusBarMenuController;

//update window controller
@property(nonatomic, retain)UpdateWindowController* updateWindowController;

@end

