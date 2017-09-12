//
//  AppReceipt.h
//  RansomWhere?
//
//  Created by Patrick Wardle on 5/1/16.
//
//  note: code inspired by [1] https://gist.github.com/sazameki/3026845

#ifndef AppReceipt_h
#define AppReceipt_h

#import <Security/CMSDecoder.h>
#import <Foundation/Foundation.h>
#import <Security/SecAsn1Coder.h>
#import <CommonCrypto/CommonDigest.h>
#import <Security/SecAsn1Templates.h>


//from 'Receipt Fields' section (Apple's 'Receipt Validation Programming Guide')

//ANS.1 data struct
typedef struct
{
    size_t          length;
    unsigned char   *data;
} ASN1_Data;

//receipt attribute struct
typedef struct
{
    ASN1_Data type;     // INTEGER
    ASN1_Data version;  // INTEGER
    ASN1_Data value;    // OCTET STRING
    
} ReceiptAttribute;

//receipt payload struct
typedef struct
{
    ReceiptAttribute **attrs;
    
} ReceiptPayload;

//ASN.1 receipt attribute template (from [1])
static const SecAsn1Template kReceiptAttributeTemplate[] =
{
    { SEC_ASN1_SEQUENCE, 0, NULL, sizeof(ReceiptAttribute) },
    { SEC_ASN1_INTEGER, offsetof(ReceiptAttribute, type), NULL, 0 },
    { SEC_ASN1_INTEGER, offsetof(ReceiptAttribute, version), NULL, 0 },
    { SEC_ASN1_OCTET_STRING, offsetof(ReceiptAttribute, value), NULL, 0 },
    { 0, 0, NULL, 0 }
};

//ASN.1 receipt template set (from [1])
static const SecAsn1Template kSetOfReceiptAttributeTemplate[] =
{
    { SEC_ASN1_SET_OF, 0, kReceiptAttributeTemplate, sizeof(ReceiptPayload) },
    { 0, 0, NULL, 0 }
};

//attribute type for bundle ID
#define RECEIPT_ATTR_BUNDLE_ID 2

//attribute type for app version
#define RECEIPT_ATTR_APP_VERSION 3

//attribute type for opaque value
#define RECEIPT_ATTR_OPAQUE_VALUE 4

//attribute type for receipt's hash
#define RECEIPT_ATTR_RECEIPT_HASH 5

//key for bundle id
#define KEY_BUNDLE_ID @"bundleID"

//key for bundle id data
#define KEY_BUNDLE_DATA @"bundleIDData"

//key for app version
#define KEY_APP_VERSION @"applicationVersion"

//key for opaque value
#define KEY_OPAQUE_VALUE @"opaqueValue"

//key for receipt's sha-1 hash
#define KEY_RECEIPT_HASH @"receiptHash"

//class interface
@interface AppReceipt : NSObject
{
    
}

/* METHODS */

//init with app path
// ->locate/load receipt, etc
-(instancetype)init:(NSBundle *)bundle;

/* PROPERTIES */

//encoded receipt data
@property (nonatomic, retain) NSData* encodedData;

//decoded receipt data
@property (nonatomic, retain) NSData* decodedData;

//receipt components
@property(nonatomic, retain)NSMutableDictionary* components;

//bundle id (from receipt)
@property (nonatomic, strong, readonly) NSString *bundleIdentifier;

//bundle id data (from receipt)
@property (nonatomic, strong, readonly) NSData *bundleIdentifierData;

//app version (from receipt)
@property (nonatomic, strong, readonly) NSString *appVersion;

//opaque value (from receipt)
@property (nonatomic, strong, readonly) NSData *opaqueValue;

//receipts hash (from receipt)
@property (nonatomic, strong, readonly) NSData *receiptHash;

@end

#endif /* AppReceipt_h */
