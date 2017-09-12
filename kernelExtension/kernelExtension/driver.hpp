//
//  file: driver.hpp
//  project: lulu (kext)
//  description: main driver's interface (header)
//
//  created by Patrick Wardle
//  copyright (c) 2017 Objective-See. All rights reserved.
//

#include <IOKit/IOService.h>

#ifndef driver_h
#define driver_h

//class definition
class com_objective_see_firewall : public IOService
{
    //declare RTTI stuffz
    OSDeclareDefaultStructors(com_objective_see_firewall);
    
public:
    
    //standard driver methods
    virtual bool init(OSDictionary *dictionary = 0) override;
    virtual void free(void) override;
    virtual bool start(IOService *provider) override;
    virtual void stop(IOService *provider) override;
};

#endif

