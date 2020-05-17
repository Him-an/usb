//
//  Utils.h
//  usbdocumentlib
//
//  Created by Aldo Ilsant on 20/10/15.
//  Copyright © 2015 aldoilsant. All rights reserved.
//

#ifndef usbdocumentlib_utils_h
#define usbdocumentlib_utils_h
#import <Foundation/Foundation.h>
#include <string>
#define LDEBUG 0
#define LINFO 1
#define LWARNING 2
#define LERROR 3
#define LFATAL 4
#include<syslog.h>

#include <IOKit/usb/IOUSBLib.h>


#define CURRENT_LOG_LEVEL LDEBUG
#define DLOG(Level,...) ({if(Level>=CURRENT_LOG_LEVEL) { printf(__VA_ARGS__); printf("\n"); fflush(stdout); char tempstr[1024]; snprintf(tempstr, 1024, __VA_ARGS__); syslog(LOG_NOTICE, "%s:%d:%s %s", __FILE__, __LINE__, __func__, tempstr);}})
#define USBINTFV IOUSBInterfaceInterface220

namespace usbdocument {
    class Utils {
    public:
        static void error_name (IOReturn err, char* out_buf);
        static void print_error(IOReturn err);
        static IOReturn watch_error(IOReturn err);
        static IOReturn assert_error(IOReturn err);
        static void milli_sleep(unsigned long milliseconds);
        static void test_assert(bool result,std::string message);
    };
}


#endif