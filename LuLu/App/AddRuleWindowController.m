//
//  file: AddRuleWindowController.h
//  project: lulu
//  description: 'add/edit rule' window controller
//
//  created by Patrick Wardle
//  copyright (c) 2017 Objective-See. All rights reserved.
//

#import "consts.h"
#import "utilities.h"
#import "AddRuleWindowController.h"

/* GLOBALS */

//log handle
extern os_log_t logHandle;

@implementation AddRuleWindowController

@synthesize rule;

//automatically called when nib is loaded
// center window, set some defaults such as icon
-(void)awakeFromNib
{
    //set icon
    self.icon.image = [[NSWorkspace sharedWorkspace] iconForFileType: NSFileTypeForHFSTypeCode(kGenericApplicationIcon)];
    
    //resize
    [self.icon.image setSize:NSMakeSize(128, 128)];
    
    //set delegate for process path text field
    self.path.delegate = self;
    
    //existing rule?
    // prepopulate fields
    if(nil != self.rule)
    {
        //set title
        self.window.title = @"Edit Exiting Rule";
        
        //path
        self.path.stringValue = self.rule.path;
        
        //endpoint addr
        self.endpointAddr.stringValue = (0 != self.rule.endpointAddrDisplay.length) ? self.rule.endpointAddrDisplay : self.rule.endpointAddr;
        
        //regex button
        // note: generated wildcard regex rules show their friendly string with the box unchecked
        if( (EndpointTypeRegex == self.rule.isEndpointAddrRegex) &&
            (EndpointInputKindGlob != self.rule.endpointInputKind.integerValue) )
        {
            //on
            self.isEndpointAddrRegex.state = NSControlStateValueOn;
        }
        
        //endpoint port
        self.endpointPort.stringValue = self.rule.endpointPort;
        
        //block?
        if(RULE_STATE_BLOCK == self.rule.action.intValue)
        {
            //set
            self.blockButton.state = NSControlStateValueOn;
        }
        //allow?
        else
        {
            //set
            self.allowButton.state = NSControlStateValueOn;
        }
        
        //configure 'add' button
        self.addButton.title = NSLocalizedString(@"Update", @"Update");
        
        //enable 'add' button
        self.addButton.enabled = YES;
        
        //make add/edit button first responder
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (100 * NSEC_PER_MSEC)), dispatch_get_main_queue(), ^{
            
            //set first responder
            [self.window makeFirstResponder:self.addButton];
            
        });

    }
    
    //no rule
    // just init some defaults
    else
    {
        //'add' button should be disabled
        // ...until user enters an app/binary
        self.addButton.enabled = NO;
    }

    return;
}

//automatically called when editing start
// update UI by resetting icon and disabling 'add' button
-(void)controlTextDidBeginEditing:(NSNotification *)obj
{
    //reset icon
    self.icon.image = [[NSWorkspace sharedWorkspace]
                       iconForFileType: NSFileTypeForHFSTypeCode(kGenericApplicationIcon)];
    
    //resize
    [self.icon.image setSize:NSMakeSize(128, 128)];
    
    //disable 'add' button
    self.addButton.enabled = NO;
    
    return;
}

//automatically called when text changes
// invoke helper to set icon, and enable/select 'add' button
-(void)controlTextDidChange:(NSNotification *)notification
{
    //ignore everything but process path
    if([notification object] != self.path)
    {
        //bail
        goto bail;
    }
    
    //update
    [self updateUI];
    
bail:
    
    return;
}

//automatically called when 'enter' is hit
// invoke helper to set icon, and enable/select 'add' button
-(void)controlTextDidEndEditing:(NSNotification *)notification
{
    //ignore everything but process path
    if([notification object] != self.path)
    {
        //bail
        goto bail;
    }
    
    //update
    [self updateUI];
    
    //make 'add' selected
    [self.window makeFirstResponder:self.addButton];
    
bail:
    
    return;
}

//'block'/'allow' button handler
// just needed so buttons will toggle
-(IBAction)radioButtonsHandler:(id)sender
{
    return;
}

//'browse' button handler
//  open a panel for user to select file
-(IBAction)browseButtonHandler:(id)sender
{
    //'browse' panel
    NSOpenPanel *panel = nil;
    
    //response to 'browse' panel
    NSInteger response = 0;
    
    //init panel
    panel = [NSOpenPanel openPanel];
    
    //allow files
    panel.canChooseFiles = YES;
    
    //allow directories (app bundles)
    panel.canChooseDirectories = YES;
    
    //can open app bundles
    panel.treatsFilePackagesAsDirectories = YES;
    
    //start in /Apps
    panel.directoryURL = [NSURL fileURLWithPath:@"/Applications"];
    
    //disable multiple selections
    panel.allowsMultipleSelection = NO;
    
    //show it
    response = [panel runModal];
    
    //ignore cancel
    if(NSModalResponseCancel == response)
    {
        //bail
        goto bail;
    }
    
    //set text
    self.path.stringValue = panel.URL.path;
    
    //update UI
    [self updateUI];
    
    //make 'add' selected
    [self.window makeFirstResponder:self.addButton];

bail:
    
    return;
}

//'cancel' button handler
// close sheet, returning NSModalResponseCancel
-(IBAction)cancelButtonHandler:(id)sender
{
    //dbg msg
    os_log_debug(logHandle, "user clicked: %{public}@", ((NSButton*)sender).title);
    
    //stop/cancel
    [NSApp stopModalWithCode:NSModalResponseCancel];
    
    //close
    [self.window close];
    
    return;
}

//convert a simple glob (using '*' wildcards) to an anchored regular expression
// e.g. '85.140.*.*' -> '^85\.140\..*\..*$' : literal chars are regex-escaped, '*' -> '.*', anchored
-(NSString*)regexFromGlob:(NSString*)glob
{
    //split on '*'
    NSArray<NSString*>* parts = [glob componentsSeparatedByString:@"*"];

    //regex-escape each literal piece (handles '.', etc.)
    NSMutableArray<NSString*>* escaped = [NSMutableArray array];
    for(NSString* part in parts)
    {
        [escaped addObject:[NSRegularExpression escapedPatternForString:part]];
    }

    //join escaped pieces with '.*' and anchor (^...$) for a full match
    return [NSString stringWithFormat:@"^%@$", [escaped componentsJoinedByString:@".*"]];
}

//'add' button handler
// close sheet, returning NSModalResponseOK
-(IBAction)addButtonHandler:(id)sender
{
    //response
    NSModalResponse response = NSModalResponseAbort;
    
    //path
    NSMutableString* path = nil;
    
    //flag
    BOOL exists = NO;
    
    //flag
    BOOL isDirectory = NO;
    
    //(remote) endpoint addr
    NSString* endpointAddr = nil;
    
    //(remote) endpoint addr, as entered/displayed
    NSString* endpointAddrDisplay = nil;
    
    //(remote) endpoint technical matcher
    NSString* endpointAddrMatcher = nil;
    
    //endpoint input kind
    NSNumber* endpointInputKind = nil;
    
    //normalized endpoint input
    NSString* endpointInputNormalized = nil;
    
    //endpoint addr match type {exact, regex, cidr}
    NSNumber* endpointAddrRegex = nil;
    
    //(remote) endpoint addr
    NSString* endpointPort = nil;
    
    //action
    NSNumber* action = nil;
    
    //error
    NSError* error = nil;

    //dbg msg
    os_log_debug(logHandle, "user clicked: %{public}@", ((NSButton*)sender).title);

    //init path
    // and check
    path = [self.path.stringValue mutableCopy];
    if(0 == path.length)
    {
        //bail
        goto bail;
    }
    
    //set flags
    // exists/is directory
    exists = [NSFileManager.defaultManager fileExistsAtPath:path isDirectory:&isDirectory];

    //if its a directory (but not bundle)
    // add '/*' to make it directory rule
    if( (YES == isDirectory) &&
        (nil == [NSBundle bundleWithPath:path]))
    {
        //no '/'?
        // ...append it
        if(YES != [path hasSuffix:@"/"])
        {
            //append
            [path appendString:@"/"];
        }
        
        //add '*' to make it a directory rule
        [path appendString:VALUE_ANY];
    }
    
    //invalid path?
    if( (YES != exists) ||
        (0 == path.length) )
    {
        //error
        // though only if its not '*' or '/*'
        if(YES != [path hasSuffix:VALUE_ANY])
        {
            //show alert
            showAlert(NSAlertStyleWarning, NSLocalizedString(@"ERROR: invalid path", @"ERROR: invalid path"), [NSString stringWithFormat:NSLocalizedString(@"%@ does not exist!", @"%@ does not exist!"), path], @[NSLocalizedString(@"OK", @"OK")]);
        
            //bail
            goto bail;
        }
    }
    
    //endpoint addr
    // or '*' if blank
    endpointAddrDisplay = (0 != self.endpointAddr.stringValue.length) ? self.endpointAddr.stringValue : VALUE_ANY;
    endpointAddr = endpointAddrDisplay;
    endpointAddrMatcher = NSLocalizedString(@"Exact", @"Exact");
    endpointInputKind = @(EndpointInputKindExact);
    endpointInputNormalized = endpointAddrDisplay;
    
    //determine endpoint addr match type {exact, regex, cidr}
    EndpointType endpointType = EndpointTypeExact;

    //explicit regex?
    // validate that it compiles
    if(NSControlStateValueOn == self.isEndpointAddrRegex.state)
    {
        //regex
        endpointType = EndpointTypeRegex;
        endpointAddrMatcher = [NSString stringWithFormat:NSLocalizedString(@"Regex: %@", @"Regex: %@"), endpointAddr];
        endpointInputKind = @(EndpointInputKindRegex);

        //validate
        if(nil == [NSRegularExpression regularExpressionWithPattern:endpointAddr options:0 error:&error])
        {
            //show alert
            showAlert(NSAlertStyleWarning, NSLocalizedString(@"ERROR: invalid regex", @"ERROR: invalid regex"), [NSString stringWithFormat:NSLocalizedString(@"%@ is not a valid regular expression\r\ndetails: %@", @"%@ is not a valid regular expression\r\ndetails: %@"), endpointAddr, error.localizedDescription], @[NSLocalizedString(@"OK", @"OK")]);

            //bail
            goto bail;
        }
    }
    //not an explicit regex, but the lone '*' (VALUE_ANY) is left untouched ('any endpoint')
    else if(YES != [endpointAddr isEqualToString:VALUE_ANY])
    {
        //contains a glob ('*')?
        // convert to an anchored regex & send as a regex rule
        if(NSNotFound != [endpointAddr rangeOfString:@"*"].location)
        {
            //dbg msg
            os_log_debug(logHandle, "endpoint address '%{public}@' contains a glob ('*'), converting to regex", endpointAddr);

            //convert glob -> anchored regex
            endpointAddr = [self regexFromGlob:endpointAddr];
            endpointAddrMatcher = [NSString stringWithFormat:NSLocalizedString(@"Generated regex: %@", @"Generated regex: %@"), endpointAddr];
            endpointInputKind = @(EndpointInputKindGlob);

            //regex
            endpointType = EndpointTypeRegex;

            //dbg msg
            os_log_debug(logHandle, "converted glob to regex: %{public}@", endpointAddr);
        }
        //a CIDR ('a.b.c.d/n') or IP range ('ipA - ipB')?
        // matched numerically (IPv4 & IPv6) by the extension
        else if(YES == isAddressRange(endpointAddr))
        {
            //dbg msg
            os_log_debug(logHandle, "endpoint address '%{public}@' is a CIDR/range", endpointAddr);

            //cidr
            endpointType = EndpointTypeCIDR;
            
            //matcher metadata
            if(NSNotFound != [endpointAddr rangeOfString:@"/"].location)
            {
                endpointAddrMatcher = NSLocalizedString(@"CIDR", @"CIDR");
                endpointInputKind = @(EndpointInputKindCIDR);
            }
            else
            {
                endpointAddrMatcher = NSLocalizedString(@"IP range", @"IP range");
                endpointInputKind = @(EndpointInputKindRange);
            }
        }
        //looks like a CIDR ('/') but didn't parse?
        // reject (rather than silently storing a dead exact-match rule)
        else if(NSNotFound != [endpointAddr rangeOfString:@"/"].location)
        {
            //show alert
            showAlert(NSAlertStyleWarning, NSLocalizedString(@"ERROR: invalid CIDR", @"ERROR: invalid CIDR"), [NSString stringWithFormat:NSLocalizedString(@"%@ is not a valid CIDR (e.g. 192.168.1.0/24)", @"%@ is not a valid CIDR (e.g. 192.168.1.0/24)"), endpointAddr], @[NSLocalizedString(@"OK", @"OK")]);

            //bail
            goto bail;
        }
        //looks like an IP range, but didn't parse?
        // reject obvious range input rather than storing a dead exact-match rule
        else if(YES == looksLikeIPAddressRange(endpointAddr))
        {
            //show alert
            showAlert(NSAlertStyleWarning, NSLocalizedString(@"ERROR: invalid IP range", @"ERROR: invalid IP range"), [NSString stringWithFormat:NSLocalizedString(@"%@ is not a valid IP range (e.g. 1.2.3.4 - 23.3.4.6)", @"%@ is not a valid IP range (e.g. 1.2.3.4 - 23.3.4.6)"), endpointAddr], @[NSLocalizedString(@"OK", @"OK")]);

            //bail
            goto bail;
        }
    }

    //save match type
    endpointAddrRegex = @(endpointType);

    //endpoint port
    // ...set var, but also validate
    endpointPort = (0 != self.endpointPort.stringValue.length) ? self.endpointPort.stringValue : VALUE_ANY;
    if( (0 != self.endpointPort.stringValue.length) &&
        (YES != [self.endpointPort.stringValue isEqualToString:VALUE_ANY]) &&
        (NSNotFound != [endpointPort rangeOfCharacterFromSet:[[NSCharacterSet decimalDigitCharacterSet] invertedSet]].location) )
    {
        //show alert
        showAlert(NSAlertStyleWarning, NSLocalizedString(@"ERROR: invalid port", @"ERROR: invalid port"), [NSString stringWithFormat:NSLocalizedString(@"%@ is not a valid (port) number", @"%@ is not a valid (port) number"), endpointPort], @[NSLocalizedString(@"OK", @"OK")]);
        
        //bail
        goto bail;
    }

    //set action
    action = (self.blockButton.state == NSControlStateValueOn) ? @RULE_STATE_BLOCK : @RULE_STATE_ALLOW;
    
    //save all info
    self.info = @{KEY_PATH:path,
                  KEY_ENDPOINT_ADDR:endpointAddr,
                  KEY_ENDPOINT_ADDR_IS_REGEX:endpointAddrRegex,
                  KEY_ENDPOINT_ADDR_DISPLAY:endpointAddrDisplay,
                  KEY_ENDPOINT_ADDR_MATCHER:endpointAddrMatcher,
                  KEY_ENDPOINT_INPUT_KIND:endpointInputKind,
                  KEY_ENDPOINT_INPUT_NORMALIZED:endpointInputNormalized,
                  KEY_ENDPOINT_PORT:endpointPort,
                  KEY_TYPE:@RULE_TYPE_USER,
                  KEY_ACTION:action};
    
    //ok happy
    response = NSModalResponseOK;

bail:
    
    //stop w/ response
    [NSApp stopModalWithCode:response];
    
    //close
    [self.window close];
    
    return;
}

//update the UI
// set icon, and enable/select 'add' button
-(void)updateUI
{
    //icon
    NSImage* processIcon = nil;
    
    //blank
    // disable 'add' button
    if(0 == self.path.stringValue.length)
    {
        //set state
        self.addButton.enabled = NO;
        
        //bail
        goto bail;
    }
    
    //get icon
    processIcon = getIconForProcess(self.path.stringValue);
    if(nil != processIcon)
    {
        //add
        self.icon.image = processIcon;
    }
    
    //enable 'add' button
    self.addButton.enabled = YES;
    
bail:
    
    return;
}

//ensure title-bar close also ends the modal
- (BOOL)windowShouldClose:(NSWindow *)sender {
    [NSApp stopModalWithCode:NSModalResponseCancel];
    return YES;
}

@end
