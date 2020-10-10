//
//  ItemPathsWindowController.h
//  LuLu
//
//  Created by Patrick Wardle on 9/19/20.
//  Copyright (c) 2020 Objective-See. All rights reserved.
//

@import Cocoa;
@import OSLog;

#import "Rule.h"

NS_ASSUME_NONNULL_BEGIN

@interface ItemPathsWindowController : NSWindowController

//item
@property(nonatomic, retain)Rule* rule;

//item paths
@property (weak) IBOutlet NSTextField *itemPaths;

//close button
@property (weak) IBOutlet NSButton *closeButton;

@end

NS_ASSUME_NONNULL_END
