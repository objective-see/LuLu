//
//  file: GrayList.m
//  project: lulu (launch daemon)
//  description: gray listed binaries
//
//  created by Patrick Wardle
//  copyright (c) 2017 Objective-See. All rights reserved.
//

#import "consts.h"
#import "Process.h"
#import "GrayList.h"

//apple system utils that aren't allowed by default
// these may be abused by malware, so will make sure they trigger an alert
NSString* const GRAYLISTED_BINARIES[] =
{
    @"com.apple.nc",
    @"com.apple.ftp",
    @"com.apple.zsh",
    @"com.apple.ksh",
    @"com.apple.php",
    @"com.apple.scp",
    @"com.apple.ssh",
    @"com.apple.bash",
    @"com.apple.tcsh",
    @"com.apple.curl",
    @"com.apple.perl",
    @"com.apple.ruby",
    @"com.apple.sftp",
    @"com.tcltk.tclsh",
    @"com.apple.perl5",
    @"com.apple.whois",
    @"com.apple.python",
    @"com.apple.telnet",
    @"com.apple.openssh",
    @"com.apple.python2",
    @"com.apple.python3",
    @"org.python.python",
    @"com.apple.pythonw",
    @"com.apple.osascript",
    
};

/* GLOBALS */

//log handle
extern os_log_t logHandle;

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
        os_log_debug(logHandle, "loaded 'gray-listed' binaries: %{public}@", self.graylistedBinaries);
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
    os_log_debug(logHandle, "checking if %{public}@ is graylisted (signing info: %{public}@)", process.path, process.csInfo);
    
    //no code signing identifier?
    if(nil == process.csInfo[KEY_CS_ID]) goto bail;
    
    //has to be apple
    if(Apple != [process.csInfo[KEY_CS_SIGNER] intValue]) goto bail;

    //not in list?
    if(YES != [self.graylistedBinaries containsObject:process.csInfo[KEY_CS_ID]])
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
