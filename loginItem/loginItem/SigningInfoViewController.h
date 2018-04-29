//
//  file: SigningInfoViewController
//  project: lulu (login item)
//  description: view controller for signing info popup (header)
//
//  created by Patrick Wardle
//  copyright (c) 2018 Objective-See. All rights reserved.
//

@import Cocoa;

/* DEFINES */

//signing auths view
#define SIGNING_AUTH_1 1

@interface SigningInfoViewController : NSViewController <NSPopoverDelegate>
{
    
}

/* METHODS */


/* PROPERTIES */

//alert info
@property(nonatomic, retain)NSDictionary* alert;

//signing icon
@property (weak) IBOutlet NSImageView *icon;

//main signing msg
@property (weak) IBOutlet NSTextField *message;

//details
@property (weak) IBOutlet NSTextField *details;


@end
