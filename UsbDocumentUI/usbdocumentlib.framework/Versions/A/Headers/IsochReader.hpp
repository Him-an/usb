//
//  IsochReader.h
//  usbdocumentlib
//
//  Created by Aldo Ilsant on 20/10/15.
//  Copyright © 2015 aldoilsant. All rights reserved.
//

#ifndef usbdocumentlib_IsochReader_h
#define usbdocumentlib_IsochReader_h
#include "Utils.hpp"
#include "SyncBuffer.hpp"
#import <Foundation/Foundation.h>

namespace usbdocument {
    class IsochReader;
    class IsochRead;
    class IsochReaderDelegate {
    public:
        virtual void on_isoch_succeeded(IsochReader *reader, unsigned char * buffer, UInt64 actual_size)=0;
        virtual void on_isoch_error(IsochReader *reader)=0;
        
    };
    class IsochReader {
    private:
        bool has_started;
        bool halted;
        USBINTFV **interface;
        int endpoint;
        UInt32 buffer_size;
        IsochReaderDelegate *delegate;
        pthread_t reader_thread;
        int bytesPerFrame;
        int framesPerTransfer;
        int destroyedReads;
        UInt64 currentFrameNumber;
        bool frameNumberRetrieved;
        bool useLowLatency;
        
    protected:
        UInt64 get_next_frame_number();
        void destroy_isoch_read(IsochRead *read);

    public:
        IsochReader(USBINTFV ** interface, int endpoint, IsochReaderDelegate* delegate, bool useLowLatency);
        void start();
        void stop();
        
        //Internal
        void launch_isoch_transfers();
        void on_read_transferred(IsochRead *read, IOReturn retval, IOUSBIsocFrame *frameList);
        void launch_isoch_read(IsochRead *read);


    };
    
    class IsochRead {
    public:
        IsochRead();
        int tid;
        unsigned char *data_buffer;
        void *frame_list;
        UInt64 frameNumber;
        IsochReader *parent;
    };
}


#endif
 