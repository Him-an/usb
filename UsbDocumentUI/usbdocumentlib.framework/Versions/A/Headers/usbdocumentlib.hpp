//
//  usbdocumentlib.h
//  usbdocumentlib
//
//  Created by Aldo Ilsant on 20/10/15.
//  Copyright © 2015 aldoilsant. All rights reserved.
//

#ifndef usbdocumentlib_usbdocumentlib_h
#define usbdocumentlib_usbdocumentlib_h
#import <Cocoa/Cocoa.h>

//! Project version number for usbdocumentlib.
FOUNDATION_EXPORT double usbdocumentlibVersionNumber;

//! Project version string for usbdocumentlib.
FOUNDATION_EXPORT const unsigned char usbdocumentlibVersionString[];

// In this header, you should import all the public headers of your framework using statements like #import <usbdocumentlib/PublicHeader.h>


namespace usbdocument {
    
    class UVCamera;
    
    class UVCCameraDelegate{
    public:
        virtual void on_new_frame(unsigned char * buffer, UInt64 size)=0;
        virtual void on_interrupt()=0;
    };
    
    class UVCCameraDescription {
    public:
        UInt16 vendor_id;
        UInt16 product_id;
        UVCCameraDescription(UInt16 vendor_id, UInt16 product_id);
        UInt16 get_vendor_id();
        UInt16 get_product_id();
        
    };
    enum UVCVideoFormat {
        YUV2,
        RGB,
        RGB_BW,
        MJPEG
    };
    class UVCFormat {
    public:
        unsigned int width;
        unsigned int height;
        unsigned int bbp;
        unsigned int frame_interval;
        UVCVideoFormat format;
        int format_index;
        int frame_index;
    };
    
    typedef enum e_uvc_setting_type {
        UVC_BRIGHTNESS,
        UVC_CONTRAST,
        UVC_HUE,
        UVC_SATURATION,
        UVC_SHARPNESS,
        UVC_GAMMA,
        UVC_WHITE_BALANCE_TEMPERATURE,
        UVC_BACKLIGHT_COMPENSATION,
        UVC_GAIN,
        UVC_POWER_LINE_FREQUENCY,
        UVC_WHITE_BALANCE_TEMPERATURE_AUTO,
        UVC_AUTO_EXPOSURE_MODE,
        UVC_AUTO_EXPOSURE_PRIORITY,
        UVC_EXPOSURE_TIME_ABSOLUTE,
        UVC_FOCUS_ABSOLUTE,
        UVC_FOCUS_AUTO
    } UVC_SETTING_TYPE;

    class UVCSettingDescription {
    public:
        UVC_SETTING_TYPE type;
        UInt8 entity;
        bool supports_get_curr;
        bool supports_set_curr;
        bool supports_get_min;
        bool supports_get_max;
        bool supports_get_def;
        bool supports_get_res;
        bool supports_get_info;
        UInt32 def_min;
        UInt32 def_max;
        UInt32 def_def;
        UInt32 def_res;
        UInt32 def_info;
        UInt16 length;
    };
    class UVCSetting {
    public:
        UVC_SETTING_TYPE type;
        SInt32 min;
        SInt32 max;
        SInt32 curr;
        SInt32 def;
        UInt8 entity;
        UInt8 unit;
        SInt32 length;
    };
    
    class UVCCamera {
    public:
        virtual void open()=0;
        virtual void start()=0;
        virtual void stop()=0;
        virtual void close()=0;
        virtual bool started()=0;
        virtual bool opened()=0;
        virtual void set_delegate(UVCCameraDelegate *delegate)=0;
        virtual UVCCameraDescription *get_description()=0;
        virtual size_t get_num_formats()=0;
        virtual UVCFormat *get_format(int index)=0;
        virtual void set_format(int index)=0;
        virtual size_t get_num_settings()=0;
        virtual UVCSetting get_setting(int index)=0;
        virtual void set_setting(int index, SInt32 value)=0;
        virtual size_t get_num_setting_descriptions()=0;
        virtual UVCSettingDescription get_setting_description(int index)=0;
        virtual void restore_default_settings()=0;
        virtual int get_description_index_by_type(UVC_SETTING_TYPE type)=0;
        virtual int get_setting_index_by_type(UVC_SETTING_TYPE type)=0;
    };
    
    class UVCDriverDelegate {
    public:
        virtual void on_camera_added(unsigned long index)=0;
        virtual void on_camera_removed(unsigned long index)=0;
    };
    
    class UVCDriver {
    public:
        virtual void start()=0;
        virtual void stop()=0;
        virtual bool started()=0;
        virtual size_t get_num_cameras()=0;
        virtual UVCCamera *get_camera(unsigned long index)=0;
        virtual void set_delegate(UVCDriverDelegate *delegate)=0;
        virtual void add_camera_description(UVCCameraDescription *description)=0;
        virtual UVCCameraDescription *get_camera_description(unsigned long index)=0;
        virtual size_t get_num_descriptions()=0;
    };

}

#endif