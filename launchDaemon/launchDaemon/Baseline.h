//
//  Baseline.h
//  launchDaemon
//
//  Created by Patrick Wardle on 2/21/18.
//  Copyright © 2018 Objective-See. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface Baseline : NSObject

/* PROPERTIES */

//query for baselining rules
//@property(nonatomic, retain)NSMetadataQuery* appQuery;
    
//operation queue
//@property(nonatomic, retain)NSOperationQueue *operationQueue;
    
//list of installed (3rd-party) app
//@property(nonatomic, retain)NSMutableArray* installedApps;

/* METHODS */

//start query for all installed apps
// save, and if user selects 'allow (already) installed apps, we'll have this reference list
//-(void)startBaselining;

//invoke system profiler to get installed apps
// then process each, saving info about 3rd-party ones
-(void)baseline;

@end
