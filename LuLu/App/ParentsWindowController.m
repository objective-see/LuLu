//
//  file: ParentsWindowController.m
//  project: lulu (login item)
//  description: window controller for process heirachy
//
//  created by Patrick Wardle
//  copyright (c) 2017 Objective-See. All rights reserved.
//

#import "consts.h"
#import "ParentsWindowController.h"

@implementation ParentsWindowController

//automatically invoked
// return number of children, simply either 1, or 0 (for last item)
-(NSInteger)outlineView:(NSOutlineView *)outlineView numberOfChildrenOfItem:(id)item
{
    //# of kids
    // defaults to 1
    NSInteger kidCount = 1;
    
    //for last item
    // no more kids...
    if( (1 != self.processHierarchy.count) &&
        ([((NSDictionary*)item)[KEY_INDEX] integerValue] == self.processHierarchy.count-1) )
    {
        //no kids
        kidCount = 0;
    }
    
    return kidCount;
}

//automatically invoked to determine if item is expandable
// always the case, except for the last item
-(BOOL)outlineView:(NSOutlineView *)outlineView isItemExpandable:(id)item
{
    //flag
    // ->defaults to yes
    BOOL isExpandable = YES;
    
    //for last item
    // no kids, so obv. no expandable
    if([((NSDictionary*)item)[KEY_INDEX] integerValue] == self.processHierarchy.count-1)
    {
        //last one
        isExpandable = NO;
    }
    
    return isExpandable;
}

//automatically invoked to get the child item
-(id)outlineView:(NSOutlineView *)outlineView child:(NSInteger)index ofItem:(id)item
{
    //item
    id itemForRow = nil;
    
    //item is nil for root
    // just provide root item
    if(nil == item)
    {
        //first item
        itemForRow = self.processHierarchy[0];
    }
    
    //other items
    // return *their* child!
    else
    {
        //child at index
        itemForRow = self.processHierarchy[[((NSDictionary*)item)[KEY_INDEX] integerValue]+1];
    }
    
    return itemForRow;
}

//automatically invoked to get the object for the row
// return items name/pid
-(id)outlineView:(NSOutlineView *)outlineView objectValueForTableColumn:(NSTableColumn *)tableColumn byItem:(id)item
{
    //row value
    NSString* rowValue = nil;
    
    //init string for row
    // process name + pid
    //  note: if this format changes, also change row width calculation in AlertWindowController!
    rowValue = [NSString stringWithFormat:NSLocalizedString(@"%@ (pid: %@)",@"%@ (pid: %@)"), ((NSDictionary*)item)[KEY_PROCESS_NAME], ((NSDictionary*)item)[@"pid"]];
    
    return rowValue;
}

@end
