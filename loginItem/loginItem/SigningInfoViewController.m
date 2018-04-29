//
//  file: SigningInfoViewController
//  project: lulu (login item)
//  description: view controller for signing info popup (header)
//
//  created by Patrick Wardle
//  copyright (c) 2018 Objective-See. All rights reserved.
//


#import "consts.h"
#import "logging.h"
#import "utilities.h"
#import "SigningInfoViewController.h"

@implementation SigningInfoViewController

@synthesize alert;

//automatically invoked
-(void)popoverWillShow:(NSNotification *)notification;
{
    //signing info
    NSDictionary* signingInfo = nil;
    
    //summary
    NSMutableString* summary = nil;
    
    //signing auth
    NSMutableString* signingAuths = nil;
    
    //alloc string for summary
    summary = [NSMutableString string];

    //alloc string for signing auths
    signingAuths = [NSMutableString string];
    
    //extract signing info
    signingInfo = alert[ALERT_SIGNINGINFO];
    
    //start summary with item name
    [summary appendString:getProcessName(alert[ALERT_PATH])];
    
    //process
    switch([signingInfo[KEY_SIGNATURE_STATUS] integerValue])
    {
        //happily signed
        case noErr:
            
            //append to summary
            [summary appendFormat:@" is validly signed"];
            
            //item signed by apple
            if(YES == [signingInfo[KEY_SIGNING_IS_APPLE] boolValue])
            {
                //set details
                self.details.stringValue = @"signed by Apple proper";
            }
            //item signed, third party/ad hoc, etc
            else
            {
                //from app store?
                if(YES == [signingInfo[KEY_SIGNING_IS_APP_STORE] boolValue])
                {
                    //set details
                    self.details.stringValue = @"signed by Mac App Store";
                }
                //developer id?
                // ->but not from app store
                else if(YES == [signingInfo[KEY_SIGNING_IS_APPLE_DEV_ID] boolValue])
                {
                    //set details
                    self.details.stringValue = @"signed with an Apple Developer ID";
                }
                //something else
                // ad hoc? 3rd-party?
                else
                {
                    //set details
                    self.details.stringValue = @" signed by 3rd-party/ad hoc";
                }
            }
            
            //no signing auths
            // usually (always?) adhoc
            if(0 == [signingInfo[KEY_SIGNING_AUTHORITIES] count])
            {
                //set details
                self.details.stringValue = @"signed, but no signing authorities (adhoc?)";
                
                //set signing auths
                signingAuths = [@"none" mutableCopy];
            }
            
            //add each signing auth
            else
            {
                //add signing auth
                for(NSString* signingAuthority in signingInfo[KEY_SIGNING_AUTHORITIES])
                {
                    //append to details
                    [signingAuths appendString:[NSString stringWithFormat:@"› %@ \n", signingAuthority]];
                }
            }
            
            break;
            
        //unsigned
        case errSecCSUnsigned:
            
            //append to summary
            [summary appendFormat:@" is not signed"];
            
            //set details
            self.details.stringValue = [@"n/a" mutableCopy];
            
            //set signing auths
            signingAuths = [@"n/a" mutableCopy];
            
            break;
            
        //everything else
        // other signing errors
        default:
            
            //append to summary
            [summary appendFormat:@" has a signing issue"];
            
            //set details
            self.details.stringValue = [NSMutableString stringWithFormat:@"signing error: %ld", (long)[signingInfo[KEY_SIGNATURE_STATUS] integerValue]];
            
            //set signing auths
            signingAuths = [@"n/a" mutableCopy];
            
            break;
    }
    
    //assign summary to outlet
    self.message.stringValue = summary;
    
    //set details to outlet
    self.authorities.stringValue = signingAuths;
    
    return;
}

@end
