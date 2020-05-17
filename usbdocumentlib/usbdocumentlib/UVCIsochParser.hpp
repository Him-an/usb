//
//  UVCIsochParser.h
//  usbdocumentlib
//
//  Created by Aldo Ilsant on 20/10/15.
//  Copyright © 2015 aldoilsant. All rights reserved.
//

#ifndef usbdocumentlib_UVCIsochParser_h
#define usbdocumentlib_UVCIsochParser_h

#import <Foundation/Foundation.h>
#import "SyncBuffer.hpp"
#import "usbdocumentlib.hpp"

namespace usbdocument {
    class UVCIsochParser;
    
    class UVCIsochParserDelegate {
    public:
        virtual void on_new_frame(unsigned char *buffer, UInt64 size)=0;
    };
    
    class UVCIsochParser {
    private:
        SyncBufferManager *syncBufferManager;
        UVCIsochParserDelegate *delegate;
        UVCFormat *format;
        bool has_started;
        bool halted;
        
    public:
        UVCIsochParser(UVCFormat *format, SyncBufferManager *syncBufferManager,UVCIsochParserDelegate *delegate);
        void start();
        void stop();
        void parse_loop();
    };
}

#endif
 