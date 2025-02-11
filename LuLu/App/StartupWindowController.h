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

//version warning msg
@property (weak) IBOutlet NSTextField *versionWarning;

//activity indicator
@property (weak) IBOutlet NSProgressIndicator *spinner;

@end
