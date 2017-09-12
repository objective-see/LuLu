//
//  file: VirusTotalViewController.h
//  project: lulu (login item)
//  description: view controller for VirusTotal results popup (header)
//
//  created by Patrick Wardle
//  copyright (c) 2017 Objective-See. All rights reserved.
//


#import "Logging.h"
#import "Utilities.h"
#import "VirusTotal.h"
#import "HyperlinkTextField.h"
#import "VirusTotalViewController.h"

@implementation VirusTotalViewController

@synthesize message;
@synthesize vtSpinner;

//automatically invoked
// ->configure popover and kick off VT queries
-(void)popoverWillShow:(NSNotification *)notification;
{
    //set message
    self.message.stringValue = @"querying virus total...";
    
    //show spinner
    self.vtSpinner.hidden = NO;
    
    //start spinner
    [self.vtSpinner startAnimation:nil];
    
    //bg thread for VT
    [self performSelectorInBackground:@selector(queryVT) withObject:nil];
    
    return;
}

//make a query to VT in the background
// invokes helper function to update UI as needed (results/errors)
-(void)queryVT
{
    //vt object
    VirusTotal* vtObj = nil;
    
    //hash
    NSString* hash = nil;
    
    //item
    NSMutableDictionary* item = nil;
    
    //alloc
    vtObj = [[VirusTotal alloc] init];
    
    //alloc
    item = [NSMutableDictionary dictionary];
    
    //nap to allow msg/spinner to do a bit
    [NSThread sleepForTimeInterval:1.0f];
    
    //hash
    hash = hashFile(self.itemPath);
    if(0 == hash.length)
    {
        //err msg
        logMsg(LOG_ERR, [NSString stringWithFormat:@"failed to hash %@ to submit", self.itemName]);
        
        //show error on main thread
        dispatch_sync(dispatch_get_main_queue(), ^{
            
            //show error
            [self showError];
            
        });
        
        //bail
        goto bail;
    }
    
    //dbg msg
    #ifdef DEBUG
    logMsg(LOG_DEBUG, [NSString stringWithFormat:@"querying VT with %@", self.itemPath]);
    #endif
    
    //add name
    item[@"name"] = self.itemName;
    
    //add path
    item[@"path"] = self.itemPath;
    
    //add hash
    item[@"hash"] = hash;
    
    //query VT
    // ->also check for error (offline, etc)
    if(YES == [vtObj queryVT:item])
    {
        //update UI on main thread
        dispatch_sync(dispatch_get_main_queue(), ^{
            
            //update UI
            [self displayResults:item];
            
        });
    }
    
    //error
    else
    {
        //err msg
        logMsg(LOG_ERR, [NSString stringWithFormat:@"failed to query virus total: %@", item]);
        
        //show error on main thread
        dispatch_sync(dispatch_get_main_queue(), ^{
            
            //show error
            [self showError];
            
        });
    }

bail:
    
    return;
}

//display results
-(void)displayResults:(NSMutableDictionary*)item
{
    //dbg msg
    #ifdef DEBUG
    logMsg(LOG_DEBUG, [NSString stringWithFormat:@"VT response: %@", item]);
    #endif
    
    //stop spinner
    [self.vtSpinner stopAnimation:nil];
    
    //hide spinner
    self.vtSpinner.hidden = YES;
    
    
    [self.message setAllowsEditingTextAttributes: YES];
    [self.message setSelectable: YES];
    
    //format/set info
    self.message.attributedStringValue = [self formatVTInfo:item];
    
    return;
}

//show error in UI
-(void)showError
{
    //stop spinner
    [self.vtSpinner stopAnimation:nil];
    
    //hide spinner
    self.vtSpinner.hidden = YES;
    
    //set message
    self.message.stringValue = @"failed to query virus total :(";
    
    return;
}

//build string with process/binary name + signing info
-(NSAttributedString*)formatVTInfo:(NSDictionary*)item
{
    //info
    NSMutableAttributedString* info = nil;
    
    //string attributes
    NSDictionary* attributes = nil;
    
    //name
    // ->handles truncations, etc
    NSString* name = nil;
    
    //init string
    info = [[NSMutableAttributedString alloc] initWithString:@""];
    
    //init string attributes
    attributes = @{NSFontAttributeName: [NSFont fontWithName:@"Menlo-Bold" size:13]};

    //grab name
    name = item[@"name"];
    
    //truncate long names
    if(name.length > 25)
    {
        //truncate
        name = [[name substringToIndex:22] stringByAppendingString:@"..."];
    }
    
    //add name
    [info appendAttributedString:[[NSMutableAttributedString alloc] initWithString:[NSString stringWithFormat:@"%@: ", name] attributes:attributes]];
    
    //un-set bold attributes
    attributes = @{NSFontAttributeName: [NSFont fontWithName:@"Menlo" size:13]};
    
    //sanity check
    if( (nil == item[@"vtInfo"]) ||
        (nil == item[@"vtInfo"][@"found"]) )
    {
        //set
        [info appendAttributedString:[[NSMutableAttributedString alloc] initWithString:@"received invalid response"]];
        
        //bail
        goto bail;
    }

    //add ratio and report link if file is found
    if(0 != [item[@"vtInfo"][@"found"] intValue])
    {
        //sanity check
        if( (nil == item[@"vtInfo"][@"detection_ratio"]) ||
            (nil == item[@"vtInfo"][@"permalink"]) )
        {
            //set
            [info appendAttributedString:[[NSMutableAttributedString alloc] initWithString:@"received invalid response"]];
            
            //bail
            goto bail;
        }
        
        //make ratio red if there are positives
        if( (nil != item[@"vtInfo"][@"positives"]) &&
            (0 != [item[@"vtInfo"][@"positives"] intValue]) )
        {
            //red
            attributes = @{NSFontAttributeName: [NSFont fontWithName:@"Menlo" size:13], NSForegroundColorAttributeName:[NSColor redColor]};
        }
        
        //add ratio
        [info appendAttributedString:[[NSMutableAttributedString alloc] initWithString:[NSString stringWithFormat:@"%@ ", item[@"vtInfo"][@"detection_ratio"]] attributes:attributes]];
        
        //set attributes to for html link for report
        attributes = @{NSFontAttributeName: [NSFont fontWithName:@"Menlo" size:13], NSLinkAttributeName:[NSURL URLWithString:item[@"vtInfo"][@"permalink"]], NSForegroundColorAttributeName:[NSColor blueColor], NSUnderlineStyleAttributeName:[NSNumber numberWithInt:NSUnderlineStyleSingle]};
        
        //add link to full report
        [info appendAttributedString:[[NSMutableAttributedString alloc] initWithString:@"details" attributes:attributes]];

    }
    //file not found on vt
    else
    {
        //add ratio
        [info appendAttributedString:[[NSMutableAttributedString alloc] initWithString:@"not found" attributes:attributes]];
    }
    
bail:
    
    return info;
}

@end
