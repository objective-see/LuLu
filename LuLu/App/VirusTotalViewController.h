//
//  file: VirusTotalViewController.h
//  project: lulu (login item)
//  description: view controller for VirusTotal results popup (header)
//
//  created by Patrick Wardle
//  copyright (c) 2017 Objective-See. All rights reserved.
//

@import Cocoa;
@import OSLog;

@interface VirusTotalViewController : NSViewController <NSPopoverDelegate>
{
    
}

/* METHODS */


/* PROPERTIES */

//item name
@property(nonatomic, retain)NSString* itemName;

//item path
@property(nonatomic, retain)NSString* itemPath;

//progress indicator
@property(weak)IBOutlet NSProgressIndicator *vtSpinner;

//query msg
@property (unsafe_unretained) IBOutlet NSTextView *message;


@end

