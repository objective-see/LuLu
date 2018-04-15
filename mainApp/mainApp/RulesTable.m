//
//  file: RuleTable.m
//  project: lulu (main app)
//  description: subclass for rules table
//
//  created by Patrick Wardle
//  copyright (c) 2018 Objective-See. All rights reserved.
//

#import "RulesTable.h"

@implementation RulesTable

//override
// user (right) clicks, select row
// this allows code to find correct rule obj,
-(NSMenu*)menuForEvent:(NSEvent *)event
{
    //selected row
    NSInteger selectedRow = -1;
    
    //covert mouse click to selected row
    selectedRow = [self rowAtPoint:[self convertPoint:[event locationInWindow] fromView:nil]];
    
    //make it selected
    [self selectRowIndexes:[NSIndexSet indexSetWithIndex:selectedRow] byExtendingSelection:NO];
    
    return nil;
}

@end
