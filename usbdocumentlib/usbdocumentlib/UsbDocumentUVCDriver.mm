//
//  UsbDocumentUVCDriver.m
//  usbdocumentlib
//
//  Created by Aldo Ilsant on 20/10/15.
//  Copyright © 2015 aldoilsant. All rights reserved.
//

#include "UsbDocumentUVCDriver.hpp"
#include <pthread.h>
#include <IOKit/usb/IOUSBLib.h>
#include <IOKit/IOCFPlugIn.h>
#include <IOKit/IOMessage.h>

using namespace usbdocument;


void *usb_launch_driver(void *arg) {
    DocumentUVCDriver *driver=(DocumentUVCDriver *)arg;
    driver->do_driver_loop();
    return NULL;
}

void device_removed(void *refConf, io_iterator_t iterator) {
    DocumentUVCDriver *driver=(DocumentUVCDriver *) refConf;
    driver->device_removed(iterator);
}
void device_added(void *refConf,io_iterator_t iterator) {
    DocumentUVCDriver *driver=(DocumentUVCDriver *) refConf;
    driver->device_added(iterator);
}

void interestCallback(void * refcon, io_service_t service, natural_t messageType, void *messageArgument ) {
    DocumentUVCCamera *camera=(DocumentUVCCamera *) refcon;
    camera->on_interest_callback(messageType, messageArgument);
}
void usbdocument::DocumentUVCDriver::on_camera_removed(DocumentUVCCamera *removed_camera) {
    int i;
    for(i=0;i<cameras.size();i++) {
        if(cameras[i]==removed_camera) {
            delegate->on_camera_removed(i);
            break;
        }
    }
    cameras.erase(cameras.begin()+i);
    delete removed_camera;
}
void usbdocument::DocumentUVCDriver::device_added(io_iterator_t iterator) {
    io_service_t			usbDeviceRef=IO_OBJECT_NULL;
    DLOG(LINFO,"Iterating services...\n");
    usbDeviceRef=IOIteratorNext(iterator);
    while (usbDeviceRef!=IO_OBJECT_NULL) {
        IOCFPlugInInterface 		**iodev;
        SInt32 				score;
        Utils::watch_error(IOCreatePlugInInterfaceForService(usbDeviceRef, kIOUSBDeviceUserClientTypeID, kIOCFPlugInInterfaceID, &iodev, &score));
        
        IOUSBDeviceInterface ** dev;
        Utils::watch_error((*iodev)->QueryInterface(iodev, CFUUIDGetUUIDBytes(kIOUSBDeviceInterfaceID), (LPVOID *)&dev));
        
        if(!dev) {
            DLOG(LERROR,"USB device is NULL\n");
        }
        (*iodev)->Release(iodev);
        
        UInt16 vendor;
        UInt16 product;
        
        Utils::watch_error((*dev)->GetDeviceVendor(dev,&vendor));
        Utils::watch_error((*dev)->GetDeviceProduct(dev,&product));
        DLOG(LINFO,"Found device with vendor %x; product %x",vendor,product);
        int i;
        int deviceNo=-1;
        for(i=0;i<get_num_descriptions();i++) {
            UVCCameraDescription *description=get_camera_description(i);
            if(description->vendor_id== vendor && description->product_id == product) {
                deviceNo=i;
                break;
            }
        }
        if(deviceNo>=0) {
            DLOG(LINFO,"Claimed device found.\n");
            DocumentUVCCamera *newCamera=new DocumentUVCCamera(get_camera_description(deviceNo),dev);
            newCamera->set_driver(this);
            io_object_t notification;
            IOServiceAddInterestNotification(notifyPort, usbDeviceRef, kIOGeneralInterest, interestCallback, newCamera, &notification);
            cameras.push_back(newCamera);
            if(delegate!=NULL) {
                delegate->on_camera_added(cameras.size()-1);
            }
        } else {
            DLOG(LDEBUG,"Unwanted device, releasing...\n");
            (*dev)->Release(dev);
        }
        usbDeviceRef=IOIteratorNext(iterator);
    }
}
void usbdocument::DocumentUVCDriver::device_removed(io_iterator_t iterator) {
    
}

void usbdocument::DocumentUVCDriver::do_driver_loop() {
    DLOG(LDEBUG,"Starting driver...\n");
    kern_return_t kr;
    /*Getting a master port. A master port is...*/
    
    DLOG(LDEBUG,"Retrieving master port...\n");
    mach_port_t masterPort;
    kr=IOMasterPort(MACH_PORT_NULL,&masterPort);
    Utils::watch_error(kr);
    DLOG(LDEBUG,"Preparing dictionary...\n");
    CFMutableDictionaryRef matchingDict;
    matchingDict = IOServiceMatching(kIOUSBDeviceClassName);
    if (!matchingDict) {
        DLOG(LDEBUG,"Error while retrieving matching services\n");
    }
    DLOG(LDEBUG,"Preparing asynchronous notifications...\n");
    notifyPort = IONotificationPortCreate(masterPort);
    runLoopSource = IONotificationPortGetRunLoopSource(notifyPort);
    CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, kCFRunLoopDefaultMode);
    
    io_iterator_t gRawAddedIter;
    io_iterator_t gRawRemovedIter;
    unsigned int i;
    for (i=0;i<get_num_descriptions();i++) {
        UVCCameraDescription *description=get_camera_description(i);
        DLOG(LDEBUG,"Adding device description with vendor %d and product %d\n",description->vendor_id,description->product_id);
        SInt32 vendor=description->vendor_id;
        SInt32 product=description->product_id;
        CFDictionarySetValue(matchingDict, CFSTR(kUSBVendorID),
                             CFNumberCreate(kCFAllocatorDefault,
                                            kCFNumberSInt32Type, &(vendor)));
        CFDictionarySetValue(matchingDict, CFSTR(kUSBProductID),
                             CFNumberCreate(kCFAllocatorDefault,
                                            kCFNumberSInt32Type, &(product)));
        
        matchingDict = (CFMutableDictionaryRef) CFRetain(matchingDict);
        matchingDict = (CFMutableDictionaryRef) CFRetain(matchingDict);
        matchingDict = (CFMutableDictionaryRef) CFRetain(matchingDict);
        
        kr = IOServiceAddMatchingNotification(notifyPort,
                                              kIOFirstMatchNotification, matchingDict,
                                              ::device_added, this, &(gRawAddedIter));
        DLOG(LDEBUG,"Checking for already plugged-in devices...\n");
        ::device_added(this, gRawAddedIter);
        
        kr = IOServiceAddMatchingNotification(notifyPort,
                                              kIOTerminatedNotification, matchingDict,
                                              ::device_removed, this, &(gRawRemovedIter));
        ::device_removed(this, gRawRemovedIter);
        
    }
    DLOG(LINFO,"Starting driver watching...\n");
    while(!halt) {
        CFRunLoopRunInMode(kCFRunLoopDefaultMode, 1, false);
    }
    DLOG(LINFO,"Driver requested to halt, exiting...\n");
    has_started=false;
}
void usbdocument::DocumentUVCDriver::start() {
    halt=false;
    has_started=true;
    pthread_attr_t attr;
    pthread_attr_init(&attr);
    pthread_attr_setdetachstate(&attr, PTHREAD_CREATE_JOINABLE);
    pthread_t thread;
    pthread_create(&thread,&attr,usb_launch_driver,this);
}
void usbdocument::DocumentUVCDriver::add_camera_description(UVCCameraDescription *description) {
    descriptions.push_back(description);
}
UVCCameraDescription* usbdocument::DocumentUVCDriver::get_camera_description(unsigned long index) {
    return descriptions[index];
}
size_t usbdocument::DocumentUVCDriver::get_num_descriptions() {
    return descriptions.size();
}
size_t usbdocument::DocumentUVCDriver::get_num_cameras() {
    return cameras.size();
}
UVCCamera *usbdocument::DocumentUVCDriver::get_camera(unsigned long index) {
   return cameras[index];
}

void usbdocument::DocumentUVCDriver::stop() {
    halt=true;
}
bool usbdocument::DocumentUVCDriver::started() {
    return has_started;
}
void usbdocument::DocumentUVCDriver::set_delegate(UVCDriverDelegate *delegate) {
    this->delegate=delegate;
}

#pragma mark Camera methods


usbdocument::DocumentUVCCamera::DocumentUVCCamera( UVCCameraDescription *description, IOUSBDeviceInterface **device) {
    this->dev=device;
    this->description=description;
    has_started=false;
    has_opened=false;
}
void usbdocument::DocumentUVCCamera::on_interest_callback(natural_t messageType, void *messageArgument) {
    DLOG(LINFO,"Interest callback for camera\n");
    switch(messageType) {
        case kIOMessageServiceIsAttemptingOpen:
            DLOG(LINFO,"Attempting open...\n");
            break;
            
        case kIOMessageServiceIsRequestingClose:
            DLOG(LINFO,"Requesting close...\n");
            
            break;
            
        case kIOMessageServiceWasClosed:
            DLOG(LINFO,"Close completed...\n");
            
            break;
        case kIOMessageServiceIsTerminated:
            DLOG(LINFO,"Camera unplugged...\n");
            driver->on_camera_removed(this);
            break;
        default:
            DLOG(LINFO,"Ignoring unknown service message...\n");
            break;
    }
}
void usbdocument::DocumentUVCCamera::set_driver(DocumentUVCDriver *driver) {
    this->driver=driver;
}

bool usbdocument::DocumentUVCCamera::started() {
    return has_started;
}
bool usbdocument::DocumentUVCCamera::opened() {
    return has_opened;
}
bool usbdocument::DocumentUVCCamera::setup_device() {
    UInt8 numConfig;
    try {
        Utils::milli_sleep(200);
        if(dev==NULL || *dev==NULL) return false;
        if(Utils::watch_error((*dev)->USBDeviceOpen(dev))!=kIOReturnSuccess) {
            (*dev)->Release(dev);
            dev=NULL;
            throw "Unable to open device (exclusive access?)";
        }
        Utils::assert_error((*dev)->GetNumberOfConfigurations(dev,&numConfig));
        Utils::test_assert(numConfig==1,"Unexpected number of configurations for device");
        Utils::assert_error((*dev)->SetConfiguration(dev,0));
        Utils::milli_sleep(100);
        IOUSBConfigurationDescriptorPtr configDesc;
        Utils::assert_error((*dev)->GetConfigurationDescriptorPtr(dev,0,&configDesc));
        DLOG(LDEBUG,"Number of of interfaces in this configuration: %d\n",configDesc->bNumInterfaces);
        Utils::test_assert(configDesc->bNumInterfaces==2,"Unexpected number of interfaces for configuration");
        Utils::assert_error((*dev)->SetConfiguration(dev,configDesc->bConfigurationValue));
        
        UInt8 currentConfig;
        Utils::assert_error((*dev)->GetConfiguration(dev,&currentConfig));
        Utils::test_assert(currentConfig==1,"Unexpected configuration for device");
        return true;
    } catch(...) {
        DLOG(LERROR,"Error setting up device");
        return false;
    }
}
void usbdocument::DocumentUVCCamera::open_interface(unsigned long index) {
    USBINTFV **interface=interfaces[index];
    Utils::assert_error((*interface)->USBInterfaceOpen(interface));
    Utils::assert_error((*interface)->SetAlternateInterface(interface,0));
}
void usbdocument::DocumentUVCCamera::close_interface(unsigned long index) {
    USBINTFV **interface=interfaces[index];
    Utils::assert_error((*interface)->USBInterfaceClose(interface));
}
void usbdocument::DocumentUVCCamera::release_interface(unsigned long index) {
    USBINTFV **interface=interfaces[index];
    Utils::assert_error((*interface)->Release(interface));
}
void usbdocument::DocumentUVCCamera::get_interfaces() {
    io_iterator_t iit;
    IOUSBFindInterfaceRequest request;
    request.bInterfaceClass = kIOUSBFindInterfaceDontCare;
    request.bInterfaceSubClass = kIOUSBFindInterfaceDontCare;
    request.bInterfaceProtocol = kIOUSBFindInterfaceDontCare;
    request.bAlternateSetting = kIOUSBFindInterfaceDontCare;
    
    Utils::assert_error((*dev)->CreateInterfaceIterator(dev,&request,&iit));
    io_service_t usbInterface;
    DLOG(LDEBUG,"Prepare to iterate interfaces...\n");
    int ifcount=0;
    while ((usbInterface=IOIteratorNext(iit))) {
        DLOG(LDEBUG,"Preparing interface %d\n",ifcount);
        IOCFPlugInInterface **plugInInterface = NULL;
        SInt32 score;
        DLOG(LDEBUG,"Creating plugin for interface...\n");
        Utils::assert_error(IOCreatePlugInInterfaceForService(usbInterface,kIOUSBInterfaceUserClientTypeID, kIOCFPlugInInterfaceID,&plugInInterface, &score));
        //Release the usbInterface object after getting the plug-in
        Utils::assert_error(IOObjectRelease(usbInterface));
        if (!plugInInterface)
        {
            throw "Unable to create a plug-in (unknown error)";
            break;
        }
        HRESULT result;
        IOUSBInterfaceInterface220 **interface = NULL;
        //Now create the device interface for the interface
        result = (*plugInInterface)->QueryInterface(plugInInterface,CFUUIDGetUUIDBytes(kIOUSBInterfaceInterfaceID),(LPVOID *) &interface);
        //No longer need the intermediate plug-in
        (*plugInInterface)->Release(plugInInterface);
        
        if (result || !interface)
        {
            throw "Couldn’t create a device interface for the interface";
            break;
        } else {
            interfaces.push_back(interface);
            ifcount++;
        }
    }
    Utils::test_assert(ifcount==2, "Could not create all interfaces");
}
void usbdocument::DocumentUVCCamera::open() {
    if(has_opened) return;
    if(!setup_device()) return;
    get_interfaces();
    open_interface(0);
    open_interface(1);
    uvc_dev=new UVCDevice(dev,interfaces);
    UVC_VIDEO_STREAMING *streaming=uvc_dev->get_streaming_interface();
    //Create a new simplified format per streaming format;
    int i;
    for(i=0;i<streaming->bNumFormats;i++) {
        UVC_VIDEO_FORMAT *cformat=streaming->formats[i];
        int j;
        for(j=0;j<cformat->bNumFrameDescriptors;j++) {
            UVC_VIDEO_FRAME *cframe=cformat->frames[j];
            UVCFormat *format= new UVCFormat();
            format->bbp=cformat->bBitsPerPixel;
            format->width=cframe->wWidth;
            format->height=cframe->wHeight;
            format->format=MJPEG;
            format->frame_interval=cframe->dwDefaultFrameInterval;
            format->format_index=i;
            format->frame_index=j;
            formats.push_back(format);
        }
    }
    //Setup settings
    UVC_VIDEO_CONTROL *control=uvc_dev->get_control_interface();
    setup_setting_descriptions();
    setup_settings(control);
    has_opened=true;
    current_format=0;
}
void usbdocument::DocumentUVCCamera::close() {
    if(has_opened) {
        delete uvc_dev;
        has_opened=false;
        close_interface(0);
        release_interface(0);
        close_interface(1);
        release_interface(1);
        interfaces.clear();
        (*dev)->USBDeviceClose(dev);
    }
}

void usbdocument::DocumentUVCCamera::start() {
    DLOG(LDEBUG,"Starting camera");
    UVCFormat *current=get_format(current_format);
    unsigned char format=current->format_index;
    unsigned char frame=current->frame_index;
    unsigned char interval=current->frame_interval;
    //Weak negotiation to avoid problems with frame interval
    UVC_PROBE base_probe;
    bool accepted=FALSE;
    UVC_PROBE test_probe;
    uvc_dev->do_probe(format, frame, interval, &base_probe, &accepted);
    uvc_dev->do_probe(&base_probe,&test_probe, &accepted);
    memcpy(&base_probe,&test_probe,sizeof(UVC_PROBE));
    uvc_dev->do_probe(&base_probe,&test_probe, &accepted);
    while(!accepted) {
        uvc_dev->do_probe(&base_probe,&test_probe, &accepted);
        memcpy(&base_probe,&test_probe,sizeof(UVC_PROBE));
    }
    uvc_dev->set_probe(&base_probe);
    uvc_dev->commit_probe();
    //Set alternate setting 1 for interface 1
    Utils::assert_error((*interfaces[1])->SetAlternateInterface(interfaces[1],1));
    //Create a sync buffer manager
    syncBufferManager=new SyncBufferManager();
    //Create new isoch reader
    isochReader=new IsochReader(interfaces[1],3,this,false);
    isochReader->start();
    isochParser=new UVCIsochParser(get_format(current_format),syncBufferManager,this);
    isochParser->start();
    interruptReader=new InterruptReader(interfaces[0],1,8,this);
    interruptReader->start();
    has_started=true;
}
void usbdocument::DocumentUVCCamera::on_isoch_succeeded(IsochReader *reader, unsigned char * buffer, UInt64 actual_size) {
    this->syncBufferManager->add_buffer(buffer, actual_size);
}
void usbdocument::DocumentUVCCamera::on_interrupt_read(InterruptReader *reader,unsigned char *data,  UInt64 size) {
    DLOG(LFATAL,"Interrupt read with size: %llu",size);
    UInt64 i;
    for(i=0;i<size;i++) {
        DLOG(LFATAL,"%d,",data[i]);
    }
    DLOG(LFATAL,"\n");
    delegate->on_interrupt();
}
void usbdocument::DocumentUVCCamera::on_isoch_error(IsochReader *reader) {

}
void usbdocument::DocumentUVCCamera::stop() {
    DLOG(LDEBUG,"Stopping camera");
    isochParser->stop();
    isochReader->stop();
    interruptReader->stop();
    Utils::assert_error((*interfaces[1])->SetAlternateInterface(interfaces[1],0));
    delete isochReader;
    delete isochParser;
    delete syncBufferManager;
    delete interruptReader;
    has_started=false;
}
void usbdocument::DocumentUVCCamera::set_delegate(UVCCameraDelegate *delegate) {
    this->delegate=delegate;
}
UVCCameraDescription * usbdocument::DocumentUVCCamera::get_description() {
    return description;
}

#pragma mark Formats and Settings pending
size_t usbdocument::DocumentUVCCamera::get_num_formats() {
    if(!has_opened) {
        throw "Camera must be opened before retrieving formats";
    }
    return formats.size();}
UVCFormat *usbdocument::DocumentUVCCamera::get_format(int index) {
    if(!has_opened) {
        throw "Camera must be opened before retrieving formats";
    }
    return formats[index];
}
void usbdocument::DocumentUVCCamera::set_format(int index) {
    current_format=index;
}

void usbdocument::DocumentUVCCamera::on_new_frame(unsigned char *buffer, UInt64 size) {
   // DLOG(LINFO,"NEW FRAME ARRIVED WITH SIZE: %llu!!!!!",size);
    delegate->on_new_frame(buffer, size);
}
size_t usbdocument::DocumentUVCCamera::get_num_settings() {
    return settings.size();
}
UVCSetting usbdocument::DocumentUVCCamera::get_setting(int index) {
    return settings[index];
}
void usbdocument::DocumentUVCCamera::set_setting(int index, SInt32 value) {
    UVC_ENTITY entity;
    settings[index].curr=value;
    memset(&entity,0,sizeof(UVC_ENTITY));
    entity.entity=settings[index].entity;
    entity.set=value;
    uvc_dev->uvc_set_entity(&entity,settings[index].unit,settings[index].length);
}

void usbdocument::DocumentUVCCamera::setup_settings(UVC_VIDEO_CONTROL *control) {
    settings.clear();
    /*Processing unit*/
    if(control->pu->brightness) {
        add_setting_with_type(UVC_BRIGHTNESS, control->pu->uid);
    }
    if(control->pu->contrast) {
        add_setting_with_type(UVC_CONTRAST, control->pu->uid);
    }
    if(control->pu->hue) {
        add_setting_with_type(UVC_HUE, control->pu->uid);
    }
    if(control->pu->saturation) {
        add_setting_with_type(UVC_SATURATION, control->pu->uid);
    }
    if(control->pu->sharpness) {
        add_setting_with_type(UVC_SHARPNESS, control->pu->uid);
    }
    if(control->pu->gamma) {
        add_setting_with_type(UVC_GAMMA, control->pu->uid);
    }
    if(control->pu->whiteBalanceTemperature) {
        //add_setting_with_type(UVC_WHITE_BALANCE_TEMPERATURE, control->pu->uid);
    }
    if(control->pu->backlightCompensantion) {
        //add_setting_with_type(UVC_BACKLIGHT_COMPENSATION, control->pu->uid);
    }
    if(control->pu->gain) {
        //add_setting_with_type(UVC_GAIN, control->pu->uid);
    }
    if(control->pu->powerLineFrequency) {
        //add_setting_with_type(UVC_POWER_LINE_FREQUENCY, control->pu->uid);
    }
    if(control->pu->whiteBalanceTemperatureAuto) {
        //add_setting_with_type(UVC_WHITE_BALANCE_TEMPERATURE_AUTO, control->pu->uid);
    }
    /*Input terminal*/
    if(control->it->autoExposureMode) {
        //add_setting_with_type(UVC_AUTO_EXPOSURE_MODE, control->it->tid);

    }
    if(control->it->autoExposurePriority) {
        //add_setting_with_type(UVC_AUTO_EXPOSURE_PRIORITY, control->it->tid);
    }
    if(control->it->exposureTimeAbsolute) {
        //add_setting_with_type(UVC_EXPOSURE_TIME_ABSOLUTE, control->it->tid);
    }
    if(control->it->focusAbsolute) {
        //add_setting_with_type(UVC_FOCUS_ABSOLUTE, control->it->tid);
    }
    if(control->it->focusAuto) {
        add_setting_with_type(UVC_FOCUS_AUTO, control->it->tid);
    }
}
void usbdocument::DocumentUVCCamera::add_setting_with_type(UVC_SETTING_TYPE type,UInt8 unit) {
    int description_index=get_description_index_by_type(type);
    UVCSettingDescription description=get_setting_description(description_index);
    UVCSetting setting;
    UVC_ENTITY entity;
    memset(&entity,0,sizeof(UVC_ENTITY));
    entity.entity=description.entity;
    UVC_ENTITY_CAP capabilities;
    memset(&capabilities,0,sizeof(UVC_ENTITY_CAP));
    capabilities.supports_get_curr=description.supports_get_curr;
    capabilities.supports_set_curr=description.supports_set_curr;
    capabilities.supports_get_min=description.supports_get_min;
    capabilities.supports_get_max=description.supports_get_max;
    capabilities.supports_get_res=description.supports_get_res;
    capabilities.supports_get_def=description.supports_get_def;
    capabilities.supports_get_info=description.supports_get_info;
    capabilities.length=description.length;
    uvc_dev->uvc_get_entity(&entity, unit,&capabilities);
    if(description.supports_get_min) {
        setting.min=entity.min;
    } else {
        setting.min=description.def_min;
    }
    if(description.supports_get_max) {
        setting.max=entity.max;
    } else {
        setting.max=description.def_max;
    }
    if(description.supports_get_curr) {
        setting.curr=entity.cur;
    } else {
        setting.curr=0;
    }
    if(description.supports_get_def) {
        setting.def=entity.def;
    } else {
        setting.curr=description.def_def;
    }
    setting.type=type;
    setting.entity=description.entity;
    setting.length=description.length;
    setting.unit=unit;
    /*if(type==UVC_FOCUS_ABSOLUTE) {
        setting.max=65536;
    }*/
    settings.push_back(setting);
}
void usbdocument::DocumentUVCCamera::setup_setting_descriptions() {
    descriptions.clear();

    UVCSettingDescription description=UVCSettingDescription();
    description.type=UVC_BACKLIGHT_COMPENSATION;
    description.entity=PU_BACKLIGHT_COMPENSATION_CONTROL;
    description.length=2;
    description.supports_get_curr=true;
    description.supports_set_curr=true;
    description.supports_get_min=true;
    description.supports_get_max=true;
    description.supports_get_def=true;
    description.supports_get_res=true;
    description.supports_get_info=true;
    description.def_min=0;
    description.def_max=0;
    description.def_def=0;
    description.def_res=0;
    description.def_info=0;
    descriptions.push_back(description);
    
    description=UVCSettingDescription();
    description.type=UVC_BRIGHTNESS;
    description.entity=PU_BRIGHTNESS_CONTROL;
    description.length=2;
    description.supports_get_curr=true;
    description.supports_set_curr=true;
    description.supports_get_min=true;
    description.supports_get_max=true;
    description.supports_get_def=true;
    description.supports_get_res=true;
    description.supports_get_info=true;
    description.def_min=0;
    description.def_max=0;
    description.def_def=0;
    description.def_res=0;
    description.def_info=0;
    descriptions.push_back(description);

    description=UVCSettingDescription();
    description.type=UVC_CONTRAST;
    description.entity=PU_CONTRAST_CONTROL;
    description.length=2;
    description.supports_get_curr=true;
    description.supports_set_curr=true;
    description.supports_get_min=true;
    description.supports_get_max=true;
    description.supports_get_def=true;
    description.supports_get_res=true;
    description.supports_get_info=true;
    description.def_min=0;
    description.def_max=0;
    description.def_def=0;
    description.def_res=0;
    description.def_info=0;
    descriptions.push_back(description);

    description=UVCSettingDescription();
    description.type=UVC_GAIN;
    description.entity=PU_GAIN_CONTROL;
    description.length=2;
    description.supports_get_curr=true;
    description.supports_set_curr=true;
    description.supports_get_min=true;
    description.supports_get_max=true;
    description.supports_get_def=true;
    description.supports_get_res=true;
    description.supports_get_info=true;
    description.def_min=0;
    description.def_max=0;
    description.def_def=0;
    description.def_res=0;
    description.def_info=0;
    descriptions.push_back(description);
    
    //0 disabled, 1 50hz, 2 60hz
    description=UVCSettingDescription();
    description.type=UVC_POWER_LINE_FREQUENCY;
    description.entity=PU_POWER_LINE_FREQUENCY_CONTROL;
    description.length=1;
    description.supports_get_curr=true;
    description.supports_set_curr=true;
    description.supports_get_min=false;
    description.supports_get_max=false;
    description.supports_get_def=true;
    description.supports_get_res=false;
    description.supports_get_info=true;
    description.def_min=0;
    description.def_max=2;
    description.def_def=0;
    description.def_res=0;
    description.def_info=0;
    descriptions.push_back(description);

    description=UVCSettingDescription();
    description.type=UVC_HUE;
    description.entity=PU_HUE_CONTROL;
    description.length=2;
    description.supports_get_curr=true;
    description.supports_set_curr=true;
    description.supports_get_min=true;
    description.supports_get_max=true;
    description.supports_get_def=true;
    description.supports_get_res=true;
    description.supports_get_info=true;
    description.def_min=0;
    description.def_max=0;
    description.def_def=0;
    description.def_res=0;
    description.def_info=0;
    descriptions.push_back(description);
    
    description=UVCSettingDescription();
    description.type=UVC_SATURATION;
    description.entity=PU_SATURATION_CONTROL;
    description.length=2;
    description.supports_get_curr=true;
    description.supports_set_curr=true;
    description.supports_get_min=true;
    description.supports_get_max=true;
    description.supports_get_def=true;
    description.supports_get_res=true;
    description.supports_get_info=true;
    description.def_min=0;
    description.def_max=0;
    description.def_def=0;
    description.def_res=0;
    description.def_info=0;
    descriptions.push_back(description);
    
    description=UVCSettingDescription();
    description.type=UVC_SHARPNESS;
    description.entity=PU_SHARPNESS_CONTROL;
    description.length=2;
    description.supports_get_curr=true;
    description.supports_set_curr=true;
    description.supports_get_min=true;
    description.supports_get_max=true;
    description.supports_get_def=true;
    description.supports_get_res=true;
    description.supports_get_info=true;
    description.def_min=0;
    description.def_max=0;
    description.def_def=0;
    description.def_res=0;
    description.def_info=0;
    descriptions.push_back(description);
    
    description=UVCSettingDescription();
    description.type=UVC_GAMMA;
    description.entity=PU_GAMMA_CONTROL;
    description.length=2;
    description.supports_get_curr=true;
    description.supports_set_curr=true;
    description.supports_get_min=true;
    description.supports_get_max=true;
    description.supports_get_def=true;
    description.supports_get_res=true;
    description.supports_get_info=true;
    description.def_min=0;
    description.def_max=0;
    description.def_def=0;
    description.def_res=0;
    description.def_info=0;
    descriptions.push_back(description);
    
    description=UVCSettingDescription();
    description.type=UVC_WHITE_BALANCE_TEMPERATURE;
    description.entity=PU_WHITE_BALANCE_TEMPERATURE_CONTROL;
    description.length=2;
    description.supports_get_curr=true;
    description.supports_set_curr=true;
    description.supports_get_min=true;
    description.supports_get_max=true;
    description.supports_get_def=true;
    description.supports_get_res=true;
    description.supports_get_info=true;
    description.def_min=0;
    description.def_max=0;
    description.def_def=0;
    description.def_res=0;
    description.def_info=0;
    descriptions.push_back(description);
    
    description=UVCSettingDescription();
    description.type=UVC_WHITE_BALANCE_TEMPERATURE_AUTO;
    description.entity=PU_WHITE_BALANCE_TEMPERATURE_AUTO_CONTROL;
    description.length=1;
    description.supports_get_curr=true;
    description.supports_set_curr=true;
    description.supports_get_min=false;
    description.supports_get_max=false;
    description.supports_get_def=true;
    description.supports_get_res=false;
    description.supports_get_info=true;
    description.def_min=0;
    description.def_max=1;
    description.def_def=0;
    description.def_res=0;
    description.def_info=0;
    descriptions.push_back(description);
    
    description=UVCSettingDescription();
    description.type=UVC_AUTO_EXPOSURE_MODE;
    description.entity=CT_AE_MODE_CONTROL;
    description.length=1;
    description.supports_get_curr=true;
    description.supports_set_curr=true;
    description.supports_get_min=false;
    description.supports_get_max=false;
    description.supports_get_def=true;
    //returns bitmap of supported
    description.supports_get_res=true;
    description.supports_get_info=true;
    description.def_min=0;
    description.def_max=0;
    description.def_def=0;
    description.def_res=0;
    description.def_info=0;
    descriptions.push_back(description);
    
    description=UVCSettingDescription();
    description.type=UVC_AUTO_EXPOSURE_PRIORITY;
    description.entity=CT_AE_PRIORITY_CONTROL;
    description.length=1;
    description.supports_get_curr=true;
    description.supports_set_curr=true;
    description.supports_get_min=false;
    description.supports_get_max=false;
    description.supports_get_def=false;
    //returns bitmap of supported
    description.supports_get_res=false;
    description.supports_get_info=true;
    description.def_min=0;
    description.def_max=1;
    description.def_def=0;
    description.def_res=0;
    description.def_info=0;
    descriptions.push_back(description);
    
    description=UVCSettingDescription();
    description.type=UVC_EXPOSURE_TIME_ABSOLUTE;
    description.entity=CT_EXPOSURE_TIME_ABSOLUTE_CONTROL;
    description.length=4;
    description.supports_get_curr=true;
    description.supports_set_curr=true;
    description.supports_get_min=true;
    description.supports_get_max=true;
    description.supports_get_def=true;
    description.supports_get_res=true;
    description.supports_get_info=true;
    description.def_min=0;
    description.def_max=0;
    description.def_def=0;
    description.def_res=0;
    description.def_info=0;
    descriptions.push_back(description);
    
    description=UVCSettingDescription();
    description.type=UVC_FOCUS_ABSOLUTE;
    description.entity=CT_FOCUS_ABSOLUTE_CONTROL;
    description.length=2;
    description.supports_get_curr=true;
    description.supports_set_curr=true;
    description.supports_get_min=true;
    description.supports_get_max=true;
    description.supports_get_def=true;
    description.supports_get_res=true;
    description.supports_get_info=true;
    description.def_min=0;
    description.def_max=0;
    description.def_def=0;
    description.def_res=0;
    description.def_info=0;
    descriptions.push_back(description);
    
    description=UVCSettingDescription();
    description.type=UVC_FOCUS_AUTO;
    description.entity=CT_FOCUS_AUTO_CONTROL;
    description.length=1;
    description.supports_get_curr=true;
    description.supports_set_curr=true;
    description.supports_get_min=false;
    description.supports_get_max=false;
    description.supports_get_def=true;
    description.supports_get_res=false;
    description.supports_get_info=true;
    description.def_min=0;
    description.def_max=1;
    description.def_def=0;
    description.def_res=0;
    description.def_info=0;
    descriptions.push_back(description);

}
size_t usbdocument::DocumentUVCCamera::get_num_setting_descriptions() {
    return descriptions.size();
}
UVCSettingDescription usbdocument::DocumentUVCCamera::get_setting_description(int index) {
    return descriptions[index];
}
void usbdocument::DocumentUVCCamera::restore_default_settings() {
    int i;
    for(i=0;i<get_num_settings();i++) {
        UVCSetting setting=get_setting(i);
        set_setting(i, setting.def);
    }
}
int usbdocument::DocumentUVCCamera::get_description_index_by_type(UVC_SETTING_TYPE type) {
    int i;
    for(i=0;i<get_num_setting_descriptions();i++) {
        UVCSettingDescription d=descriptions[i];
        if(d.type==type) return i;
    }
    return -1;
}
int usbdocument::DocumentUVCCamera::get_setting_index_by_type(UVC_SETTING_TYPE type) {
    int i;
    for(i=0;i<get_num_settings();i++) {
        UVCSetting s=settings[i];
        if(s.type==type) return i;
    }
    return -1;
}

