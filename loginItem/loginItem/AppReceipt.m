//
//  AppReceipt.m
//  RansomWhere?
//
//  Created by Patrick Wardle on 5/1/16.
//

#import "AppReceipt.h"

//helper function from [1]
// ->extract an int from ASN.1 data
inline static int getIntValueFromASN1Data(const ASN1_Data *asn1Data)
{
    int ret = 0;
    for (int i = 0; i < asn1Data->length; i++)
    {
        ret = (ret << 8) | asn1Data->data[i];
    }
    return ret;
}

//helper function from [1]
// ->decode string from ASN.1 data
inline static NSString *decodeUTF8StringFromASN1Data(SecAsn1CoderRef decoder, ASN1_Data srcData)
{
    //data struct
    ASN1_Data asn1Data = {0};
    
    //decoded string
    NSString* decodedString = nil;
    
    //status
    OSStatus status = -1;
    
    //decode
    status = SecAsn1Decode(decoder, srcData.data, srcData.length, kSecAsn1UTF8StringTemplate, &asn1Data);
    if(noErr != status)
    {
        //bail
        goto bail;
    }
    
    //convert to string
    decodedString = [[NSString alloc] initWithBytes:asn1Data.data length:asn1Data.length encoding:NSUTF8StringEncoding];
    
//bail
bail:
    
    return decodedString;
}

//class implementation
@implementation AppReceipt

//synthesize thingz
@synthesize components;
@synthesize encodedData;
@synthesize decodedData;

//init with app path
// ->locate/load/decode receipt, etc
-(instancetype)init:(NSBundle *)bundle
{
    //init
    if(self = [super init])
    {
        //first check for receipt
        if( (nil == bundle.appStoreReceiptURL) ||
            (YES != [[NSFileManager defaultManager] fileExistsAtPath:bundle.appStoreReceiptURL.path]) )
        {
            //bail
            return nil;
        }
        
        //load encoded receipt data
        self.encodedData = [NSData dataWithContentsOfURL:bundle.appStoreReceiptURL];
        if(nil == self.encodedData)
        {
            //bail
            return nil;
        }
        
        //decode receipt data
        self.decodedData = [self decode];
        if(nil == self.decodedData)
        {
            //bail
            return nil;
        }
        
        //parse out values
        // ->bundle id, app version, etc
        self.components = [self parse];
        if( (nil == self.components) ||
            (0 == self.components.count) )
        {
            //bail
            return nil;
        }
    }
    
    return self;
}

//decode receipt data
// ->some validations performed here too
-(NSData*)decode
{
    //decoded data
    NSData* decoded = nil;
    
    //decoder
    CMSDecoderRef decoder = NULL;
    
    //policy
    SecPolicyRef policy = NULL;
    
    //trust
    SecTrustRef trust = NULL;
    
    //status
    OSStatus status = -1;
    
    //data
    CFDataRef data = NULL;
    
    //number of signers
    size_t signers = 0;
    
    //signer status
    CMSSignerStatus signerStatus = -1;
    
    //cert verify
    OSStatus certVerifyResult = 1;

    //create decoder
    status = CMSDecoderCreate(&decoder);
    if(noErr != status)
    {
        //bail
        goto bail;
    }
    
    //add encoded data to message
    status = CMSDecoderUpdateMessage(decoder, self.encodedData.bytes, self.encodedData.length);
    if(noErr != status)
    {
        //bail
        goto bail;
    }
    
    //decode
    status = CMSDecoderFinalizeMessage(decoder);
    if(noErr != status)
    {
        //bail
        goto bail;
    }
    
    //create policy
    policy = SecPolicyCreateBasicX509();
    if(NULL == policy)
    {
        //bail
        goto bail;
    }

    //CHECK 1:
    // ->make sure there is a signer
    status = CMSDecoderGetNumSigners(decoder, &signers);
    if( (noErr != status) ||
        (0 == signers) )
    {
        //bail
        goto bail;
    }

    //CHECK 2:
    // ->make sure signer status is ok
    status = CMSDecoderCopySignerStatus(decoder, 0, policy, TRUE, &signerStatus, &trust, &certVerifyResult);
    if( (noErr != status) ||
        (kCMSSignerValid != signerStatus) )
    {
        //bail
        goto bail;
    }
    
    //grab decoded content
    status = CMSDecoderCopyContent(decoder, &data);
    if(noErr != status)
    {
        //bail
        goto bail;
    }
    
    //convert to NSData
    decoded = [NSData dataWithData:(__bridge NSData *)data];
    
//bail
bail:
    
    //release policy
    if(NULL != policy)
    {
        //release
        CFRelease(policy);
    }
    
    //release trust
    if(NULL != trust)
    {
        //release
        CFRelease(trust);
    }
    
    //release decoder
    if(NULL != decoder)
    {
        //release
        CFRelease(decoder);
    }
    
    //release data
    if(NULL != data)
    {
        //release
        CFRelease(data);
    }
    
    return decoded;
}

//parse decoded receipt
// ->extract out items such as bundle id, app version, etc.
-(NSMutableDictionary*)parse
{
    //decoder
    SecAsn1CoderRef decoder = NULL;
    
    //status
    OSStatus status = -1;
    
    //payload struct
    ReceiptPayload payload = {0};
    
    //attribute
    ReceiptAttribute *attribute;
    
    //dictionary for items
    NSMutableDictionary* items = nil;
    
    //create decoder
    status = SecAsn1CoderCreate(&decoder);
    if(noErr != status)
    {
        //bail
        goto bail;
    }
    
    //decode
    status = SecAsn1Decode(decoder, self.decodedData.bytes, self.decodedData.length, kSetOfReceiptAttributeTemplate, &payload);
    if(noErr != status)
    {
        //bail
        goto bail;
    }
    
    //init dictionary for items
    items = [NSMutableDictionary dictionary];
    
    //extact attributes
    // ->save those of interest
    for(int i = 0; (attribute = payload.attrs[i]); i++)
    {
        //process each type
        switch(getIntValueFromASN1Data(&attribute->type))
        {
            //bundle id
            // ->save bundle id and data
            case RECEIPT_ATTR_BUNDLE_ID:
            {
                //save bundle id
                items[KEY_BUNDLE_ID] = decodeUTF8StringFromASN1Data(decoder, attribute->value);
                
                //save bundle id data
                items[KEY_BUNDLE_DATA] = [NSData dataWithBytes:attribute->value.data length:attribute->value.length];
                
                break;
            }
                
            //app version
            case RECEIPT_ATTR_APP_VERSION:
            {
                //save
                items[KEY_APP_VERSION] = decodeUTF8StringFromASN1Data(decoder, attribute->value);
                
                break;
                
            }
                
            //opaque value
            case RECEIPT_ATTR_OPAQUE_VALUE:
            {
                //save
                items[KEY_OPAQUE_VALUE] = [NSData dataWithBytes:attribute->value.data length:attribute->value.length];
                
                break;
            }
                
            //receipt hash
            case RECEIPT_ATTR_RECEIPT_HASH:
            {
                //save
                items[KEY_RECEIPT_HASH] = [NSData dataWithBytes:attribute->value.data length:attribute->value.length];
                
                break;
            }
                
            //default
            // ->ignore
            default:
            {
                break;
            }
                
        }//switch
        
    }//for all attributes

//bail
bail:
    
    //release decoder
    if(NULL != decoder)
    {
        //release
        SecAsn1CoderRelease(decoder);
    }
    
    return items;
}

//return bundle id
-(NSString*)bundleIdentifier
{
    return self.components[KEY_BUNDLE_ID];
}

//return bundle id data
-(NSData*)bundleIdentifierData
{
    return self.components[KEY_BUNDLE_DATA];
}

//return app version
-(NSString*)appVersion
{
    return self.components[KEY_APP_VERSION];
}

//return opaque data
-(NSData*)opaqueValue
{
    return self.components[KEY_OPAQUE_VALUE];
}

//return receipt hash
-(NSData*)receiptHash
{
    return self.components[KEY_RECEIPT_HASH];
}

@end