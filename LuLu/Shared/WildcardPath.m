//
//  file: WildcardPath.m
//  project: LuLu (shared)
//  description: matching of (rule) paths that contain wildcards
//
//  created by Patrick Wardle
//  copyright (c) 2025 Objective-See. All rights reserved.
//

#import "consts.h"
#import "WildcardPath.h"

#import <fnmatch.h>

//wildcard metacharacters
// note: '\' is in here as fnmatch treats it as an escape, so a literal prefix has to stop there too
#define WILDCARD_CHARACTERS @"*?[\\"

//does a (rule) path contain wildcards?
BOOL isWildcardPath(NSString* path)
{
    //portion of the path to examine
    NSString* candidate = path;

    //no path?
    if(0 == path.length) return NO;

    //global rule ('*')?
    // it matches everything, so it's never matched as a path
    if(YES == [path isEqualToString:VALUE_ANY]) return NO;

    //only absolute paths can name a binary on disk
    // ...so anything else is left alone (and won't match)
    if(YES != [path hasPrefix:@"/"]) return NO;

    //directory rule ('/some/dir/*')?
    // its trailing '*' is matched by prefix, so drop it before looking for any others
    if(YES == [path hasSuffix:@"/*"]) candidate = [path substringToIndex:(path.length - 2)];

    //any (other) wildcard?
    return (NSNotFound != [candidate rangeOfCharacterFromSet:[NSCharacterSet characterSetWithCharactersInString:WILDCARD_CHARACTERS]].location);
}

//the literal (leading) portion of a wildcard path, up to its first wildcard
NSString* wildcardPathPrefix(NSString* path)
{
    //first wildcard
    NSRange wildcard = {0};

    //no path?
    if(0 == path.length) return @"";

    //find first wildcard
    wildcard = [path rangeOfCharacterFromSet:[NSCharacterSet characterSetWithCharactersInString:WILDCARD_CHARACTERS]];

    //none?
    // whole path is literal
    if(NSNotFound == wildcard.location) return path;

    return [path substringToIndex:wildcard.location];
}

//does a path match a wildcard (rule) path?
BOOL wildcardPathMatch(NSString* pattern, NSString* path)
{
    //pattern, as a c string
    const char* patternUTF8 = NULL;

    //path, as a c string
    const char* pathUTF8 = NULL;

    //sanity check
    if( (0 == pattern.length) ||
        (0 == path.length) ) return NO;

    //cheap pre-filter
    // whatever the pattern matches has to start with its literal portion
    if(YES != [path hasPrefix:wildcardPathPrefix(pattern)]) return NO;

    //convert
    patternUTF8 = pattern.UTF8String;
    pathUTF8 = path.UTF8String;
    if( (NULL == patternUTF8) ||
        (NULL == pathUTF8) ) return NO;

    //match
    // note: 'FNM_PATHNAME' so a wildcard matches within a single path component, never across a '/'
    return (0 == fnmatch(patternUTF8, pathUTF8, FNM_PATHNAME));
}
