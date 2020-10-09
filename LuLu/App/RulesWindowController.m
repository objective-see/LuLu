//
//  file: RulesWindowController.m
//  project: lulu (main app)
//  description: window controller for 'rules' table
//
//  created by Patrick Wardle
//  copyright (c) 2017 Objective-See. All rights reserved.
//

#import "consts.h"
#import "RuleRow.h"
#import "utilities.h"
#import "AppDelegate.h"
#import "XPCDaemonClient.h"
#import "RulesWindowController.h"
#import "AddRuleWindowController.h"
#import "3rd-party/OrderedDictionary.h"

/* GLOBALS */

//log handle
extern os_log_t logHandle;

@implementation RulesWindowController

@synthesize rules;
@synthesize toolbar;
@synthesize addedRule;
@synthesize filterBox;
@synthesize addRulePanel;
@synthesize loadingRules;
@synthesize rulesFiltered;
@synthesize rulesObserver;
@synthesize loadingRulesSpinner;

//init some settings
-(void)awakeFromNib
{
    //set target
    self.outlineView.target = self;
    
    //set 2x click handler
    self.outlineView.doubleAction = @selector(doubleClickHandler:);
    
    return;
}

//configure (UI)
-(void)configure
{
    //dbg msg
    os_log_debug(logHandle, "method '%s' invoked", __PRETTY_FUNCTION__);
    
    //load rules
    [self loadRules];

    return;
}

//alloc/init
// get rules and listen for new ones
-(void)windowDidLoad
{
    //filtering?
    // only generate events end events
    self.filterBox.sendsWholeSearchString = YES;
    
    //set indentation level for outline view
    self.outlineView.indentationPerLevel = 42;
    
    //pre-req for color of overlay
    self.loadingRules.wantsLayer = YES;
    
    //round overlay's corners
    self.loadingRules.layer.cornerRadius = 20.0;
    
    //mask overlay
    self.loadingRules.layer.masksToBounds = YES;
    
    //set overlay's view material
    self.loadingRules.material = NSVisualEffectMaterialHUDWindow;
    
    //setup observer for new rules
    // will be broadcast (via XPC) when daemon updates rules
    self.rulesObserver = [[NSNotificationCenter defaultCenter] addObserverForName:RULES_CHANGED object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *notification)
    {
        //get new rules
        [self loadRules];
    }];
    
    return;
}

//get rules from daemon
// then, re-load rules table
-(void)loadRules
{
    //dbg msg
    os_log_debug(logHandle, "loading rules...");
    
    //show overlay
    self.loadingRules.hidden = NO;
    
    //start progress indicator
    [self.loadingRulesSpinner startAnimation:nil];
    
    //in background get rules
    // ...then load rule table table
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0),
    ^{
        //current rules (from ext)
        NSDictionary* currentRules = nil;
        
        //sorted keys
        NSArray* sortedKeys = nil;
        
        //nap for UI (loading msg)
        [NSThread sleepForTimeInterval:0.5f];
        
        //get rules
        currentRules = [((AppDelegate*)[[NSApplication sharedApplication] delegate]).xpcDaemonClient getRules];
        
        //dbg msg
        os_log_debug(logHandle, "received %lu rules from daemon: %{public}@", (unsigned long)currentRules.count, currentRules.allKeys);
        
        //sync rules
        @synchronized (self)
        {
            //alloc
            self.rules = [[OrderedDictionary alloc] init];
        
            //dbg msg
            os_log_debug(logHandle, "sorting rules...");
            
            //sort by (rule) name
            sortedKeys = [currentRules keysSortedByValueUsingComparator:^NSComparisonResult(id _Nonnull obj1, id  _Nonnull obj2)
            {
                //compare/return
                return [((Rule*)[((NSDictionary*)obj1)[KEY_RULES] firstObject]).name compare:((Rule*)[((NSDictionary*)obj2)[KEY_RULES] firstObject]).name options:NSCaseInsensitiveSearch];
            }];
            
            //add sorted rules
            for(NSInteger i = 0; i<sortedKeys.count; i++)
            {
                //add to ordered dictionary
                [self.rules insertObject:currentRules[sortedKeys[i]] forKey:sortedKeys[i] atIndex:i];
            }
            
        }//sync
        
        //show rules in UI
        dispatch_async(dispatch_get_main_queue(), ^{
            
            //hide overlay
            self.loadingRules.hidden = YES;
            
            //no tab selected?
            // set 'all' as default
            if(nil == self.toolbar.selectedItemIdentifier)
            {
                //set all
                self.toolbar.selectedItemIdentifier = @"all";
            
                //set table header
                self.outlineView.tableColumns.firstObject.headerCell.stringValue = @"All Rules";
            }
                    
            //update ui
            [self update];
            
        });

    });
        
    return;
}

//update outline view
-(void)update
{
    //selected row
    __block NSInteger selectedRow = -1;
    
    //item's (new?) row
    __block NSInteger itemRow = -1;
    
    //currently selected item
    __block id selectedItem = nil;
    
    //sync
    // filter & reload
    @synchronized (self)
    {
        //dbg msg
        os_log_debug(logHandle, "updating outline view for rules...");
        
        //get currently selected row
        // default to first row if this fails
        selectedRow = self.outlineView.selectedRow;
        if(-1 == selectedRow) selectedRow = 0;
        
        //grab selected item
        selectedItem = [self.outlineView itemAtRow:selectedRow];
        
        //always filter
        self.rulesFiltered = [self filter];
        
        //begin updates
        [self.outlineView beginUpdates];
        
        //full reload
        [self.outlineView reloadData];
        
        //auto expand
        [self.outlineView expandItem:nil expandChildren:YES];
        
        //end updates
        [self.outlineView endUpdates];
        
        //find row for new rule
        if(nil != self.addedRule)
        {
            //find row
            selectedRow = [self findRowForItem:self.addedRule];
            
            //unset
            self.addedRule = nil;
        }
        else
        {
            //get selected item's (new) row
            itemRow = [self findRowForItem:selectedItem];
            if(-1 != itemRow)
            {
                //set
                selectedRow = itemRow;
            }
        }
        
        //prev selected now beyond bounds?
        // just default to select last row...
        selectedRow = MIN(selectedRow, (self.outlineView.numberOfRows-1));
        
        //(re)select & scroll
        dispatch_async(dispatch_get_main_queue(),
        ^{
            //reselect
            [self.outlineView selectRowIndexes:[NSIndexSet indexSetWithIndex:selectedRow] byExtendingSelection:NO];
            
            //scroll
            [self.outlineView scrollRowToVisible:selectedRow];
        });

    } //sync
    
bail:
        
    return;
}

//toolbar button handle
// generate filtered rules and reload table
-(IBAction)toolbarHandler:(id)sender
{
    //toolbar item tag
    NSInteger tag = -1;
    
    //grab tag
    tag = ((NSToolbarItem*)sender).tag;
    
    //dbg msg
    os_log_debug(logHandle, "user clicked toolbar item, %{public}@ (tag: %ld)", ((NSToolbarItem*)sender).label, (long)tag);
    
    //set column title
    switch (tag)
    {
        //all
        case RULE_TYPE_ALL:
            self.outlineView.tableColumns.firstObject.headerCell.stringValue = @"All Rules";
            break;
            
        //default
        case RULE_TYPE_DEFAULT:
            self.outlineView.tableColumns.firstObject.headerCell.stringValue = @"Operating System Programs (required for system functionality)";
            
            break;
            
        //apple
        case RULE_TYPE_APPLE:
            self.outlineView.tableColumns.firstObject.headerCell.stringValue = @"Apple Programs (automatically allowed & added here if 'allow apple programs' is set)";
            
            break;
          
        //baseline
        case RULE_TYPE_BASELINE:
            self.outlineView.tableColumns.firstObject.headerCell.stringValue = @"Pre-installed 3rd-party Programs (automatically allowed & added here if 'allow installed applications' is set)";
            
            break;
            
        //user
        case RULE_TYPE_USER:
            self.outlineView.tableColumns.firstObject.headerCell.stringValue = @"User-specified Programs (manually added, or in response to an alert)";
            break;
            
        //automatic
        case RULE_TYPE_UNCLASSIFIED:
            self.outlineView.tableColumns.firstObject.headerCell.stringValue = @"Automatically Approved Programs (allowed as user was not logged in)";
            break;
            
        
        default:
            break;
    }
    
    //unselect row
    [self.outlineView deselectRow:self.outlineView.selectedRow];
    
    //reload table
    [self update];
    
    //'add rules' only allowed for 'all' and 'user' views
    if( (tag == RULE_TYPE_ALL) ||
        (tag == RULE_TYPE_USER) )
    {
        //change label color to default
        self.addRuleLabel.textColor = [NSColor labelColor];
        
        //enable button
        self.addRuleButton.enabled = YES;
    }
    //'add rule' not allowed for 'default'/'apple'/'baseline'
    else
    {
        //change label color to gray
        self.addRuleLabel.textColor = [NSColor controlBackgroundColor];
        
        //disable button
        self.addRuleButton.enabled = NO;
    }
    
    return;
}

//filter (search box) handler
// just call into update method (which filters, etc)
-(IBAction)filterBoxHandler:(id)sender {
    
    //dbg msg
    os_log_debug(logHandle, "filtering rules...");
    
    //update
    [self update];
    
    return;
}

//double-click handler
// if it's an (editable) rule, bring up add/edit box
-(void)doubleClickHandler:(id)object
{
    //clicked row
    NSInteger row = 0;
    
    //item
    id item = nil;
    
    //dbg msg
    os_log_debug(logHandle, "method '%s' invoked", __PRETTY_FUNCTION__);

    //get row
    row = [self.outlineView clickedRow];
    
    //get item
    item = [self.outlineView itemAtRow:row];
    
    //dbg msg
    os_log_debug(logHandle, "row: %ld, item: %{public}@", (long)row, item);
    
    //item row?
    // show paths
    if(YES == [item isKindOfClass:[NSArray class]])
    {
        //show paths
        [self showItemPaths:((NSArray*)item).firstObject];
    }
    
    //rule row
    // ...only allowed editable ones
    else if( (YES == [item isKindOfClass:[Rule class]]) &&
             (RULE_TYPE_DEFAULT != ((Rule*)item).type.intValue) )
    {
        //add (edit) rule
        [self addRule:item];
    }
    
bail:
    
    return;

}

//show paths in sheet
-(void)showItemPaths:(Rule*)rule
{
    //dbg msg
    os_log_debug(logHandle, "method '%s' invoked with %{public}@", __PRETTY_FUNCTION__, rule);
    
    //alloc sheet
    self.itemPathsWindowController = [[ItemPathsWindowController alloc] initWithWindowNibName:@"ItemPaths"];
    
    //set rule
    self.itemPathsWindowController.rule = rule;
    
    //show it
    [self.window beginSheet:self.itemPathsWindowController.window completionHandler:^(NSModalResponse returnCode) {
        
        //unset
        self.itemPathsWindowController = nil;
        
    }];
    
    return;
}

//button handler for 'add rules'
// show 'add rule' sheet and then, on close, add rule via XPC
-(IBAction)addRule:(id)sender
{
    //dbg msg
    os_log_debug(logHandle, "method '%s' invoked with %{public}@", __PRETTY_FUNCTION__, sender);
    
    //alloc sheet
    self.addRuleWindowController = [[AddRuleWindowController alloc] initWithWindowNibName:@"AddRule"];
    
    //invoked with existing rule (to edit)
    if(YES == [sender isKindOfClass:[Rule class]])
    {
        //set rule
        self.addRuleWindowController.rule = (Rule*)sender;
    }
    
    //show it
    // on close/OK, invoke XPC to add rule, then reload
    [self.window beginSheet:self.addRuleWindowController.window completionHandler:^(NSModalResponse returnCode) {
        
        //(existing) rule
        Rule* rule = nil;
        
        //dbg msg
        os_log_debug(logHandle, "add/edit rule window closed...");
        
        //on OK, add rule via XPC
        if(returnCode == NSModalResponseOK)
        {
            //was an update to an existing rule?
            // delete it first, then go ahead and add
            if(nil != (rule = self.addRuleWindowController.rule))
            {
                //remove rule via XPC
                [((AppDelegate*)[[NSApplication sharedApplication] delegate]).xpcDaemonClient deleteRule:rule.key rule:rule.uuid];
            }
            
            //add rule via XPC
            [((AppDelegate*)[[NSApplication sharedApplication] delegate]).xpcDaemonClient addRule:self.addRuleWindowController.info];
            
            //new rule?
            // save path, and toggle to user tab
            if(nil == rule)
            {
                //user tab
                self.toolbar.selectedItemIdentifier = @"user";
                
                //save into iVar
                // allows table to select/scroll to this new rule
                self.addedRule = self.addRuleWindowController.info[KEY_PATH];
            }
                    
            //reload
            [self loadRules];
            
        } //NSModalResponseOK

        //unset add rule window controller
        self.addRuleWindowController = nil;
        
    }];
    
    return;
}

//init array of filtered rules
// determines what toolbar item is selected, then sort based on that and also what's in search box
-(OrderedDictionary*)filter
{
    //filtered items
    OrderedDictionary* results = nil;
    
    //filter string
    NSString* filter = nil;

    //selected toolbar item
    NSToolbarItem* selectedItem = nil;
    
    //dbg msg
    os_log_debug(logHandle, "filtering rules...");
    
    //init
    results = [[OrderedDictionary alloc] init];
    
    //grab filter string
    filter = self.filterBox.stringValue;
    
    //find selected toolbar item
    for(NSToolbarItem* toolbarItem in self.toolbar.items)
    {
        //find
        if(YES == [toolbarItem.itemIdentifier isEqualToString:self.toolbar.selectedItemIdentifier])
        {
            //found match
            selectedItem = toolbarItem;
            
            //all done
            break;
        }
    }
    
    //dbg msg
    os_log_debug(logHandle, "selected toolbar item: %{public}@ %ld", selectedItem.itemIdentifier, (long)selectedItem.tag);
    
    //all/no filter
    // don't need to filter
    if( (RULE_TYPE_ALL == selectedItem.tag) &&
        (0 == self.filterBox.stringValue.length) )
    {
        //dbg msg
        os_log_debug(logHandle, "selected toolbar item is 'all' and filter box is empty ...no need to filter");
        
        //no filter
        results = self.rules;
        
        //bail
        goto bail;
    }
          
    //dbg msg
    os_log_debug(logHandle, "filtering on '%{public}@'", filter);
    
    //scan all rules
    // add any that match toolbar and filter string
    {[self.rules enumerateKeysAndObjectsUsingBlock:^(id key, id value, BOOL* stop) {
        
        //item
        // cs info, rules, etc
        NSMutableDictionary* item = nil;
        
        //(item's) rules that match
        NSMutableArray* matchedRules = nil;
        
        //not on 'all' tab?
        // and no match on selected toolbar tab? ...skip
        if( (RULE_TYPE_ALL != selectedItem.tag) &&
            (selectedItem.tag != ((Rule*)[value[KEY_RULES] firstObject]).type.intValue) )
        {
            //skip
            return;
        }
        
        //no filter string?
        // it's a 'match, add, and continue
        if(0 == filter.length)
        {
            //append
            [results insertObject:value forKey:key atIndex:results.count];
            
            //next
            return;
        }
        
        //init matched (process) rules
        matchedRules = [NSMutableArray array];
        
        //check each rule(s)
        for(Rule* rule in value[KEY_RULES])
        {
            //match?
            // save rule
            if(YES == [rule matchesString:filter])
            {
                //add
                [matchedRules addObject:rule];
            }
        }
        
        //any matched (item) rules?
        // update item rule array and add item
        if(0 != matchedRules.count)
        {
            //make copy
            item = [value mutableCopy];
            
            //update item's rules
            item[KEY_RULES] = matchedRules;
            
            //append to filtered results
            [results insertObject:item forKey:key atIndex:results.count];
        }
        
    }];}
            
bail:
    
    //dbg msg
    os_log_debug(logHandle, "filtered rules: %{public}@", results.allKeys);
    
    return results;
}


#pragma mark -
#pragma mark outline delegate methods

//number of the children
-(NSInteger)outlineView:(NSOutlineView *)outlineView numberOfChildrenOfItem:(id)item
{
    //# of children
    // root: all
    // non-root, just items in item
    return (nil == item) ? self.rulesFiltered.count : [item count];
}

//items (processes) are expandable
// these items are built from items of type array
-(BOOL)outlineView:(NSOutlineView *)outlineView isItemExpandable:(id)item
{
    return (YES == [item isKindOfClass:[NSArray class]]);
}

//return child
-(id)outlineView:(NSOutlineView *)outlineView child:(NSInteger)index ofItem:(id)item
{
    //child
    id child = nil;
    
    //key
    id key = nil;
    
    //a root item?
    // 'child' is array of rules
    if(nil == item)
    {
        //key
        key = [self.rulesFiltered keyAtIndex:index];
        
        //child
        child = self.rulesFiltered[key][KEY_RULES];
    }
    //otherwise
    // child is rule at index
    else
    {
        //set child
        child = item[index];
    }
    
    return child;
}

//return custom row for view
// allows highlighting, etc...
-(NSTableRowView *)outlineView:(NSOutlineView *)outlineView rowViewForItem:(id)item
{
    //row view
    RuleRow* rowView = nil;
    
    //row ID
    static NSString* const kRowIdentifier = @"RowView";
    
    //try grab existing row view
    rowView = [self.outlineView makeViewWithIdentifier:kRowIdentifier owner:self];
    
    //make new if needed
    if(nil == rowView)
    {
        //create new
        // size doesn't matter
        rowView = [[RuleRow alloc] initWithFrame:NSZeroRect];
        
        //set row ID
        rowView.identifier = kRowIdentifier;
    }

    return rowView;
}

//table delegate method
// return new cell for row
-(NSView *)outlineView:(NSOutlineView *)outlineView viewForTableColumn:(NSTableColumn *)tableColumn item:(id)item
{
    //view
    NSTableCellView* cell = nil;
    
    //first rule
    Rule* rule = nil;
        
    //first column
    // process or connection
    if(tableColumn == self.outlineView.tableColumns[0])
    {
        //a root item?
        if(YES == [item isKindOfClass:[NSArray class]])
        {
            //grab first rule
            rule = [item firstObject];
            
            //create/configure process cell
            cell = [self createProcessCell:rule];
        }
        //child
        // create/configure event cell
        else
        {
            //create/configure process cell
            cell = [self createConnectionCell:item];
        }
    }
    //all other columns
    // init a basic cell
    else if(tableColumn == self.outlineView.tableColumns[1])
    {
        //init table cell
        cell = [self.outlineView makeViewWithIdentifier:@"ruleCell" owner:self];
        if(nil == cell) goto bail;
        
        //only add rule for connection (i.e. not root item)
        if(YES == [item isKindOfClass:[Rule class]])
        {
            //typecast
            rule = (Rule*)item;
            
            //block?
            if(RULE_STATE_BLOCK == rule.action.integerValue)
            {
                //set image
                cell.imageView.image = [NSImage imageNamed:@"MainAppRulesBlock"];
                
                //set text
                cell.textField.stringValue = @"block";
            }
            //allow?
            else
            {
                //set image
                cell.imageView.image = [NSImage imageNamed:@"MainAppRulesAllow"];
                
                //set text
                cell.textField.stringValue = @"allow";
            }
        }
        //otherwise unset image/text
        else
        {
            //grab first rule
            rule = [item firstObject];
            
            //unset image
            cell.imageView.image = nil;
            
            //unset text
            cell.textField.stringValue = @"";
        }
        
        //disable button delete button if rule is a default (system) rule
        if(RULE_TYPE_DEFAULT == rule.type.intValue)
        {
            //disable
            [(NSButton*)[cell viewWithTag:TABLE_ROW_DELETE_TAG] setEnabled:NO];
        }
        
        //otherwise
        // enable delete button
        else
        {
            //enable
            [(NSButton*)[cell viewWithTag:TABLE_ROW_DELETE_TAG] setEnabled:YES];
        }
    }
    
bail:
    
    return cell;

}

//create & customize process cell
// this are the root cells, that hold the item (process)
-(NSTableCellView*)createProcessCell:(Rule*)rule
{
    //item cell
    NSTableCellView* processCell = nil;
    
    //create cell
    processCell = [self.outlineView makeViewWithIdentifier:@"processCell" owner:self];
    
    //global rule?
    // no icon, no path, etc.
    if(YES == [rule.path isEqualToString:VALUE_ANY])
    {
        //set icon
        processCell.imageView.image = [[NSWorkspace sharedWorkspace]
        iconForFileType: NSFileTypeForHFSTypeCode(kGenericHardDiskIcon)];
        
        //set text
        processCell.textField.stringValue = @"Any Process";
    }
    
    //non global rule?
    // set icon, path, etc.
    else
    {
        //set icon
        processCell.imageView.image = getIconForProcess(rule.path);
        
        //main text
        // item's name
        processCell.textField.stringValue = rule.name;
        
        //details
        ((NSTextField*)[processCell viewWithTag:TABLE_ROW_SUB_TEXT]).stringValue = [self formatItemDetails:rule];
    }
    
    return processCell;
}

//format details for item
-(NSString*)formatItemDetails:(Rule*)rule
{
    //details
    NSString* details = @"";
    
    //signer
    NSInteger signer = None;
    
    //cs info?
    if(nil != rule.csInfo)
    {
        //format, based on signer
        switch([rule.csInfo[KEY_CS_SIGNER] intValue])
        {
            //apple
            case Apple:
                details = [NSString stringWithFormat:@"%@ (signer: Apple Proper)", rule.csInfo[KEY_CS_ID]];
                break;
            
            //app store
            case AppStore:
                details = [NSString stringWithFormat:@"%@ (signer: Apple Mac OS App Store)", rule.csInfo[KEY_CS_ID]];
                break;
                
            //dev id
            case DevID:
                details = [NSString stringWithFormat:@"%@ (signer: %@)", rule.csInfo[KEY_CS_ID], [rule.csInfo[KEY_CS_AUTHS] firstObject]];
                break;
                
            default:
                break;
        }
    }
    
    //no valid cs info, etc
    // just use item's path
    if(0 == details.length)
    {
        //set
        details = [NSString stringWithFormat:@"%@ (signer: invalid/unsigned)", rule.path];
    }

    return details;
}

//create & customize connection cell
-(NSTableCellView*)createConnectionCell:(Rule*)rule
{
    //endpoint port
    NSString* port = nil;
    
    //endpoint addr
    NSString* address = nil;
    
    //item cell
    NSTableCellView* cell = nil;
    
    //create cell
    cell = [self.outlineView makeViewWithIdentifier:@"simpleCell" owner:self];
    
    //reset text
    ((NSTableCellView*)cell).textField.stringValue = @"";
    
    //set endpoint addr
    address = (YES == [rule.endpointAddr isEqualToString:VALUE_ANY]) ? @"any address" : rule.endpointAddr;
    
    //set endpoint port
    port = (YES == [rule.endpointPort isEqualToString:VALUE_ANY]) ? @"any port" : rule.endpointPort;
    
    //set main text
    cell.textField.stringValue = [NSString stringWithFormat:@"%@:%@", address, port];

    return cell;
}

//delete a rule
// grab rule, then invoke daemon to delete
-(IBAction)deleteRule:(id)sender
{
    //index of row
    // either clicked or selected row
    NSInteger row = 0;
    
    //item
    id item = nil;
    
    //rule
    Rule* rule = nil;
    
    //dbg msg
    os_log_debug(logHandle, "deleting rule...");
    
    //get row
    if(nil != sender)
    {
        //row from sender
        row = [self.outlineView rowForView:sender];
    }
    //otherwise get selected row
    else
    {
        //selected row
        row = self.outlineView.selectedRow;
    }
    
    //get item
    item = [self.outlineView itemAtRow:row];
    
    //dbg msg
    os_log_debug(logHandle, "row: %ld, item: %{public}@", (long)row, item);
    
    //get rule
    // a root item? any rule is fine
    if(YES == [item isKindOfClass:[NSArray class]])
    {
        //grab first rule
        rule = [item firstObject];
    }
    //child
    // item is the rule
    else
    {
        //typecast
        rule = (Rule*)item;
    }
    
    //remove rule via XPC
    // nil uuid, means delete all rules for item (process)
    [((AppDelegate*)[[NSApplication sharedApplication] delegate]).xpcDaemonClient deleteRule:rule.key rule:rule.uuid];
    
    //(re)load rules
    [self loadRules];
    
bail:
    
    return;
}

//find row for item
-(NSInteger)findRowForItem:(id)item
{
    //row
    NSInteger row = -1;
    
    //current item
    id currentItem = nil;
    
    //scan outline to find matching object
    for(NSUInteger i = 0; i < self.outlineView.numberOfRows; i++)
    {
        //extract current item
        currentItem = [self.outlineView itemAtRow:i];
        
        //looking for path?
        // only apply to item/process objects
        if( (YES == [item isKindOfClass:[NSString class]]) &&
            (YES == [currentItem isKindOfClass:[NSArray class]]) )
        {
            //paths match?
            if(YES == [item isEqualToString:((Rule*)[currentItem firstObject]).path])
            {
               //save index
               row = i;
               
               //all done
               break;
            }
        }
        
        //looking for item?
        // grab first rule from it's array and compare paths
        else if( (YES == [item isKindOfClass:[NSArray class]]) &&
                 (YES == [currentItem isKindOfClass:[NSArray class]]) )
        {
            //paths match?
            if(YES == [((Rule*)[item firstObject]).path isEqualToString:((Rule*)[currentItem firstObject]).path])
            {
               //save index
               row = i;
               
               //all done
               break;
            }
        }
        
        //looking for rule?
        else if( (YES == [item isKindOfClass:[Rule class]]) &&
                 (YES == [currentItem isKindOfClass:[Rule class]]) )
        {
            //rules match?
            if(YES == [(Rule*)item isEqualToRule:(Rule*)currentItem])
            {
               //save index
               row = i;
               
               //all done
               break;
            }
        }
        
    }//all items
    
    return row;
}

//menu handler for row context menu
-(IBAction)rowMenuHandler:(id)sender
{
    //item
    id item = nil;
    
    //get item
    item = [self.outlineView itemAtRow:self.outlineView.selectedRow];
    
    //handle click
    switch(((NSMenuItem*)sender).tag)
    {
        //show paths
        case MENU_SHOW_PATHS:
            
            //sanity check
            if(YES != [item isKindOfClass:[NSArray class]]) goto bail;
            
            //show paths
            [self showItemPaths:((NSArray*)item).firstObject];
            
            break;
            
        //edit rule
        case MENU_EDIT_RULE:
            
            //sanity check
            if(YES != [item isKindOfClass:[Rule class]]) goto bail;
            
            //show paths
            [self addRule:item];
            
            break;
            
        //delete rule
        case MENU_DELETE_RULE:
            
            //delete
            [self deleteRule:nil];
            
            break;
        

        default:
            
            break;
    }
    
bail:
    
    return;
}

//on window close
// set activation policy
-(void)windowWillClose:(NSNotification *)notification
{
     //wait a bit, then set activation policy
     dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0),
     ^{
         //on main thread
         dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
             
             //set activation policy
             [((AppDelegate*)[[NSApplication sharedApplication] delegate]) setActivationPolicy];
             
         });
     });
    
    return;
}

@end
