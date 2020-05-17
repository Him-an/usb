//
//  SyncBuffer.m
//  usbdocumentlib
//
//  Created by Aldo Ilsant on 20/10/15.
//  Copyright © 2015 aldoilsant. All rights reserved.
//

#include "SyncBuffer.hpp"

usbdocument::SyncBufferManager::SyncBufferManager() {
    pthread_mutex_init(&(mutex),NULL);
}

void usbdocument::SyncBufferManager::add_buffer(unsigned char *data, UInt64 size) {
    pthread_mutex_lock(&mutex);
    SyncBuffer buffer;
    
    buffer.buffer=(unsigned char *)calloc(1,size);
    memcpy(buffer.buffer, data, size);
    buffer.size=size;
    syncBuffers.push_back(buffer);
    pthread_mutex_unlock(&mutex);
}
usbdocument::SyncBuffer usbdocument::SyncBufferManager::pop_buffer(){
    pthread_mutex_lock(&mutex);
    if(syncBuffers.size()==0) {
        SyncBuffer buffer;
        buffer.buffer=NULL;
        buffer.size=0;
        pthread_mutex_unlock(&mutex);
        return buffer;
    } else {
        SyncBuffer ret=syncBuffers[0];
        syncBuffers.erase(syncBuffers.begin());
        pthread_mutex_unlock(&mutex);
        return ret;
    }
}
usbdocument::SyncBuffer usbdocument::SyncBufferManager::peek_buffer() {
    pthread_mutex_lock(&mutex);
    if(syncBuffers.size()==0) {
        SyncBuffer buffer;
        buffer.buffer=NULL;
        buffer.size=0;
        pthread_mutex_unlock(&mutex);
        return buffer;
    } else {
        SyncBuffer ret=syncBuffers[0];
        pthread_mutex_unlock(&mutex);
        return ret;
    }
}
void usbdocument::SyncBufferManager::destroy_buffer(usbdocument::SyncBuffer buffer) {
    if(buffer.buffer!=NULL) {
        free(buffer.buffer);
    }
}
void usbdocument::SyncBufferManager::clear() {
    pthread_mutex_lock(&mutex);
    for(auto buffer : syncBuffers) {
        destroy_buffer(buffer);
    }
    syncBuffers.clear();
    pthread_mutex_unlock(&mutex);
    
}