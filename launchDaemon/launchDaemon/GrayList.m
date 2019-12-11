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
    @"com.apple.ftp",
    @"com.apple.ksh",
    @"com.apple.php",
    @"com.apple.scp",
    @"com.apple.curl",
    @"com.apple.perl",
    @"com.apple.ruby",
    @"com.apple.sftp",
    @"com.tcltk.tclsh"
    @"com.apple.perl5",
    @"com.apple.whois",
    @"com.apple.python",
    @"com.apple.telnet",
    @"com.apple.openssh",
    @"com.apple.python2",
    @"org.python.python",
    @"com.apple.pythonw",
    @"com.apple.osascript",
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
    
    //dbg info
    logMsg(LOG_DEBUG, [NSString stringWithFormat:@"checking if %@ is graylisted (signing info: %@)", process.path, process.signingInfo]);
    
    //has to be apple
    if(Apple != [process.signingInfo[KEY_SIGNATURE_SIGNER] intValue])
    {
        //bail
        goto bail;
    }
    
    //no code signing identifier?
    if(nil == process.signingInfo[KEY_SIGNATURE_IDENTIFIER])
    {
        //bail
        goto bail;
    }
    
    //not in list?
    if(YES != [self.graylistedBinaries containsObject:process.signingInfo[KEY_SIGNATURE_IDENTIFIER]])
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
