//
//  SyncBuffer.h
//  usbdocumentlib
//
//  Created by Aldo Ilsant on 20/10/15.
//  Copyright © 2015 aldoilsant. All rights reserved.
//

#ifndef usbdocumentlib_SyncBuffer_h
#define usbdocumentlib_SyncBuffer_h

#import <Foundation/Foundation.h>
#include<pthread.h>
#include<vector>

using std::vector;

namespace usbdocument {
    
    class SyncBuffer {
    public:
        unsigned char *buffer;
        UInt64 size;
    };
    
    class SyncBufferManager {
    private:
        pthread_mutex_t mutex;
        vector<SyncBuffer> syncBuffers;
    public:
        SyncBufferManager();
        
        void add_buffer(unsigned char *data, UInt64 size);
        SyncBuffer pop_buffer();
        SyncBuffer peek_buffer();
        void destroy_buffer(SyncBuffer buffer);
        
        void clear();
    };
    
}
#endif
