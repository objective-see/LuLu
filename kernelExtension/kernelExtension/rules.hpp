//
//  file: rules.hpp
//  project: lulu (kext)
//  description: manages dictionary of rules (header)
//
//  created by Patrick Wardle
//  copyright (c) 2017 Objective-See. All rights reserved.
//

#ifndef rules_h
#define rules_h

#include <sys/proc.h>

//init function
bool initRules();

//add rule
bool rulesAdd(int processID, bool state);

//get state of rule
// not found, block, allow
int queryRule(int processID);

//remove any rule that matches pid
void rulesRemove(int processID);

//uninit rules
// ->frees mutex/mutex group
void uninitRules();

#endif /* rules_h */
