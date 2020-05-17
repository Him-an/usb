//
//  IsochReader.m
//  usbdocumentlib
//
//  Created by Aldo Ilsant on 20/10/15.
//  Copyright © 2015 aldoilsant. All rights reserved.
//

#include "IsochReader.hpp"
#include <pthread.h>
#import <IOKit/IOKitLib.h>
#import <IOKit/IOMessage.h>
#import <IOKit/IOCFPlugIn.h>
#import <IOKit/usb/IOUSBLib.h>

#define NUMBER_OF_CONCURRENT_READS 20
using namespace usbdocument;

void *launchReaderThread(void *arg) {
    IsochReader *reader=(IsochReader *) arg;
    reader->launch_isoch_transfers();
    return NULL;
}
usbdocument::IsochReader::IsochReader(USBINTFV ** interface, int endpoint, IsochReaderDelegate* delegate, bool useLowLatency) {
    this->useLowLatency=useLowLatency;
    this->interface=interface;
    this->endpoint=endpoint;
    this->delegate=delegate;
    this->bytesPerFrame=3072;
    this->framesPerTransfer=64;
    this->currentFrameNumber=0;
    this->frameNumberRetrieved=false;
}

void usbdocument::IsochReader::start() {
    has_started=true;
    destroyedReads=0;
    pthread_create(&reader_thread, NULL, launchReaderThread,(void *)this);
}
void usbdocument::IsochReader::launch_isoch_transfers() {
    CFRunLoopSourceRef ref;
    IOReturn kr;
    mach_port_t port;
    //(*this->interface)->CreateInterfaceAsyncPort(this->interface,&port);
    kr=(*this->interface)->CreateInterfaceAsyncEventSource(this->interface,&ref);
    Utils::watch_error(kr);
    CFRunLoopAddSource(CFRunLoopGetCurrent(), ref, kCFRunLoopDefaultMode);
    int i;
    for(i=0;i<NUMBER_OF_CONCURRENT_READS;i++) {
        IsochRead *read=new IsochRead();
        read->parent=this;
        read->tid=i;
        UInt32 bufferSize=bytesPerFrame*framesPerTransfer;
        void *frameList;
        if(useLowLatency) {
            Utils::watch_error((*this->interface)->LowLatencyCreateBuffer(this->interface, (void **)&(read->data_buffer),bufferSize, kUSBLowLatencyReadBuffer));
            Utils::watch_error((*this->interface)->LowLatencyCreateBuffer(this->interface, &(frameList),framesPerTransfer*sizeof(IOUSBLowLatencyIsocFrame), kUSBLowLatencyFrameListBuffer));
        } else {
            read->data_buffer=(unsigned char *)calloc(bufferSize,1);
            frameList=calloc(framesPerTransfer,sizeof(IOUSBIsocFrame));
        }
        read->frame_list=frameList;
        launch_isoch_read(read);
    }
    while(destroyedReads<NUMBER_OF_CONCURRENT_READS) {
        CFRunLoopRunInMode(kCFRunLoopDefaultMode, 0, false);
    }
    CFRunLoopStop(CFRunLoopGetCurrent());
    CFRunLoopRemoveSource(CFRunLoopGetCurrent(), ref,kCFRunLoopDefaultMode);
    halted=true;
}
UInt64 usbdocument::IsochReader::get_next_frame_number() {
    if(!frameNumberRetrieved) {
        frameNumberRetrieved=true;
        AbsoluteTime atTime;
        (*(this->interface))->GetBusFrameNumber(this->interface,&(currentFrameNumber),&atTime);
        return currentFrameNumber;
    } else if(has_started){
        currentFrameNumber+=framesPerTransfer/8;
        return currentFrameNumber;
    } else {
        return 0;
    }
}
void usbdocument::IsochReader::destroy_isoch_read(IsochRead *read) {
    if(useLowLatency) {
        Utils::watch_error((*this->interface)->LowLatencyDestroyBuffer(this->interface, read->data_buffer));
        Utils::watch_error((*this->interface)->LowLatencyDestroyBuffer(this->interface, read->frame_list));
    }
    destroyedReads++;
}
void on_isoch_transfer(void *refcon, IOReturn retval, void *arg0) {
    IsochRead *read=(IsochRead *) refcon;
    Utils::watch_error(retval);
    IOUSBIsocFrame *frameList=(IOUSBIsocFrame *) arg0;
    read->parent->on_read_transferred(read, retval,(IOUSBIsocFrame *)read->frame_list);
    //Relaunch
    read->parent->launch_isoch_read(read);
}
void usbdocument::IsochReader::on_read_transferred(IsochRead *read, IOReturn retval, IOUSBIsocFrame *frameList) {
    int dataFrameCount=0;
    unsigned int offset=0;
    if(retval==kIOReturnSuccess || retval==kIOReturnUnderrun || retval==kIOUSBBufferOverrunErr) {
        int i;
        for(i=0;i<framesPerTransfer;i++) {
            unsigned int actCount=0;
            if(useLowLatency) {
                actCount=((IOUSBLowLatencyIsocFrame *)frameList)[i].frActCount;
            } else {
                actCount=((IOUSBIsocFrame *)frameList)[i].frActCount;
            }
            if(actCount>0) {
                delegate->on_isoch_succeeded(this, read->data_buffer+offset, actCount*sizeof(char));
                dataFrameCount++;
            }
            offset+=bytesPerFrame;
        }
        
    }
    //DLOG(LDEBUG,"Frames with data: %d\n",dataFrameCount);
}
void usbdocument::IsochReader::launch_isoch_read(IsochRead *read) {
    read->frameNumber=get_next_frame_number();
    if(read->frameNumber==0) {
        destroy_isoch_read(read);
        DLOG(LDEBUG,"Ending isoch read");
        return;
    }
    void *fl;
    fl=read->frame_list;
    if(useLowLatency) {
        IOUSBLowLatencyIsocFrame *fl2=(IOUSBLowLatencyIsocFrame *)read->frame_list;
        int i;
        for(i=0;i<framesPerTransfer;i++) {
            memset(&(fl2[i]),0,sizeof(IOUSBLowLatencyIsocFrame));
            fl2[i].frReqCount=bytesPerFrame;
        }
    } else {
        IOUSBIsocFrame *fl2=(IOUSBIsocFrame *) read->frame_list;
        int i;
        for(i=0;i<framesPerTransfer;i++) {
            fl2[i].frReqCount=bytesPerFrame;
        }
    }
    IOReturn kr;
    if(useLowLatency) {
        //Launch the actual read
         kr=(*this->interface)->LowLatencyReadIsochPipeAsync(interface, //reference to self
                                                                     1, //Endpoint to use
                                                                     read->data_buffer, //Buffer to hold
                                                                     read->frameNumber, //Frame start
                                                                     framesPerTransfer,
                                                                     0,
                                                                     (IOUSBLowLatencyIsocFrame *)fl,
                                                                     on_isoch_transfer,
                                                                     (void *)read);
    } else {
        kr=(*this->interface)->ReadIsochPipeAsync(
                                                      interface, //reference to self
                                                      1, //Endpoint to use
                                                      read->data_buffer, //Buffer to hold the data
                                                      read->frameNumber, //Frame start
                                                      framesPerTransfer, //Number of frames
                                                      (IOUSBIsocFrame *)fl, //The misterious frame list
                                                      on_isoch_transfer,
                                                      (void *) read
                                                      );
    }
    
    Utils::watch_error(kr);
    if(kr!=kIOReturnSuccess && kr!=kIOReturnNoDevice && kr!=kIOReturnAborted) { //Do not relaunch if camera is gone
        DLOG(LINFO,"RELAUNCHING ASYNCREQUEST...\n");
        launch_isoch_read(read);
    }
}
void usbdocument::IsochReader::stop() {
    halted=false;
    has_started=false;
    while(!halted) {
        Utils::milli_sleep(100);
    }
    Utils::milli_sleep(200);
}
usbdocument::IsochRead::IsochRead() {
}
