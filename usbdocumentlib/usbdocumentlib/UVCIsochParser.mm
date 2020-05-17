//
//  UVCIsochParser.m
//  usbdocumentlib
//
//  Created by Aldo Ilsant on 20/10/15.
//  Copyright © 2015 aldoilsant. All rights reserved.
//

#import "UVCIsochParser.hpp"
#import "Utils.hpp"
#import "UVCUtils.hpp"

using namespace usbdocument;

void *parser_pthread_launch(void *arg) {
    UVCIsochParser *parser=(UVCIsochParser *) arg;
    parser->parse_loop();
    return NULL;
}

usbdocument::UVCIsochParser::UVCIsochParser(UVCFormat *format, SyncBufferManager *syncBufferManager,UVCIsochParserDelegate *delegate) {
    this->format=format;
    this->syncBufferManager=syncBufferManager;
    this->delegate=delegate;
    has_started=false;
}

void usbdocument::UVCIsochParser::start() {
    has_started=true;
    pthread_attr_t attr;
    pthread_attr_init(&attr);
    pthread_attr_setdetachstate(&attr, PTHREAD_CREATE_JOINABLE);
    pthread_t thread;
    pthread_create(&thread,&attr,parser_pthread_launch,this);
}
void usbdocument::UVCIsochParser::stop() {
    halted=false;
    has_started=false;
    while(!halted) {
        Utils::milli_sleep(10);
    }
}
void usbdocument::UVCIsochParser::parse_loop() {
    int fid=-1;
    unsigned char *frame_data=NULL;
    int frame_offset=0;
    int max_size=format->width*format->height*16;
    while(has_started) {
        SyncBuffer isoch_buffer=syncBufferManager->pop_buffer();
        if(isoch_buffer.buffer!=NULL) {
            int i;
            int headerLength=isoch_buffer.buffer[0];
            if(headerLength==0) {
                DLOG(LINFO,"Invalid zero length header");
                syncBufferManager->destroy_buffer(isoch_buffer);
                continue;
            }
            UVC_DECODE_HEADER header;
            UVCUtils::decode_header(isoch_buffer.buffer, &header);
            unsigned int data_length=isoch_buffer.size-isoch_buffer.buffer[0];
            if(fid!=header.bFrameId) {
                //DLOG(LINFO,"FID has changed: %d",header.bFrameId);
                if(frame_data!=NULL) {
                    delegate->on_new_frame(frame_data, frame_offset);
                    free(frame_data);
                    frame_data=NULL;
                }
                fid=header.bFrameId;
                frame_data=(unsigned char *)calloc(1,max_size);
                frame_offset=0;
            }
            if(frame_offset+data_length<max_size) {
                //Copy
                if(frame_data!=NULL) {
                    memcpy(frame_data+frame_offset,isoch_buffer.buffer+isoch_buffer.buffer[0],data_length);
                    frame_offset+=data_length;
                }
            } else {
                DLOG(LINFO,"Frame overrun");
            }
            
        cleanup:
            syncBufferManager->destroy_buffer(isoch_buffer);
        } else {
            syncBufferManager->destroy_buffer(isoch_buffer);
            Utils::milli_sleep(1);
        }
    }
    if(frame_data!=NULL) {
        free(frame_data);
    }
    halted=true;
}
