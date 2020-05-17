//
//  InterruptReader.h
//  usbdocumentlib
//
//  Created by Aldo Ilsant on 21/10/15.
//  Copyright © 2015 aldoilsant. All rights reserved.
//

#ifndef usbdocumentlib_InterruptReader_h
#define usbdocumentlib_InterruptReader_h

#import <Foundation/Foundation.h>
#include "Utils.hpp"
#include <pthread.h>

namespace usbdocument {

    class InterruptReader;
    
    class InterruptReaderDelegate {
    public:
        virtual void on_interrupt_read(InterruptReader *reader, unsigned char *data, UInt64 size)=0;
    };
    
    class InterruptReader {
    private:
        USBINTFV **interface;
        int endpoint;
        int bufferSize;
        InterruptReaderDelegate *delegate;
        bool has_started;
        pthread_t reader_thread;
        unsigned char *interrupt_buffer;

    public:
        InterruptReader(USBINTFV **interface, int endpoint, int bufferSize, InterruptReaderDelegate *delegate);
        void start();
        void stop();
        
        //Internal
        void watch_interrupt_transfer();
        void watch_interrupt_transfer_2();
        void launch_interrupt_transfer();
        void launch_interrupt_transfer_2();
        void notify_delegate(UInt64 bytesRead);
        bool started();
    };
    
}
#endif
