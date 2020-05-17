//
//  UsbDocumentUVCDriver.h
//  usbdocumentlib
//
//  Created by Aldo Ilsant on 20/10/15.
//  Copyright © 2015 aldoilsant. All rights reserved.
//

#ifndef usbdocumentlib_USBDocumentUVCDriver_h
#define usbdocumentlib_USBDocumentUVCDriver_h

#include <vector>
#include "usbdocumentlib.hpp"
#include <IOKit/usb/IOUSBLib.h>
#include "Utils.hpp"
#include "UVCUtils.hpp"
#include "IsochReader.hpp"
#include "SyncBuffer.hpp"
#include "UVCIsochParser.hpp"
#include "InterruptReader.hpp"

using std::vector;

namespace usbdocument {
    
    class DocumentUVCCamera;
    
    class DocumentUVCDriver : public UVCDriver {
    private:
        vector<usbdocument::DocumentUVCCamera *> cameras;
        vector<usbdocument::UVCCameraDescription *> descriptions;
        CFRunLoopSourceRef runLoopSource;
        IONotificationPortRef notifyPort;
        bool halt;
        bool has_started=false;
        UVCDriverDelegate *delegate;
        
    public:
        void start();
        void stop();
        bool started();
        void set_delegate(UVCDriverDelegate *delegate);
        size_t get_num_cameras();
        UVCCamera *get_camera(unsigned long index);
        void add_camera_description(UVCCameraDescription *description);
        UVCCameraDescription *get_camera_description(unsigned long index);
        size_t get_num_descriptions();
        void do_driver_loop();
        void device_added(io_iterator_t iterator);
        void device_removed(io_iterator_t iterator);
        void on_camera_removed(DocumentUVCCamera * camera);
    };
    
    class DocumentUVCCamera : public UVCCamera, public IsochReaderDelegate, public UVCIsochParserDelegate, public InterruptReaderDelegate{
    private:
        bool has_started;
        bool has_opened;
        DocumentUVCDriver *driver;
        IOUSBDeviceInterface ** dev;
        UVCCameraDescription *description;
        UVCCameraDelegate *delegate;
        vector<USBINTFV**> interfaces;
        UVCDevice *uvc_dev;
        vector<UVCFormat *> formats;
        int current_format;
        SyncBufferManager *syncBufferManager;
        IsochReader *isochReader;
        UVCIsochParser *isochParser;
        InterruptReader *interruptReader;
        vector<UVCSetting> settings;
        vector<UVCSettingDescription> descriptions;

    protected:
        bool setup_device();
        void open_interface(unsigned long index);
        void close_interface(unsigned long index);
        void release_interface(unsigned long index);
        void get_interfaces();
        void setup_settings(UVC_VIDEO_CONTROL *control);
        void add_setting_with_type(UVC_SETTING_TYPE type,UInt8 unit);
        
    public:
        DocumentUVCCamera( UVCCameraDescription *description, IOUSBDeviceInterface **device);
        void on_interest_callback(natural_t messageType, void *messageArgument);
        void set_driver(DocumentUVCDriver *driver);
        //Open, start
        void start();
        void stop();
        bool started();
        void open();
        void close();
        bool opened();
        //Requested methods from superclass
        void set_delegate(UVCCameraDelegate *delegate);
        UVCCameraDescription *get_description();
        size_t get_num_formats();
        UVCFormat *get_format(int index);
        void set_format(int index);
        size_t get_num_settings();
        UVCSetting get_setting(int index);
        void set_setting(int index, SInt32 value);
        
        void setup_setting_descriptions();
        size_t get_num_setting_descriptions();
        UVCSettingDescription get_setting_description(int index);
        int get_description_index_by_type(UVC_SETTING_TYPE type);
        int get_setting_index_by_type(UVC_SETTING_TYPE type);
        void restore_default_settings();
        
        //Internal
        void on_isoch_succeeded(IsochReader *reader, unsigned char * buffer, UInt64 actual_size);
        void on_isoch_error(IsochReader *reader);
        void on_new_frame(unsigned char *buffer, UInt64 size);
        void on_interrupt_read(InterruptReader *reader,unsigned char *data,  UInt64 size);

    };

}


#endif