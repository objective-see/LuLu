//
//  file: StatusBarMenu.h
//  project: lulu (login item)
//  description: menu handler for status bar icon (header)
//
//  created by Patrick Wardle
//  copyright (c) 2017 Objective-See. All rights reserved.
//


@import Cocoa;
@import OSLog;

#import "RulesMenuController.h"

@interface StatusBarItem : NSObject <NSPopoverDelegate, NSMenuDelegate>
{

}

//status item
@property(nonatomic, strong, readwrite)NSStatusItem* statusItem;

//rules (sub)menu handler
@property(nonatomic, retain)RulesMenuController* rulesMenuController;

//popover
@property(retain, nonatomic)NSPopover* popover;

//disabled flag
@property BOOL isDisabled;

/* METHODS */

//remove status item
-(void)removeStatusItem;

//init
-(id)init:(NSMenu*)menu preferences:(NSDictionary*)preferences;

//set profile
-(void)setProfile:(NSArray*)profiles current:(NSString*)current;

@end
