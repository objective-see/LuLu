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

#define SORT_DESCRIPTOR_COLUMN_0 @"sort_0"

/* GLOBALS */

//log handle
extern os_log_t logHandle;

//xpc for daemon comms
extern XPCDaemonClient* xpcDaemonClient;

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
    [self loadRules:YES];
    
    //select first row
    [self.outlineView selectRowIndexes:[NSIndexSet indexSetWithIndex:0] byExtendingSelection:NO];

    return;
}

//alloc/init
// get rules and listen for new ones
-(void)windowDidLoad
{
    //set default rule's view
    self.selectedRuleView = RULE_TYPE_ALL;
    
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
    
    //set initial table header
    self.outlineView.tableColumns.firstObject.headerCell.stringValue = NSLocalizedString(@"All Rules",@"All Rules");
    
    //set sort descriptor for first column
    [self.outlineView.tableColumns[0] setSortDescriptorPrototype:[[NSSortDescriptor alloc] initWithKey:SORT_DESCRIPTOR_COLUMN_0 ascending:YES]];
    
    //set it to whole too...
    [self.outlineView setSortDescriptors:@[self.outlineView.tableColumns[0].sortDescriptorPrototype]];
    
    //set flag
    self.isAscending = YES;
 
    //setup observer for new rules
    // will be broadcast (via XPC) when daemon updates rules
    self.rulesObserver = [[NSNotificationCenter defaultCenter] addObserverForName:RULES_CHANGED object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *notification)
    {
        //get new rules
        [self loadRules:YES];
    }];
    
    return;
}

//get rules from daemon
// then, re-load rules table
-(void)loadRules:(BOOL)showOverlay
{
    //dbg msg
    os_log_debug(logHandle, "loading rules...");
    
    //show overlay
    if(YES == showOverlay)
    {
        //show overlay
        self.loadingRules.hidden = NO;
        
        //start progress indicator
        [self.loadingRulesSpinner startAnimation:nil];
    }
    
    //in background get rules
    // ...then load rule table table
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0),
    ^{
        //current rules (from ext)
        NSDictionary* currentRules = nil;
        
        //sorted keys
        NSArray* sortedKeys = nil;
        
        //show overlay
        if(YES == showOverlay)
        {
            //nap for UI (loading msg)
            [NSThread sleepForTimeInterval:0.5f];
        }
        
        //get rules
        currentRules = [xpcDaemonClient getRules];
        
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
                //normal
                if(YES == self.isAscending)
                {
                    //compare/return
                    return [((Rule*)[((NSDictionary*)obj1)[KEY_RULES] firstObject]).name compare:((Rule*)[((NSDictionary*)obj2)[KEY_RULES] firstObject]).name options:NSCaseInsensitiveSearch];
                }
                //reversed
                else
                {
                    //compare/return
                    return [((Rule*)[((NSDictionary*)obj2)[KEY_RULES] firstObject]).name compare:((Rule*)[((NSDictionary*)obj1)[KEY_RULES] firstObject]).name options:NSCaseInsensitiveSearch];
                }
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
            
            //show overlay
            if(YES == showOverlay)
            {
                //hide overlay
                self.loadingRules.hidden = YES;
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
    //__block NSInteger itemRow = -1;
    
    //currently selected item
    //__block id selectedItem = nil;
    
    //sync
    // filter & reload
    @synchronized(self)
    {
        //dbg msg
        os_log_debug(logHandle, "updating outline view for rules...");
        
        //get currently selected row
        // default to first row if this fails
        selectedRow = self.outlineView.selectedRow;
        if(-1 == selectedRow) 
        {
            //default
            selectedRow = 0;
        }
        
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
        
        /*
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
        */
        
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

//handler for rule select view
-(IBAction)rulesViewSelectorHandler:(id)sender {
    
    //dbg msg
    os_log_debug(logHandle, "method '%s' invoked", __PRETTY_FUNCTION__);
    
    //save
    // subtract one, since rule types start at -1
    self.selectedRuleView = self.rulesViewSelector.indexOfSelectedItem - 1;
    
    //set column title
    switch(self.selectedRuleView)
    {
        //all
        case RULE_TYPE_ALL:
            
            self.outlineView.tableColumns.firstObject.headerCell.stringValue = NSLocalizedString(@"All Rules", @"All Rules");
            break;
            
        //default
        case RULE_TYPE_DEFAULT:
            
            self.outlineView.tableColumns.firstObject.headerCell.stringValue = NSLocalizedString(@"Operating System Programs (required for system functionality)", @"Operating System Programs (required for system functionality)");
            break;
            
        //apple
        case RULE_TYPE_APPLE:
            
            self.outlineView.tableColumns.firstObject.headerCell.stringValue = NSLocalizedString(@"Apple Programs (automatically allowed & added here if 'allow apple programs' is set)", @"Apple Programs (automatically allowed & added here if 'allow apple programs' is set)");
            break;
          
        //baseline
        case RULE_TYPE_BASELINE:
            
            self.outlineView.tableColumns.firstObject.headerCell.stringValue = NSLocalizedString(@"Pre-installed 3rd-party Programs (automatically allowed & added here if 'allow installed applications' is set)", @"Pre-installed 3rd-party Programs (automatically allowed & added here if 'allow installed applications' is set)");
            break;
            
        //user
        case RULE_TYPE_USER:
            
            self.outlineView.tableColumns.firstObject.headerCell.stringValue = NSLocalizedString(@"User-specified Programs (manually added, or in response to an alert)", @"User-specified Programs (manually added, or in response to an alert)");
            
            break;
            
        case RULE_TYPE_RECENT:
            
            self.outlineView.tableColumns.firstObject.headerCell.stringValue = NSLocalizedString(@"Added in last 24 hours (sorted by creation time)", @"Added in last 24 hours (sorted by creation time)");
            break;
            
        
        default:
            break;
    }
    
    //unselect (all) row
    [self.outlineView deselectAll:nil];
    
    //reload table
    [self update];
    
    //'add rules' only allowed for 'all' and 'user' views
    if( (self.selectedRuleView == RULE_TYPE_ALL) ||
        (self.selectedRuleView == RULE_TYPE_USER) )
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
// bring up add/edit box
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
    // ...show paths
    if(YES == [item isKindOfClass:[NSArray class]])
    {
        //show paths
        [self showItemPaths:((Rule*)((NSArray*)item).firstObject).key];
    }
    
    //rule row
    // ...edit!
    else if(YES == [item isKindOfClass:[Rule class]])
    {
        //default rule?
        // show alert/warning
        if(RULE_TYPE_DEFAULT == ((Rule*)item).type.intValue)
        {
            //show alert
            // ...and bail if user cancels
            if(NSAlertSecondButtonReturn == [self showDefaultRuleAlert:item action:@"Editing"])
            {
                //bail
                goto bail;
            }
        }
        
        //add (edit) rule
        [self addRule:item];
    }
    
bail:
    
    return;
}

//warn user the modifying default rules might break things
-(NSModalResponse)showDefaultRuleAlert:(Rule*)rule action:(NSString*)action
{
    return showAlert(NSAlertStyleWarning, [NSString stringWithFormat:NSLocalizedString(@"%@ is legitimate macOS process", @"%@ is legitimate macOS process"), rule.name], [NSString stringWithFormat:NSLocalizedString(@"%@ this rule, may impact legitimate system functionalty ...continue?",@"%@ this rule, may impact legitimate system functionalty ...continue?"), action], @[NSLocalizedString(@"Continue", @"Continue"), NSLocalizedString(@"Cancel", @"Cancel")]);
}

//show paths in sheet
-(void)showItemPaths:(NSString*)itemKey
{
    //current rules (from ext)
    NSDictionary* currentRules = nil;
    
    //dbg msg
    os_log_debug(logHandle, "method '%s' invoked with %{public}@", __PRETTY_FUNCTION__, itemKey);
    
    //alloc sheet
    self.itemPathsWindowController = [[ItemPathsWindowController alloc] initWithWindowNibName:@"ItemPaths"];

    //get latest rules
    currentRules = [xpcDaemonClient getRules];
    
    //set rules
    self.itemPathsWindowController.item = currentRules[itemKey];
    
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
        //default rule?
        //show alert/warning
        if(RULE_TYPE_DEFAULT == ((Rule*)sender).type.intValue)
        {
            //show alert
            // ...and bail if user cancels
            if(NSAlertSecondButtonReturn == [self showDefaultRuleAlert:sender action:@"Editing"])
            {
                //bail
                goto bail;
            }
        }
        
        //set rule
        self.addRuleWindowController.rule = (Rule*)sender;
    }
    
    //show it
    // on close/OK, invoke XPC to add rule, then reload
    NSModalResponse response = [NSApp runModalForWindow:self.addRuleWindowController.window];
    {
        
        //(existing) rule
        Rule* rule = nil;
        
        //dbg msg
        os_log_debug(logHandle, "add/edit rule window closed...");
        
        //on OK, add rule via XPC
        if(response == NSModalResponseOK)
        {
            //was an update to an existing rule?
            // delete it first, then go ahead and add
            if(nil != (rule = self.addRuleWindowController.rule))
            {
                //remove rule via XPC
                [xpcDaemonClient deleteRule:rule.key rule:rule.uuid];
            }
            
            //add rule via XPC
            [xpcDaemonClient addRule:self.addRuleWindowController.info];
            
            //new rule?
            // save path, and toggle to user tab
            if(nil == rule)
            {
                //save into iVar
                // allows table to select/scroll to this new rule
                self.addedRule = self.addRuleWindowController.info[KEY_PATH];
            }
            
            //reload
            [self loadRules:YES];
        }
        
        //unset add rule window controller
        self.addRuleWindowController = nil;
        
    }
    
bail:
    
    return;
}

//init array of filtered rules
// determines what rule view is selected, then sort based on that and also what's in search box
-(OrderedDictionary*)filter
{
    //filtered items
    OrderedDictionary* results = nil;
    
    //sorted keys
    NSArray* sortedKeys = nil;
    
    //sorted rules
    OrderedDictionary* sortedRules = nil;
    
    //filter string
    NSString* filter = nil;
    
    //dbg msg
    os_log_debug(logHandle, "filtering rules...");
    
    //init
    results = [[OrderedDictionary alloc] init];
    
    //grab filter string
    filter = self.filterBox.stringValue;
    
    //dbg msg
    os_log_debug(logHandle, "selected rule view: %ld", self.selectedRuleView);
    
    //all/no filter
    // don't need to filter
    if( (RULE_TYPE_ALL == self.selectedRuleView) &&
        (0 == filter.length) )
    {
        //dbg msg
        os_log_debug(logHandle, "selected toolbar item is 'all' and filter box is empty ...no need to filter");
        
        //no filter
        results = self.rules;
        
        //bail
        goto bail;
    }
    
    //dbg msg
    if(0 != filter.length)
    {
        //dbg msg
        os_log_debug(logHandle, "filtering on '%{public}@'", filter);
    }
        
    //scan all rules
    // add any that match rule view and filter string
    {[self.rules enumerateKeysAndObjectsUsingBlock:^(id key, id value, BOOL* stop) {
        
        //item
        // cs info, rules, etc
        NSMutableDictionary* item = nil;
        
        //item's rules
        NSArray* itemRules = nil;
        
        //(item') recent rules
        NSMutableArray* recentRules = nil;
        
        //(item's) rules that match
        NSMutableArray* matchedRules = nil;
        
        //make copy
        item = [value mutableCopy];
        
        //item's rules
        itemRules = item[KEY_RULES];
        
        //init
        matchedRules = [NSMutableArray array];
        
        //not on 'all'/'recent' view?
        // skip rules if they don't match selected toolbar type
        if( (RULE_TYPE_ALL != self.selectedRuleView) &&
            (RULE_TYPE_RECENT != self.selectedRuleView) )
        {
            //check all item's rule for match
            for(Rule* itemRule in itemRules)
            {
                //match?
                if(self.selectedRuleView == itemRule.type.intValue)
                {
                    //add
                    [matchedRules addObject:itemRule];
                }
            }
            
            //done if no item rules match
            if(0 == matchedRules.count)
            {
                return;
            }
            
            //update
            item[KEY_RULES] = [matchedRules mutableCopy];
            
            //reset
            // as we reuse this in filtering
            [matchedRules removeAllObjects];
        }
        
        //recent?
        if(RULE_TYPE_RECENT == self.selectedRuleView)
        {
            //get (item's) recent rules
            recentRules = [self recentRules:itemRules];
            
            //item doesn't have any recent rules
            if(0 == recentRules.count)
            {
                //skip
                return;
            }
            
            //make copy
            item = [value mutableCopy];
            
            //update item's rules
            item[KEY_RULES] = recentRules;
        }
        
        //no filter?
        // we're done
        if(0 == filter.length)
        {
            //append
            [results insertObject:item forKey:key atIndex:results.count];
                        
            //next
            return;
        }
        
        /* NOW FILTER */
        
        //check each rule(s) on filter string
        for(Rule* rule in item[KEY_RULES])
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
            //update item's rules
            item[KEY_RULES] = matchedRules;
            
            //append to filtered results
            [results insertObject:item forKey:key atIndex:results.count];
        }
        
    }];}
    
    //sort recent rules
    if(RULE_TYPE_RECENT == self.selectedRuleView)
    {
        //nap for UI (loading msg)
        [NSThread sleepForTimeInterval:0.5f];
        
        //dbg msg
        os_log_debug(logHandle, "sorting (recent) rules by creation timestamp...");
        
        //init
        sortedRules = [[OrderedDictionary alloc] init];
        
        //sort by (rule) timestamp
        sortedKeys = [results keysSortedByValueUsingComparator:^NSComparisonResult(id _Nonnull obj1, id  _Nonnull obj2)
        {
            //normal
            if(YES == self.isAscending)
            {
                //compare/return
                return [((Rule*)[((NSDictionary*)obj2)[KEY_RULES] firstObject]).creation compare:((Rule*)[((NSDictionary*)obj1)[KEY_RULES] firstObject]).creation];
            }
            //reversed
            else
            {
                //compare/return
                return [((Rule*)[((NSDictionary*)obj1)[KEY_RULES] firstObject]).creation compare:((Rule*)[((NSDictionary*)obj2)[KEY_RULES] firstObject]).creation];
            }
        }];
        
        //add sorted rules
        for(NSInteger i = 0; i<sortedKeys.count; i++)
        {
            //add to ordered dictionary
            [sortedRules insertObject:results[sortedKeys[i]] forKey:sortedKeys[i] atIndex:i];
        }
        
        results = sortedRules;
    }
            
bail:
    
    //dbg msg
    os_log_debug(logHandle, "filtered rules: %{public}@", results.allKeys);
    
    return results;
}

//item's recent rules
// any that are after boot time
-(NSMutableArray*)recentRules:(NSArray*)itemRules
{
    //24 hrs ago
    NSDate* cutoff = nil;
    
    //recent
    NSMutableArray* recentRules = nil;
    
    //alloc/init
    recentRules = [NSMutableArray array];
    
    //init
    cutoff = [[NSDate date] dateByAddingTimeInterval:-(24 * 60 * 60)];
    
    //check each rule(s)
    for(Rule* rule in itemRules)
    {
        //skip older rules
        // ...didn't have creation time
        if(nil == rule.creation)
        {
            continue;
        }
        
        //not after
        if(NSOrderedDescending != [rule.creation compare:cutoff])
        {
            continue;
        }

        //add
        [recentRules addObject:rule];
    }
    
bail:
    
    //sort: ascending
    if(YES == self.isAscending)
    {
        //sort from newest to oldest
        [recentRules sortUsingComparator:^NSComparisonResult(Rule *rule1, Rule *rule2) {
                //compare the creation dates
                return [rule2.creation compare:rule1.creation];
        }];
    }
    //sort: descending
    else
    {
        //sort from oldest to newest
        [recentRules sortUsingComparator:^NSComparisonResult(Rule *rule1, Rule *rule2) {
                //compare the creation dates
                return [rule1.creation compare:rule2.creation];
        }];
    }
    
    
    
    

    return recentRules;
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
    //date formatter
    NSDateFormatter *dateFormatter = nil;
    
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
        
        //only add rule for connection (i.e. not item)
        if(YES == [item isKindOfClass:[Rule class]])
        {
            //action
            NSString* action = nil;
            
            //typecast
            rule = (Rule*)item;
            
            //block?
            if(RULE_STATE_BLOCK == rule.action.integerValue)
            {
                //set image
                cell.imageView.image = [NSImage imageNamed:@"RulesBlock"];
                
                //duration: process
                if(nil != rule.pid)
                {
                    //set msg
                    action = [NSString stringWithFormat:NSLocalizedString(@"Block (pid: %@)", @"Block (pid: %@)"), rule.pid];
                }
                
                //duration: expiration
                else if(nil != rule.expiration)
                {
                    //init date formatter
                    dateFormatter = [[NSDateFormatter alloc] init];
                    [dateFormatter setDateStyle:NSDateFormatterNoStyle];
                    [dateFormatter setTimeStyle:NSDateFormatterShortStyle];
                    
                    //set msg
                    action = [NSString stringWithFormat:NSLocalizedString(@"Block (until: %@)", @"Block (until: %@)"), [dateFormatter stringFromDate:rule.expiration]];
                }
                
                //normal
                else
                {
                    //set action text
                    action = NSLocalizedString(@"Block", @"Block");
                }
                
            }
            //allow?
            else
            {
                //set image
                cell.imageView.image = [NSImage imageNamed:@"RulesAllow"];
                
                //duration: process
                if(nil != rule.pid)
                {
                    //set msg
                    action = [NSString stringWithFormat:NSLocalizedString(@"Allow (pid: %@)", @"Allow (pid: %@)"), rule.pid];
                }
                
                //duration: expiration
                else if(nil != rule.expiration)
                {
                    //init date formatter
                    dateFormatter = [[NSDateFormatter alloc] init];
                    [dateFormatter setDateStyle:NSDateFormatterNoStyle];
                    [dateFormatter setTimeStyle:NSDateFormatterShortStyle];
                    
                    //set msg
                    action = [NSString stringWithFormat:NSLocalizedString(@"Allow (until: %@)", @"Allow (until: %@)"), [dateFormatter stringFromDate:rule.expiration]];
                }
                
                //normal
                else
                {
                    //set action text
                    action = NSLocalizedString(@"Allow", @"Allow");
                }
            }
            
            //set text
            cell.textField.stringValue = action;
            
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
        
        //enable
        [(NSButton*)[cell viewWithTag:TABLE_ROW_DELETE_TAG] setEnabled:YES];
    }
    
bail:
    
    return cell;
}

//sort
// really for now, just reverse
-(void)outlineView:(NSOutlineView *)outlineView sortDescriptorsDidChange:(NSArray<NSSortDescriptor *> *)oldDescriptors
{
    //dbg msg
    os_log_debug(logHandle, "method '%s' invoked", __PRETTY_FUNCTION__);
    
    //only sort first column: rule name
    if(YES == [outlineView.sortDescriptors.firstObject.key isEqualToString:SORT_DESCRIPTOR_COLUMN_0])
    {
        //reverse
        [self.rules reverse];
        
        //toggle
        self.isAscending = !self.isAscending;
        
        //unselect row
        // want top row to be selected after reverse
        [self.outlineView deselectAll:nil];

        //refresh table
        [self update];
    }
    
    return;
}

//create & customize process cell
// these are the root cells, that hold the item (process)
-(NSTableCellView*)createProcessCell:(Rule*)rule
{
    //item cell
    NSTableCellView* processCell = nil;
    
    //directory
    NSString* directory = nil;
    
    //create cell
    processCell = [self.outlineView makeViewWithIdentifier:@"processCell" owner:self];
    
    //global rule?
    // no icon, no path, etc.
    if(YES == rule.isGlobal.boolValue)
    {
        //set icon
        processCell.imageView.image = [[NSWorkspace sharedWorkspace]
        iconForFileType: NSFileTypeForHFSTypeCode(kGenericHardDiskIcon)];
        
        //set text
        processCell.textField.stringValue = NSLocalizedString(@"Any program", @"Any program");
        
        //(un)set detailed text
        ((NSTextField*)[processCell viewWithTag:TABLE_ROW_SUB_TEXT]).stringValue = @"";
    }
    //directory rule?
    else if(YES == rule.isDirectory.boolValue)
    {
        //init directory
        // ...by removing *
        directory = [rule.path substringToIndex:(rule.path.length-1)];
        
        //set icon
        processCell.imageView.image = getIconForProcess(directory);
        
        //main text
        // last directory
        processCell.textField.stringValue = [NSString stringWithFormat:NSLocalizedString(@"Programs within \"%@/\"", @"Programs within \"%@/\""), directory.lastPathComponent];
        
        //details
        // just use path
        ((NSTextField*)[processCell viewWithTag:TABLE_ROW_SUB_TEXT]).stringValue = rule.path;
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
        
        //format/set details
        ((NSTextField*)[processCell viewWithTag:TABLE_ROW_SUB_TEXT]).stringValue = [self formatItemDetails:rule];
    }
    
    return processCell;
}

//format details for item
-(NSString*)formatItemDetails:(Rule*)rule
{
    //details
    NSString* details = @"";
        
    //cs info?
    if(nil != rule.csInfo)
    {
        //format, based on signer
        switch([rule.csInfo[KEY_CS_SIGNER] intValue])
        {
            //apple
            case Apple:
                details = [NSString stringWithFormat:NSLocalizedString(@"%@ (signer: Apple Proper)", @"%@ (signer: Apple Proper)"), rule.csInfo[KEY_CS_ID]];
                break;
            
            //app store
            case AppStore:
                details = [NSString stringWithFormat:NSLocalizedString(@"%@ (signer: Apple Mac OS App Store)", @"%@ (signer: Apple Mac OS App Store)"), rule.csInfo[KEY_CS_ID]];
                break;
                
            //dev id
            case DevID:
                details = [NSString stringWithFormat:NSLocalizedString(@"%@ (signer: %@)",@"%@ (signer: %@)"), rule.csInfo[KEY_CS_ID], [rule.csInfo[KEY_CS_AUTHS] firstObject]];
                break;
                
            //ad hoc
            case AdHoc:
                details = [NSString stringWithFormat:NSLocalizedString(@"%@ (signer: %@)", @"%@ (signer: %@)"), rule.csInfo[KEY_CS_ID], NSLocalizedString(@"Ad hoc", @"Ad hoc")];
                break;
                
            default:
                break;
        }
    }
    
    //no valid cs info
    // just use path / and mention issue
    if(0 == details.length)
    {
        //set
        details = [NSString stringWithFormat:NSLocalizedString(@"%@ (signer: invalid/unsigned)", @"%@ (signer: invalid/unsigned)"), rule.path];
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
    
    //contents
    NSMutableString* contents = nil;
    
    //time stamp
    NSString* timestamp = nil;
    
    //contents + time stamp
    NSMutableAttributedString* contentsWithTimestamp = nil;
    
    //date formatter
    static NSDateFormatter *dateFormatter = nil;
    
    //string attributes
    static NSDictionary *attributes = nil;
    
    //token
    static dispatch_once_t onceToken = 0;
    
    //only once
    // init requirements
    dispatch_once(&onceToken, ^{
        
        //init
        dateFormatter = [[NSDateFormatter alloc] init];
        
        //config
        [dateFormatter setDateFormat:@"yyyy-MM-dd HH:mm"];
        
        //set (string) attributes
        attributes = @{NSForegroundColorAttributeName:NSColor.lightGrayColor, NSFontAttributeName:[NSFont fontWithName:@"Menlo-Regular" size:12]};
        
    });

    //create cell
    cell = [self.outlineView makeViewWithIdentifier:@"simpleCell" owner:self];
    
    //reset text
    ((NSTableCellView*)cell).textField.stringValue = @"";
    ((NSTableCellView*)cell).textField.attributedStringValue = [[NSAttributedString alloc] initWithString:@""];
    
    //set endpoint addr
    address = (YES == [rule.endpointAddr isEqualToString:VALUE_ANY]) ? NSLocalizedString(@"any address",@"any address") : rule.endpointAddr;
    
    //set endpoint port
    port = (YES == [rule.endpointPort isEqualToString:VALUE_ANY]) ? NSLocalizedString(@"any port",@"any port") : rule.endpointPort;
    
    //init addr/port
    contents = [NSMutableString stringWithFormat:@"%@:%@", address, port];
    
    //in "recents" view, add creation timestamp
    if(RULE_TYPE_RECENT == self.selectedRuleView)
    {
        //init contents
        contentsWithTimestamp = [[NSMutableAttributedString alloc] initWithString:contents];
        
        //init (formatted) timestamp
        timestamp = [NSString stringWithFormat:@" (created at: %@)", [dateFormatter stringFromDate:rule.creation]];
        
        //combine
        [contentsWithTimestamp appendAttributedString:[[NSAttributedString alloc] initWithString:timestamp attributes:attributes]];
    
        //set contents
        cell.textField.attributedStringValue = contentsWithTimestamp;
    }
    //no timestamp
    else
    {
        cell.textField.stringValue = contents;
    }

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
    
    //rule uuid
    NSString* uuid = nil;
    
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
        
        //set uuid
        uuid = rule.uuid;
    }
    
    //default rule?
    // show alert/warning
    if(RULE_TYPE_DEFAULT == rule.type.intValue)
    {
        //show alert
        // ...and bail if user cancels
        if(NSAlertSecondButtonReturn == [self showDefaultRuleAlert:rule action:@"Deleting"])
        {
            //bail
            goto bail;
        }
    }
    
    //remove rule via XPC
    // nil uuid, means delete all rules for item (process)
    [xpcDaemonClient deleteRule:rule.key rule:uuid];
    
    //(re)load rules
    // but no need to show overlay
    [self loadRules:NO];
    
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
            if(YES != [item isKindOfClass:[NSArray class]]) 
            {
                goto bail;
            }
            
            //show paths
            [self showItemPaths:((Rule*)((NSArray*)item).firstObject).key];
            
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


//button handler
// open LuLu home page/docs
-(IBAction)openHomePage:(id)sender {
    
    //open
    [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:PRODUCT_URL]];
    
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
