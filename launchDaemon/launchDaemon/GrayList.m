//
//  file: GrayList.m
//  project: lulu (launch daemon)
//  description: gray listed binaries
//
//  created by Patrick Wardle
//  copyright (c) 2017 Objective-See. All rights reserved.
//

#import "consts.h"
#import "logging.h"
#import "procInfo.h"
#import "GrayList.h"

//apple system utils that aren't allowed by default
// these may be abused by malware, so will make sure they trigger an alert
NSString* const GRAYLISTED_BINARIES[] =
{
    @"com.apple.nc",
    @"com.apple.curl",
    @"com.apple.ruby",
    @"com.apple.perl",
    @"com.apple.python",
    @"com.apple.osascript"
};

@implementation GrayList

@synthesize graylistedBinaries;

//init
-(id)init
{
    //init super
    self = [super init];
    if(nil != self)
    {
        //init list (set) of gray listed binaries
        graylistedBinaries = [NSMutableSet set];

        //add each to set
        for(NSUInteger i=0; i<sizeof(GRAYLISTED_BINARIES)/sizeof(GRAYLISTED_BINARIES[0]); i++)
        {
            //add
            [self.graylistedBinaries addObject:GRAYLISTED_BINARIES[i]];
        }
        
        //dbg msg
        logMsg(LOG_DEBUG, [NSString stringWithFormat:@"loaded 'gray-listed' binaries: %@", self.graylistedBinaries]);
    }
    
    return self;
}

//determine if process is graylisted
// a) signed by apple
// b) signing identifier matches
-(BOOL)isGrayListed:(Process*)process
{
    //flag
    BOOL grayListed = NO;
    
    //process signing info
    NSDictionary* signingInfo = nil;
    
    //has to be apple
    if(YES != process.binary.isApple)
    {
        //bail
        goto bail;
    }
    
    //extract signing info
    signingInfo = process.binary.signingInfo;
    
    //no signing identifier?
    if(nil == signingInfo[KEY_SIGNATURE_IDENTIFIER])
    {
        //bail
        goto bail;
    }
    
    //not in list?
    if(YES != [self.graylistedBinaries containsObject:signingInfo[KEY_SIGNATURE_IDENTIFIER]])
    {
        //bail
        goto bail;
    }
    
    //item is gray listed
    grayListed = YES;
    
bail:
    
    return grayListed;
}

@end
