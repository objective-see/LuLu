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

@interface StatusBarMenu : NSObject <NSPopoverDelegate>
{

}

//status item
@property (nonatomic, strong, readwrite) NSStatusItem *statusItem;

//popover
@property (retain, nonatomic)NSPopover *popover;

//disabled flag
@property BOOL isDisabled;

/* METHODS */

//init
-(id)init:(NSMenu*)menu preferences:(NSDictionary*)preferences firstTime:(BOOL)firstTime;

@end
