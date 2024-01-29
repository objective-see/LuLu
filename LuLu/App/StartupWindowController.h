//
//  file: StartupWindowController.h
//
//  created by Patrick Wardle
//  copyright (c) 2024 Objective-See. All rights reserved.
//

@import Cocoa;
@import OSLog;

@interface StartupWindowController : NSWindowController <NSWindowDelegate>
{
    
}

@property (weak) IBOutlet NSProgressIndicator *spinner;

@end
