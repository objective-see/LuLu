//
//  File: Signing.m
//  Project: LuLu
//
//  Created by: Patrick Wardle
//  Copyright:  2017 Objective-See

#import "consts.h"
#import "signing.h"
#import "utilities.h"

@import Security;
@import SystemConfiguration;

/* GLOBALS */

//log handle
extern os_log_t logHandle;

//get the signing info of a item
// audit token: extract dynamic code signing info
// path on disk: generate static code signing info
NSMutableDictionary* extractSigningInfo(audit_token_t* token, NSString* path, SecCSFlags flags)
{
    //info dictionary
    NSMutableDictionary* signingInfo = nil;
    
    //status
    OSStatus status = !errSecSuccess;
    
    //static code ref
    SecStaticCodeRef staticCode = NULL;
    
    //dynamic code ref
    SecCodeRef dynamicCode = NULL;
    
    //signing details
    CFDictionaryRef signingDetails = NULL;
    
    //signing authorities
    NSMutableArray* signingAuths = nil;
    
    //init signing status
    signingInfo = [NSMutableDictionary dictionary];
    
    //dynamic code checks
    // no path, dynamic check via pid
    if(nil == path)
    {
        //obtain dynamic code ref from (audit) token
        status = SecCodeCopyGuestWithAttributes(NULL, (__bridge CFDictionaryRef _Nullable)(@{(__bridge NSString *)kSecGuestAttributeAudit:[NSData dataWithBytes:token length:sizeof(audit_token_t)]}), kSecCSDefaultFlags, &dynamicCode);
        if(errSecSuccess != status)
        {
            //err msg
            os_log_error(logHandle, "ERROR: 'SecCodeCopyGuestWithAttributes' failed with %d/%#x", status, status);
            
            //set error
            signingInfo[KEY_CS_STATUS] = [NSNumber numberWithInt:status];
            
            //bail
            goto bail;
        }
        
        //validate code
        status = SecCodeCheckValidity(dynamicCode, flags, NULL);
        if(errSecSuccess != status)
        {
            //err msg
            os_log_error(logHandle, "ERROR: 'SecCodeCheckValidity' failed with %d/%#x", status, status);
            
            //set error
            signingInfo[KEY_CS_STATUS] = [NSNumber numberWithInt:status];
            
            //bail
            goto bail;
        }
        
        //happily signed
        signingInfo[KEY_CS_STATUS] = [NSNumber numberWithInt:errSecSuccess];
        
        //determine signer
        // apple, app store, dev id, adhoc, etc...
        signingInfo[KEY_CS_SIGNER] = extractSigner(dynamicCode, flags, YES);
        
        //extract signing info
        status = SecCodeCopySigningInformation(dynamicCode, kSecCSSigningInformation, &signingDetails);
        if(errSecSuccess != status)
        {
            //err msg
            os_log_error(logHandle, "ERROR: 'SecCodeCopySigningInformation' failed with %d/%#x", status, status);
            
            //set error
            signingInfo[KEY_CS_STATUS] = [NSNumber numberWithInt:status];
            
            //bail
            goto bail;
        }
    }
    
    //static code checks
    else
    {
        //create static code ref via path
        status = SecStaticCodeCreateWithPath((__bridge CFURLRef)([NSURL fileURLWithPath:path]), kSecCSDefaultFlags, &staticCode);
        if(errSecSuccess != status)
        {
            //err msg
            os_log_error(logHandle, "ERROR: 'SecStaticCodeCreateWithPath' failed with %d/%#x", status, status);
            
            //set error
            signingInfo[KEY_CS_STATUS] = [NSNumber numberWithInt:status];
            
            //bail
            goto bail;
        }
        
        //check signature
        status = SecStaticCodeCheckValidity(staticCode, flags, NULL);
        if(errSecSuccess != status)
        {
            //err msg
            os_log_error(logHandle, "'SecStaticCodeCheckValidity' failed with %d/%#x", status, status);
            
            //set error
            signingInfo[KEY_CS_STATUS] = [NSNumber numberWithInt:status];
            
            //bail
            goto bail;
        }
        
        //happily signed
        signingInfo[KEY_CS_STATUS] = [NSNumber numberWithInt:errSecSuccess];
        
        //determine signer
        // apple, app store, dev id, adhoc, etc...
        signingInfo[KEY_CS_SIGNER] = extractSigner(staticCode, flags, NO);
        
        //extract signing info
        status = SecCodeCopySigningInformation(staticCode, kSecCSSigningInformation, &signingDetails);
        if(errSecSuccess != status)
        {
            //err msg
            os_log_error(logHandle, "'SecCodeCopySigningInformation' failed with %d/%#x", status, status);
            
            //set error
            signingInfo[KEY_CS_STATUS] = [NSNumber numberWithInt:status];
            
            //bail
            goto bail;
        }
    }
    
    //extract code signing id
    if(0 != [[(__bridge NSDictionary*)signingDetails objectForKey:(__bridge NSString*)kSecCodeInfoIdentifier] length])
    {
        //extract/save
        signingInfo[KEY_CS_ID] = [(__bridge NSDictionary*)signingDetails objectForKey:(__bridge NSString*)kSecCodeInfoIdentifier];
    }
    
    //extract signing authorities
    signingAuths = extractSigningAuths((__bridge NSDictionary *)(signingDetails));
    if(0 != signingAuths.count)
    {
        //save
        signingInfo[KEY_CS_AUTHS] = signingAuths;
    }
    
bail:
    
    //free signing info
    if(NULL != signingDetails)
    {
        //free
        CFRelease(signingDetails);
        signingDetails = NULL;
    }
    
    //free dynamic code
    if(NULL != dynamicCode)
    {
        //free
        CFRelease(dynamicCode);
        dynamicCode = NULL;
    }
    
    //free static code
    if(NULL != staticCode)
    {
        //free
        CFRelease(staticCode);
        staticCode = NULL;
    }
    
    return signingInfo;
}

//determine who signed item
NSNumber* extractSigner(SecStaticCodeRef code, SecCSFlags flags, BOOL isDynamic)
{
    //result
    NSNumber* signer = nil;
    
    //"anchor apple"
    static SecRequirementRef isApple = nil;
    
    //"anchor apple generic"
    static SecRequirementRef isDevID = nil;
    
    //"Apple Mac OS Application Signing"
    static SecRequirementRef isAppStore = nil;
    
    //"Apple iPhone OS Application Signing"
    static SecRequirementRef isiOSAppStore = nil;
    
    //signing details
    CFDictionaryRef signingDetails = NULL;
    
    //team id
    NSString* teamID = nil;
    
    //token
    static dispatch_once_t onceToken = 0;
    
    //only once
    // init requirements
    dispatch_once(&onceToken, ^{
        
        //init apple signing requirement
        SecRequirementCreateWithString(CFSTR("anchor apple"), kSecCSDefaultFlags, &isApple);
        
        //init dev id signing requirement
        SecRequirementCreateWithString(CFSTR("anchor apple generic"), kSecCSDefaultFlags, &isDevID);
        
        //init (macOS)  app store signing requirement
        SecRequirementCreateWithString(CFSTR("anchor apple generic and certificate leaf [subject.CN] = \"Apple Mac OS Application Signing\""), kSecCSDefaultFlags, &isAppStore);
        
        //init (iOS) app store signing requirement
        SecRequirementCreateWithString(CFSTR("anchor apple generic and certificate leaf [subject.CN] = \"Apple iPhone OS Application Signing\""), kSecCSDefaultFlags, &isiOSAppStore);
    });
    
    //check 1: "is apple" (proper)
    if(errSecSuccess == validateRequirement(code, isApple, flags, isDynamic))
    {
        //set signer to apple
        signer = [NSNumber numberWithInt:Apple];
    }

    //check 2: "is app store"
    // note: this is more specific than dev id, so do it first
    else if(errSecSuccess == validateRequirement(code, isAppStore, flags, isDynamic))
    {
        //default signer to app store
        signer = [NSNumber numberWithInt:AppStore];
        
        //however, set back to apple
        // ...if it's one of apple's app store apps
        if(errSecSuccess == SecCodeCopySigningInformation(code, kSecCSSigningInformation, &signingDetails))
        {
            //extract team id
            // and check if it belongs to apple
            teamID = [(__bridge NSDictionary*)signingDetails objectForKey:(__bridge NSString*)kSecCodeInfoTeamIdentifier];
            if( (YES == [teamID isEqualToString:@"K36BKF7T3D"]) ||
                (YES == [teamID isEqualToString:@"APPLECOMPUTER"]) )
            {
               //set signer to apple
               signer = [NSNumber numberWithInt:Apple];
            }
            
            //release
            CFRelease(signingDetails);
            signingDetails = NULL;
        }
    }
    
    //check 3: "is (iOS) app store"
    // note: this is more specific than dev id, so also do it first
    else if(errSecSuccess == validateRequirement(code, isiOSAppStore, flags, isDynamic))
    {
        //set signer to app store
        signer = [NSNumber numberWithInt:AppStore];
    }
    
    //check 4: "is dev id"
    else if(errSecSuccess == validateRequirement(code, isDevID, flags, isDynamic))
    {
        //set signer to dev id
        signer = [NSNumber numberWithInt:DevID];
    }
    
    //otherwise
    // has to be adhoc?
    else
    {
        //set signer to ad hoc
        signer = [NSNumber numberWithInt:AdHoc];
    }
    
    return signer;
}

//validate a requirement
OSStatus validateRequirement(SecStaticCodeRef code, SecRequirementRef requirement, SecCSFlags flags, BOOL isDynamic)
{
    //result
    OSStatus result = -1;
    
    //dynamic check?
    if(YES == isDynamic)
    {
        //validate dynamically
        result = SecCodeCheckValidity((SecCodeRef)code, flags, requirement);
    }
    //static check
    else
    {
        //validate statically
        result = SecStaticCodeCheckValidity(code, flags, requirement);
    }
    
    return result;
}

//extract (names) of signing auths
NSMutableArray* extractSigningAuths(NSDictionary* signingDetails)
{
    //signing auths
    NSMutableArray* authorities = nil;
    
    //cert chain
    NSArray* certificateChain = nil;
    
    //index
    NSUInteger index = 0;
    
    //cert
    SecCertificateRef certificate = NULL;
    
    //common name on chert
    CFStringRef commonName = NULL;
    
    //init array for certificate names
    authorities = [NSMutableArray array];
    
    //get cert chain
    certificateChain = [signingDetails objectForKey:(__bridge NSString*)kSecCodeInfoCertificates];
    if(0 == certificateChain.count)
    {
        //no certs
        goto bail;
    }
    
    //extract/save name of all certs
    for(index = 0; index < certificateChain.count; index++)
    {
        //reset
        commonName = NULL;
        
        //extract cert
        certificate = (__bridge SecCertificateRef)([certificateChain objectAtIndex:index]);
        
        //get common name
        if( (errSecSuccess == SecCertificateCopyCommonName(certificate, &commonName)) &&
            (NULL != commonName) )
        {
            //save
            [authorities addObject:(__bridge NSString*)(commonName)];
            
            //release
            CFRelease(commonName);
        }
    }
        
bail:
    
    return authorities;
}
