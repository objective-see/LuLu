//
//  file: WildcardPath.h
//  project: LuLu (shared)
//  description: matching of (rule) paths that contain wildcards (header)
//
//  created by Patrick Wardle
//  copyright (c) 2025 Objective-See. All rights reserved.
//

#ifndef WildcardPath_h
#define WildcardPath_h

@import Foundation;

/* FUNCTIONS */

//does a (rule) path contain wildcards?
// note: the lone '*' (global rule) and a trailing '/*' (directory rule) don't count,
//       as both already have their own (cheaper) matching logic
BOOL isWildcardPath(NSString* path);

//the literal (leading) portion of a wildcard path, up to its first wildcard
// e.g. '/Users/*/.vscode/extensions/foo-*/bar' -> '/Users/'
// note: anything the path matches must start with this, so it makes for a cheap pre-filter
NSString* wildcardPathPrefix(NSString* path);

//does a path match a wildcard (rule) path?
// note: '*', '?' and '[...]' match within a single path component, never across a '/'
BOOL wildcardPathMatch(NSString* pattern, NSString* path);

#endif /* WildcardPath_h */
