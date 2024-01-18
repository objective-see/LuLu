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
        //path
        self.path.stringValue = self.rule.path;
        
        //endpoint addr
        self.endpointAddr.stringValue = self.rule.endpointAddr;
        
        //regex button
        if(YES == self.rule.isEndpointAddrRegex)
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
        self.addButton.title = @"Update";
        
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
    //dbg msg
    os_log_debug(logHandle, "radio toggle: %{public}@", sender);
    
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
    
    //close & return NSModalResponseCancel
    [self.window.sheetParent endSheet:self.window returnCode:NSModalResponseCancel];
    
    return;
}

//'add' button handler
// close sheet, returning NSModalResponseOK
-(IBAction)addButtonHandler:(id)sender
{
    //response
    NSModalResponse response = NSModalResponseAbort;
    
    //path
    NSMutableString* path = nil;
    
    //extension
    NSString* extension = nil;
    
    //flag
    BOOL exists = NO;
    
    //flag
    BOOL isDirectory = NO;
    
    //(remote) endpoint addr
    NSString* endpointAddr = nil;
    
    //flag
    NSNumber* endpointAddrRegex = nil;
    
    //(remote) endpoint addr
    NSString* endpointPort = nil;
    
    //type
    NSNumber* type = nil;
    
    //action
    NSNumber* action = nil;
    
    //error
    NSError* error = nil;
    
    //bundles
    NSArray* bundles = @[@"app", @"bundle", @"xpc"];
    
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
    
    //get extension
    extension = path.pathExtension;
    
    //if its a directory (but not bundle)
    // add '/*' to make it directory rule
    if( (YES == isDirectory) &&
        (YES != [bundles containsObject:extension]) )
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
            showAlert(@"ERROR: invalid path", [NSString stringWithFormat:@"%@ does not exist!", path]);
        
            //bail
            goto bail;
        }
    }
    
    //endpoint addr
    // or '*' if blank
    endpointAddr = (0 != self.endpointAddr.stringValue.length) ? self.endpointAddr.stringValue : VALUE_ANY;
    
    //is endpoint addr regex?
    // ...set var, but also validate
    endpointAddrRegex = [NSNumber numberWithBool:(self.isEndpointAddrRegex.state == NSControlStateValueOn)];
    if( (YES == endpointAddrRegex.boolValue) &&
        (nil == [NSRegularExpression regularExpressionWithPattern:endpointAddr options:0 error:&error]) )
    {
        //show alert
        showAlert(@"ERROR: invalid regex", [NSString stringWithFormat:@"%@ is not a valid regular expression\r\ndetails: %@", endpointAddr, error.localizedDescription]);
        
        //bail
        goto bail;
    }

    //endpoint port
    // ...set var, but also validate
    endpointPort = (0 != self.endpointPort.stringValue.length) ? self.endpointPort.stringValue : VALUE_ANY;
    if( (0 != self.endpointPort.stringValue.length) &&
        (YES != [self.endpointPort.stringValue isEqualToString:VALUE_ANY]) &&
        (NSNotFound != [endpointPort rangeOfCharacterFromSet:[[NSCharacterSet decimalDigitCharacterSet] invertedSet]].location) )
    {
        //show alert
        showAlert(@"ERROR: invalid port", [NSString stringWithFormat:@"%@ is not a valid (port) number", endpointPort]);
        
        //bail
        goto bail;
    }

    //init type
    // existing rule? use that type, otherwise default to 'user'
    type = (nil != self.rule) ? self.rule.type : @RULE_TYPE_USER;
    
    //set action
    action = (self.blockButton.state == NSControlStateValueOn) ? @RULE_STATE_BLOCK : @RULE_STATE_ALLOW;
    
    //save all info
    self.info = @{KEY_PATH:path,
                  KEY_ENDPOINT_ADDR:endpointAddr,
                  KEY_ENDPOINT_ADDR_IS_REGEX:endpointAddrRegex,
                  KEY_ENDPOINT_PORT:endpointPort,
                  KEY_TYPE:type,
                  KEY_ACTION:action};
    
    //ok happy
    response = NSModalResponseOK;

    //close & return
    [self.window.sheetParent endSheet:self.window returnCode:response];
    
bail:
    
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

@end
