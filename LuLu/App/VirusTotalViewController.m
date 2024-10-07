//
//  file: VirusTotalViewController.h
//  project: lulu (login item)
//  description: view controller for VirusTotal results popup (header)
//
//  created by Patrick Wardle
//  copyright (c) 2017 Objective-See. All rights reserved.
//

#import "utilities.h"
#import "VirusTotal.h"
#import "VirusTotalViewController.h"

/* GLOBALS */

//log handle
extern os_log_t logHandle;

@implementation VirusTotalViewController

@synthesize message;
@synthesize vtSpinner;

//automatically invoked
// configure popover and kick off VT queries
-(void)popoverWillShow:(NSNotification *)notification;
{
    //set message
    self.message.string = NSLocalizedString(@"Querying VirusTotal...", @"Querying VirusTotal...");
    
    //bg thread for VT
    [self performSelectorInBackground:@selector(queryVT) withObject:nil];
    
    return;
}

//automatically invoked
// finish configuring popover
-(void)popoverDidShow:(NSNotification *)notification
{
    //show spinner
    self.vtSpinner.hidden = NO;
    
    //start
    [self.vtSpinner startAnimation:nil];
    
    //make the animation show...
    [[NSRunLoop mainRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.01]];
    
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
    
    //path
    // for apps, this is app's binary
    NSString* path = nil;
    
    //alloc
    vtObj = [[VirusTotal alloc] init];
    
    //alloc
    item = [NSMutableDictionary dictionary];
    
    //nap to allow msg/spinner to do a bit
    [NSThread sleepForTimeInterval:0.5f];
    
    //dbg msg
    os_log_debug(logHandle, "querying Virus Total with %{public}@", self.itemPath);
    
    //when it's an app
    // get path to app's binary
    if(YES == [self.itemPath hasSuffix:@".app"])
    {
        //get path
        path = getBundleExecutable(self.itemPath);
        
        //dbg msg
        os_log_debug(logHandle, "resolved app's binary: %{public}@", path);
    }
    
    //not app / no app binary?
    // just use item's path for file
    if(0 == path.length)
    {
        //init path
        path = self.itemPath;
    }
        
    //hash
    hash = hashFile(path);
    if(0 == hash.length)
    {
        //err msg
        os_log_error(logHandle, "ERROR: failed to hash %{public}@, for VT submission", path);
        
        //show error on main thread
        dispatch_sync(dispatch_get_main_queue(), ^{
            
            //show error
            [self showError];
            
        });
        
        //bail
        goto bail;
    }
    
    //dbg msg
    os_log_debug(logHandle, "querying Virus Total with %{public}@", self.itemPath);
    
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
        //modal window, so use 'performSelectorOnMainThread' to update
        [self performSelectorOnMainThread:@selector(displayResults:) withObject:item waitUntilDone:YES];
    }
    
    //error
    else
    {
        //err msg
        os_log_error(logHandle, "ERROR: failed to query virus total: %@", item);
        
        //modal window, so use 'performSelectorOnMainThread' to update
        [self performSelectorOnMainThread:@selector(showError) withObject:nil waitUntilDone:YES];
    }

bail:
    
    return;
}

//display results
-(void)displayResults:(NSMutableDictionary*)item
{
    //dbg msg
    os_log_debug(logHandle, "Virus Total response: %{public}@", item);
    
    //stop spinner
    [self.vtSpinner stopAnimation:nil];
    
    //hide spinner
    self.vtSpinner.hidden = YES;
    
    //format/set info
    [self.message.textStorage setAttributedString:[self formatVTInfo:item]];
    
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
    self.message.string = NSLocalizedString(@"Failed to query VirusTotal", @"Failed to query VirusTotal");
    
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
    // handles truncations, etc
    NSString* name = nil;
    
    //init string
    info = [[NSMutableAttributedString alloc] initWithString:@""];
    
    //init string attributes
    attributes = @{
        NSForegroundColorAttributeName: [NSColor controlTextColor],
        NSFontAttributeName: [NSFont fontWithName:@"Menlo-Bold" size:12]
    };

    //grab name
    name = item[@"name"];
    
    //truncate long names
    if(name.length > 25)
    {
        //truncate
        name = [[name substringToIndex:22] stringByAppendingString:@"..."];
    }
    
    //add name
    [info appendAttributedString:[[NSMutableAttributedString alloc] initWithString:[NSString stringWithFormat:@"%@", name] attributes:attributes]];
    
    //un-set bold attributes
    attributes = @{
        NSForegroundColorAttributeName: [NSColor controlTextColor],
        NSFontAttributeName: [NSFont fontWithName:@"Menlo" size:12]
    };
    
    //sanity check
    if( (nil == item[@"vtInfo"]) ||
        (nil == item[@"vtInfo"][@"found"]) )
    {
        //set
        [info appendAttributedString:[[NSMutableAttributedString alloc] initWithString:NSLocalizedString(@"\r\nReceived invalid response", @"\r\nReceived invalid response") attributes:attributes]];
        
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
            [info appendAttributedString:[[NSMutableAttributedString alloc] initWithString:NSLocalizedString(@"\r\nReceived invalid response", @"\r\nReceived invalid response") attributes:attributes]];
            
            //bail
            goto bail;
        }
        
        //add newline/ratio
        [info appendAttributedString:[[NSMutableAttributedString alloc] initWithString:NSLocalizedString(@"\r\nDetection Ratio: ", @"\r\nDetection Ratio: ") attributes:attributes]];
        
        //make ratio red if there are positives
        if( (nil != item[@"vtInfo"][@"positives"]) &&
            (0 != [item[@"vtInfo"][@"positives"] intValue]) )
        {
            //red
            attributes = @{NSFontAttributeName: [NSFont fontWithName:@"Menlo" size:12], NSForegroundColorAttributeName:[NSColor systemRedColor]};
        }
        
        //add ratio
        [info appendAttributedString:[[NSMutableAttributedString alloc] initWithString:[NSString stringWithFormat:@"%@ ", item[@"vtInfo"][@"detection_ratio"]] attributes:attributes]];
        
        //reset attributes
        attributes = @{
            NSForegroundColorAttributeName: [NSColor controlTextColor],
            NSFontAttributeName: [NSFont fontWithName:@"Menlo" size:12]
        };
        
        //add newline/view
        [info appendAttributedString:[[NSMutableAttributedString alloc] initWithString:NSLocalizedString(@"\r\nView VirusTotal's ", @"\r\nView VirusTotal's ") attributes:attributes]];
        
        //set attributes to for html link for report
        attributes = @{NSFontAttributeName: [NSFont fontWithName:@"Menlo" size:12], NSLinkAttributeName:[NSURL URLWithString:item[@"vtInfo"][@"permalink"]], NSForegroundColorAttributeName:[NSColor linkColor], NSUnderlineStyleAttributeName:[NSNumber numberWithInt:NSUnderlineStyleSingle]};
        
        //add link to full report
        [info appendAttributedString:[[NSMutableAttributedString alloc] initWithString:NSLocalizedString(@"findings", @"findings") attributes:attributes]];
    }
    //file not found on VT
    else
    {
        //not found
        [info appendAttributedString:[[NSMutableAttributedString alloc] initWithString:NSLocalizedString(@"\r\nnot found on VirusTotal", @"\r\nnot found on VirusTotal") attributes:attributes]];
    }
    
bail:
    
    return info;
}

@end
