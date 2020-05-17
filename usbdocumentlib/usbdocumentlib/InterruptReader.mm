//
//  InterruptReader.m
//  usbdocumentlib
//
//  Created by Aldo Ilsant on 21/10/15.
//  Copyright © 2015 aldoilsant. All rights reserved.
//

#import "InterruptReader.hpp"

using namespace usbdocument;

void callback_on_interrupt_read(void *reconf, IOReturn result, void *arg0) {
    DLOG(LDEBUG,"Interrupt read received\n");
    InterruptReader *ir=(InterruptReader *)reconf;
    UInt64 bytesRead=(UInt64) arg0;
    if(ir->started() && result==kIOReturnSuccess) {
        ir->notify_delegate(bytesRead);
        DLOG(LDEBUG,"Number of bytes received: %llu\n",bytesRead);
        ir->launch_interrupt_transfer();
    } else if(result==kIOReturnAborted) {
        DLOG(LFATAL,"Interrupt aborted");
    } else if(result!=kIOReturnSuccess) {
        ir->launch_interrupt_transfer();
    }
    Utils::watch_error(result);
}

void *launchInterruptReaderThread(void *arg) {
    usbdocument::InterruptReader *reader=(usbdocument::InterruptReader *) arg;
    reader->watch_interrupt_transfer();
    return NULL;
}

usbdocument::InterruptReader::InterruptReader(USBINTFV **interface, int endpoint, int bufferSize, InterruptReaderDelegate *delegate) {
    this->interface=interface;
    this->endpoint=endpoint;
    this->bufferSize=bufferSize;
    this->delegate=delegate;
}

void usbdocument::InterruptReader::start() {
    has_started=true;
    interrupt_buffer=(unsigned char *)calloc(1,bufferSize);
    pthread_create(&reader_thread, NULL, launchInterruptReaderThread,(void *)this);
}
void usbdocument::InterruptReader::stop() {
    (*this->interface)->AbortPipe(this->interface,this->endpoint);
    Utils::milli_sleep(200);
    has_started=false;
    free(interrupt_buffer);
    interrupt_buffer=NULL;
}
void usbdocument::InterruptReader::watch_interrupt_transfer() {
    CFRunLoopSourceRef ref;
    IOReturn kr;
    mach_port_t port;
    (*this->interface)->CreateInterfaceAsyncPort(this->interface,&port);
    kr=(*this->interface)->CreateInterfaceAsyncEventSource(this->interface,&ref);
    Utils::watch_error(kr);
    if(kr==kIOReturnSuccess) {
        CFRunLoopAddSource(CFRunLoopGetCurrent(), ref, kCFRunLoopDefaultMode);
        launch_interrupt_transfer();
        while(has_started) {
            CFRunLoopRunInMode(kCFRunLoopDefaultMode, 0, false);
        }
        CFRunLoopStop(CFRunLoopGetCurrent());
        CFRunLoopRemoveSource(CFRunLoopGetCurrent(), ref,kCFRunLoopDefaultMode);
    }
}
void usbdocument::InterruptReader::watch_interrupt_transfer_2() {
    while(has_started) {
        launch_interrupt_transfer_2();
    }
}
void usbdocument::InterruptReader::launch_interrupt_transfer() {
    //IOReturn (*ReadPipeAsync)(void *self, UInt8 pipeRef, void *buf, UInt32 size, IOAsyncCallback1 callback, void *refcon);
    (*this->interface)->ClearPipeStallBothEnds(this->interface,1);
    IOReturn kr;
    //    IOReturn (*ReadPipe)(void *self, UInt8 pipeRef, void *buf, UInt32 *size);
    kr=(*(this->interface))->ReadPipeAsync(interface, 1 ,interrupt_buffer,bufferSize,callback_on_interrupt_read, this);
    Utils::watch_error(kr);
    if(kr!=kIOReturnSuccess) {
        DLOG(LFATAL,"ERROR ON LAUNCHING INTERRUPT READ");
    }
}
bool usbdocument::InterruptReader::started() {
    return has_started;
}

void usbdocument::InterruptReader::launch_interrupt_transfer_2() {
    IOReturn kr;
    //    IOReturn (*ReadPipe)(void *self, UInt8 pipeRef, void *buf, UInt32 *size);
    
    UInt32 bytesRead=bufferSize;
    kr=(*(this->interface))->ReadPipe(interface, 1 ,interrupt_buffer,&bytesRead);
    DLOG(LINFO,"INTERRUPT READ SYNCHRONOUSLY");
    if(kr==kIOReturnSuccess) {
        this->notify_delegate(bytesRead);
    }
    Utils::watch_error(kr);
}
void usbdocument::InterruptReader::notify_delegate(UInt64 bytesRead) {
    int i;
    for(i=0;i<bytesRead;i++) {
        DLOG(LFATAL,"Byte for interrupt: %d",interrupt_buffer[i]);
    }
    if(interrupt_buffer[0]==2) {
        DLOG(LFATAL,"ACTUALLY NOTIFYING CLICK");
        delegate->on_interrupt_read(this, interrupt_buffer, bytesRead);
    }
}

