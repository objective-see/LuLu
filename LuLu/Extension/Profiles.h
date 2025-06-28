//
//  Profiles.h
//
//  Created by Patrick Wardle on 06/21/25.
//  Copyright (c) 2025 Objective-See. All rights reserved.
//

@import OSLog;
@import Foundation;

@interface Profiles : NSObject

/* PROPERTIES */

//profiles directory
@property(nonatomic, retain)NSString* directory;

/* METHODS */

-(NSMutableArray*)enumerate;
-(void)set:(NSString*)profilePath;
-(BOOL)add:(NSString*)name preferences:(NSDictionary*)preferences;
-(BOOL)delete:(NSString*)name;

@end
