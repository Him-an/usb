//
//  UVCUtils.h
//  usbdocumentlib
//
//  Created by Aldo Ilsant on 20/10/15.
//  Copyright © 2015 aldoilsant. All rights reserved.
//

#ifndef usbdocumentlib_UVCUtils_h
#define usbdocumentlib_UVCUtils_h
#import <Foundation/Foundation.h>
#include <IOKit/usb/IOUSBLib.h>
#include <vector>
#import "Utils.hpp"
#include<pthread.h>

using std::vector;


#define INTERFACE_CLASS_VIDEO 0x0e
#define INTERFACE_SUBCLASS_STREAMING 0x02
#define INTERFACE_SUBCLASS_CONTROL 0x01

#define DESCRIPTOR_TYPE_INTERFACE 0x04
#define CS_INTERFACE 0X24
#define VC_HEADER 0x01
#define VC_INPUT_TERMINAL 0x02
#define VC_OUTPUT_TERMINAL 0x03
#define VC_SELECTOR_UNIT 0x04
#define VC_PROCESSING_UNIT 0x05
#define VC_EXTENSION_UNIT 0x06

#define VS_INPUT_HEADER 0x01
#define VS_FORMAT_UNCOMPRESSED 0x04
#define VS_FRAME_UNCOMPRESSED 0x05
#define VS_FORMAT_MJPEG 0x06
#define VS_FRAME_MJPEG 0x07

#define VS_COLORFORMAT 0x0d


#define GET_UINT16(Buf,Index) (USBToHostWord(*(UInt16 *)&(Buf[Index])))
#define GET_UINT32(Buf,Index) (USBToHostLong(*(UInt32 *)&(Buf[Index])))
#define SET_UINT32(Integer) (HostToUSBLong(Integer))
#define SET_UINT16(Integer) (HostToUSBWord(Integer))


#define REQUEST_SET_CUR 0x01
#define REQUEST_GET_CUR 0x81
#define REQUEST_GET_MIN 0x82
#define REQUEST_GET_MAX 0x83
#define REQUEST_GET_RES 0x84
#define REQUEST_GET_LEN 0x85
#define REQUEST_GET_INFO 0x86
#define REQUEST_GET_DEF 0X87

#define CT_CONTROL_UNDEFINED		0x00
#define CT_SCANNING_MODE_CONTROL		0x01
#define CT_AE_MODE_CONTROL			0x02
#define CT_AE_PRIORITY_CONTROL		0x03
#define CT_EXPOSURE_TIME_ABSOLUTE_CONTROL	0x04
#define CT_EXPOSURE_TIME_RELATIVE_CONTROL	0x05
#define CT_FOCUS_ABSOLUTE_CONTROL		0x06
#define CT_FOCUS_RELATIVE_CONTROL		0x07
#define CT_FOCUS_AUTO_CONTROL		0x08
#define CT_IRIS_ABSOLUTE_CONTROL		0x09
#define CT_IRIS_RELATIVE_CONTROL		0x0A
#define CT_ZOOM_ABSOLUTE_CONTROL 		0x0B
#define CT_ZOOM_RELATIVE_CONTROL		0x0C
#define CT_PANTILT_ABSOLUTE_CONTROL		0x0D
#define CT_PANTILT_RELATIVE_CONTROL		0x0E
#define CT_ROLL_ABSOLUTE_CONTROL	 0x0F
#define CT_ROLL_RELATIVE_CONTROL		0x10

#define PU_CONTROL_UNDEFINED		0x00
#define PU_BACKLIGHT_COMPENSATION_CONTROL	0x01
#define PU_BRIGHTNESS_CONTROL		0x02
#define PU_CONTRAST_CONTROL			0x03
#define PU_GAIN_CONTROL			0x04
#define PU_POWER_LINE_FREQUENCY_CONTROL	0x05
#define PU_HUE_CONTROL			0x06
#define PU_SATURATION_CONTROL		0x07
#define PU_SHARPNESS_CONTROL		0x08
#define PU_GAMMA_CONTROL			0x09
#define PU_WHITE_BALANCE_TEMPERATURE_CONTROL	0x0A
#define PU_WHITE_BALANCE_TEMPERATURE_AUTO_CONTROL	0x0B
#define PU_WHITE_BALANCE_COMPONENT_CONTROL		0x0
#define PU_WHITE_BALANCE_COMPONENT_AUTO_CONTROL	0x0D
#define PU_DIGITAL_MULTIPLIER_CONTROL		0x0E
#define PU_DIGITAL_MULTIPLIER_LIMIT_CONTROL		0x0F
#define PU_HUE_AUTO_CONTROL				0x10
#define PU_ANALOG_VIDEO_STANDARD_CONTROL 0x11


#define VS_PROBE_CONTROL 0x01
#define VS_COMMIT_CONTROL 0X02

#pragma pack(1)

typedef struct s_uvc_probe {
    UInt16 bmHint;
    UInt8 bFormatIndex;
    UInt8 bFrameIndex;
    UInt32 dwFrameInterval;
    UInt16 wKeyFrameRate;
    UInt16 wPFrameRate;
    UInt16 wCompQuality;
    UInt16 wCompWindowSize;
    UInt16 wDelay;
    UInt32 dwMaxVideoFrameSize;
    UInt32 dwMaxPayloadTransferSize;
    UInt32 wdClockFrequency;
    UInt8 bmFramingInfo;
    UInt8 bPreferedVersion;
    UInt8 bMinVersion;
    UInt8 bMaxVersion;
} UVC_PROBE;

#pragma options align=reset

#pragma pack(1)

typedef struct s_uvc_decode_header {
    UInt8 bHeaderLength;
    UInt8 bFrameId;
    UInt8 bEndOfFrame;
    UInt8 bPresentationTime;
    UInt8 bSourceClockReference;
    UInt8 bPayload;
    UInt8 bStillImage;
    UInt8 bError;
    UInt8 bEndOfHeader;
    UInt32 dwPresentationTime;
    UInt32 srcSourceClock;
} UVC_DECODE_HEADER;

#pragma options align=reset

#pragma pack(1)
typedef struct s_uvc_input_terminal {
    UInt8 tid;
    UInt8 scanningMode;
    UInt8 autoExposureMode;
    UInt8 autoExposurePriority;
    UInt8 exposureTimeAbsolute;
    UInt8 exposureTimeRelative;
    UInt8 focusAbsolute;
    UInt8 focusRelative;
    UInt8 irisAbsolute;
    UInt8 irisRelative;
    UInt8 zoomAbsolute;
    UInt8 zoomRelative;
    UInt8 panTiltAbsolute;
    UInt8 panTiltRelative;
    UInt8 rollAbsolute;
    UInt8 rollRelative;
    UInt8 focusAuto;
    UInt8 privacy;
} UVC_INPUT_TERMINAL;
#pragma options align=reset

#pragma pack(1)
typedef struct s_ucv_processing_unit {
    UInt8 uid;
    UInt8 brightness;
    UInt8 contrast;
    UInt8 hue;
    UInt8 saturation;
    UInt8 sharpness;
    UInt8 gamma;
    UInt8 whiteBalanceTemperature;
    UInt8 whiteBalanceComponent;
    UInt8 backlightCompensantion;
    UInt8 gain;
    UInt8 powerLineFrequency;
    UInt8 hueAuto;
    UInt8 whiteBalanceTemperatureAuto;
    UInt8 whiteBalanceComponentAuto;
    UInt8 digitalMultiplier;
    UInt8 digitalMultiplierLimit;
    UInt8 analogVideoStandard;
    UInt8 analogVideLockStatus;
    UInt8 contrastAuto;
    UInt8 vsNone;
    UInt8 ntsc525;
    UInt8 pal625;
    UInt8 secam;
    UInt8 ntsc625;
    UInt8 pal525;
} UVC_PROCESSING_UNIT;

#pragma options align=reset

#pragma pack(1)

typedef struct s_uvc_output_terminal {
    UInt8 tid;
} UVC_OUTPUT_TERMINAL;
#pragma options align=reset

#pragma pack(1)

typedef struct s_uvc_selector_unit {
    UInt8 tid;
} UVC_SELECTOR_UNIT;
#pragma options align=reset

typedef struct s_uvc_video_control {
    UInt16 uvc;
    UInt32 clockFrequency;
    UVC_INPUT_TERMINAL *it;
    UVC_OUTPUT_TERMINAL *ot;
    UVC_PROCESSING_UNIT *pu;
    UVC_SELECTOR_UNIT *su;
} UVC_VIDEO_CONTROL;

#pragma pack(1)
typedef struct s_uvc_video_color_format {
    UInt8 bColorPrimaries;
    UInt8 bTransferCharacteristics;
    UInt8 bMatrixCoefficients;
} UVC_VIDEO_COLOR_FORMAT;
#pragma options align=reset

typedef struct s_uvc_video_frame {
    UInt8 bFrameIndex;
    UInt8 bmCapabilities;
    UInt16 wWidth;
    UInt16 wHeight;
    UInt32 dwMinBitRate;
    UInt32 dwMaxBitRate;
    UInt32 dwMaxVideoFrameBufferSize;
    UInt32 dwDefaultFrameInterval;
    UInt8 bFrameIntervalType;
    UInt32 dwMinFrameInterval;
    UInt32 dwMaxFrameInterval;
    UInt32 dwFrameIntervalStep;
    UInt32 *dwFrameIntervals;
} UVC_VIDEO_FRAME;

typedef struct s_uvc_video_format {
    UInt8 bFormatIndex;
    UInt8 bNumFrameDescriptors;
    UInt8 bBitsPerPixel;
    UVC_VIDEO_FRAME **frames;
    UVC_VIDEO_COLOR_FORMAT *colorFormat;
} UVC_VIDEO_FORMAT;

typedef struct s_uvc_video_streaming {
    UInt8 bNumFormats;
    UInt8 bEndpointAddress;
    UInt8 bTriggerSupport;
    UInt8 bTriggerUsage;
    UInt8 bControlSize;
    UVC_VIDEO_FORMAT **formats;
} UVC_VIDEO_STREAMING;

typedef struct s_uvc_entity {
    UInt8 entity;
    SInt32 min;
    SInt32 max;
    SInt32 res;
    SInt32 set;
    SInt32 cur;
    SInt32 def;
} UVC_ENTITY;

typedef struct s_uvc_entity_cap {
    UInt8 supports_get_curr;
    UInt8 supports_set_curr;
    UInt8 supports_get_min;
    UInt8 supports_get_max;
    UInt8 supports_get_def;
    UInt8 supports_get_res;
    UInt8 supports_get_info;
    UInt32 length;
} UVC_ENTITY_CAP;

namespace usbdocument {
    class UVCUtils {
    public:
        static IOReturn decode_header(unsigned char *buffer, UVC_DECODE_HEADER *header);
    };
    class UVCDevice {
    private:
        IOUSBDeviceInterface **dev;
        vector<USBINTFV**> interfaces;
        UVC_VIDEO_CONTROL *control;
        UVC_VIDEO_STREAMING *streaming;
        UVC_PROBE *probe;
        
    protected:
        void parse_descriptors(unsigned char *data, UInt16 length);
        IOReturn parse_control_interface(unsigned char *data, unsigned int length, UVC_VIDEO_CONTROL **ret);
        IOReturn parse_streaming_interface(unsigned char *data, unsigned int length, UVC_VIDEO_STREAMING **ret);
        IOReturn init_probe();
        IOReturn do_control_request(UInt8 request, UInt8 unit, UInt8 selector, unsigned char *buffer, unsigned int length);
        IOReturn do_control_device_in(IOUSBInterfaceInterface220 **interface, int bRequest, int wValue,
                                      int wIndex, int wLength, void *buffer, int destination, int type);
        IOReturn do_control_device_out(IOUSBInterfaceInterface220 **interface, int bRequest, int wValue,
                                       int wIndex, int wLength, void *buffer, int destination, int type);


    public:
        UVCDevice(IOUSBDeviceInterface **dev, vector<USBINTFV**> interfaces);
        UVC_VIDEO_STREAMING *get_streaming_interface();
        UVC_VIDEO_CONTROL *get_control_interface();
        IOReturn commit_probe();
        IOReturn do_probe(unsigned char format, unsigned char frame, unsigned char frameInterval,UVC_PROBE *ret_probe, bool *accepted);
        IOReturn do_probe(UVC_PROBE *set_probe,UVC_PROBE *ret_probe, bool *accepted);
        void set_probe(UVC_PROBE *set_probe);
        
        //Settings
        IOReturn uvc_get_entity(UVC_ENTITY *entity, UInt8 uid, UVC_ENTITY_CAP *capabilities);
        IOReturn uvc_set_entity(UVC_ENTITY *entity, UInt8 uid, UInt32 length);
        SInt32 get_setting_value_with_length(unsigned char *buffer, UInt32 length);
        SInt32 set_setting_value_with_length(UInt32 value, UInt32 length);

        ~UVCDevice(void);
    };
}

#endif

