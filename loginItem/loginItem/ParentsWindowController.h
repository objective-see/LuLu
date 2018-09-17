//
//  file: ParentsWindowController.h
//  project: lulu (login item)
//  description: window controller for process heirachy (header)
//
//  created by Patrick Wardle
//  copyright (c) 2017 Objective-See. All rights reserved.
//

@import Cocoa;

@interface ParentsWindowController : NSViewController <NSOutlineViewDataSource, NSOutlineViewDelegate>
{
    
}

/* PROPERTIES */

//process hierarchy
@property (nonatomic, retain)NSArray* processHierarchy;

/* METHODS */

@end
