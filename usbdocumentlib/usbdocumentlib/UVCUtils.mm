//
//  UVCUtils.m
//  usbdocumentlib
//
//  Created by Aldo Ilsant on 20/10/15.
//  Copyright © 2015 aldoilsant. All rights reserved.
//

#include "UVCUtils.hpp"



IOReturn usbdocument::UVCDevice::parse_streaming_interface(unsigned char *data, unsigned int length, UVC_VIDEO_STREAMING **ret) {
    UVC_VIDEO_STREAMING *streaming=(UVC_VIDEO_STREAMING *)calloc(1,sizeof(UVC_VIDEO_STREAMING));
    *ret=streaming;
    //Parse the input header, then one format, that may have one or more frames, and possibly a color format.
    streaming->bNumFormats=data[3];
    streaming->bEndpointAddress=data[6];
    streaming->bTriggerSupport=data[10];
    streaming->bTriggerUsage=data[11];
    streaming->bControlSize=data[12];
    streaming->formats=(UVC_VIDEO_FORMAT **)calloc(streaming->bNumFormats,sizeof(UVC_VIDEO_FORMAT *));
    data+=data[0];
    length-=data[0];
    int currFormat=-1;
    unsigned int currFrame=0;
    while(length>0) {
        if(data[1]!=CS_INTERFACE && currFormat>=0) break;
        switch(data[2]) {
            case VS_FORMAT_MJPEG:
                currFormat++;
                streaming->formats[currFormat]=(UVC_VIDEO_FORMAT *)calloc(1,sizeof(UVC_VIDEO_FORMAT));
                DLOG(LDEBUG,"New MJPEG format %d...",currFormat);
                streaming->formats[currFormat]->bNumFrameDescriptors=data[4];
                DLOG(LDEBUG,"%d,%d,%d,%d,%d,%d\n",data[0],data[1],data[2],data[3],data[4],data[5]);
                streaming->formats[currFormat]->bBitsPerPixel=data[21];
                streaming->formats[currFormat]->frames=(UVC_VIDEO_FRAME **)calloc(streaming->formats[currFormat]->bNumFrameDescriptors,sizeof(UVC_VIDEO_FRAME *));
                currFrame=0;
                DLOG(LDEBUG,"Format added with frame descriptors %d and bits per pixel %d\n",streaming->formats[currFormat]->bNumFrameDescriptors,streaming->formats[currFormat]->bBitsPerPixel);
                break;
            case VS_FRAME_MJPEG:
                DLOG(LDEBUG,"New MJPEG frame...");
                DLOG(LDEBUG,"Adding frame %d...\n",currFrame);
                streaming->formats[currFormat]->frames[currFrame]=(UVC_VIDEO_FRAME *)calloc(1,sizeof(UVC_VIDEO_FRAME));
                streaming->formats[currFormat]->frames[currFrame]->bFrameIndex=data[3];
                streaming->formats[currFormat]->frames[currFrame]->bmCapabilities=data[4];
                streaming->formats[currFormat]->frames[currFrame]->wWidth=GET_UINT16(data,5);
                streaming->formats[currFormat]->frames[currFrame]->wHeight=GET_UINT16(data,7);
                streaming->formats[currFormat]->frames[currFrame]->dwMinBitRate=GET_UINT32(data,9);
                streaming->formats[currFormat]->frames[currFrame]->dwMaxBitRate=GET_UINT32(data,13);
                streaming->formats[currFormat]->frames[currFrame]->dwDefaultFrameInterval=GET_UINT32(data,21);
                streaming->formats[currFormat]->frames[currFrame]->bFrameIntervalType=data[25];
                if(streaming->formats[currFormat]->frames[currFrame]->bFrameIntervalType==0) {
                    streaming->formats[currFormat]->frames[currFrame]->dwMinFrameInterval=GET_UINT32(data,26);
                    streaming->formats[currFormat]->frames[currFrame]->dwMaxFrameInterval=GET_UINT32(data,30);
                    streaming->formats[currFormat]->frames[currFrame]->dwFrameIntervalStep=GET_UINT32(data,34);
                    
                } else {
                    streaming->formats[currFormat]->frames[currFrame]->dwFrameIntervals=(UInt32 *)calloc(streaming->formats[currFormat]->frames[currFrame]->bFrameIntervalType,sizeof(UInt32));
                    int i;
                    for(i=0;i<streaming->formats[currFormat]->frames[currFrame]->bFrameIntervalType;i++) {
                        streaming->formats[currFormat]->frames[currFrame]->dwFrameIntervals[i]=GET_UINT32(data,26+i*4);
                    }
                }
                DLOG(LDEBUG,"Frame added with frame index %d,%d,%d,%d;;;%u,%u,%u,%d\n",
                     streaming->formats[currFormat]->frames[currFrame]->bFrameIndex,
                     streaming->formats[currFormat]->frames[currFrame]->bmCapabilities,
                     streaming->formats[currFormat]->frames[currFrame]->wWidth,
                     streaming->formats[currFormat]->frames[currFrame]->wHeight,
                     (unsigned int)streaming->formats[currFormat]->frames[currFrame]->dwMinBitRate,
                     (unsigned int)streaming->formats[currFormat]->frames[currFrame]->dwMaxBitRate,
                     (unsigned int)streaming->formats[currFormat]->frames[currFrame]->dwDefaultFrameInterval,
                     streaming->formats[currFormat]->frames[currFrame]->bFrameIntervalType);
                int i;
                for(i=0;i<streaming->formats[currFormat]->frames[currFrame]->bFrameIntervalType;i++) {
                    DLOG(LDEBUG,"Frame interval %u\n",(unsigned int)streaming->formats[currFormat]->frames[currFrame]->dwFrameIntervals[i]);
                }
                currFrame++;
                break;
            case VS_FORMAT_UNCOMPRESSED:
                currFormat++;
                DLOG(LDEBUG,"Adding format %d...\n",currFormat);
                streaming->formats[currFormat]=(UVC_VIDEO_FORMAT *)calloc(1,sizeof(UVC_VIDEO_FORMAT));
                streaming->formats[currFormat]->bNumFrameDescriptors=data[4];
                DLOG(LDEBUG,"%d,%d,%d,%d,%d,%d\n",data[0],data[1],data[2],data[3],data[4],data[5]);
                streaming->formats[currFormat]->bBitsPerPixel=data[21];
                streaming->formats[currFormat]->frames=(UVC_VIDEO_FRAME **)calloc(streaming->formats[currFormat]->bNumFrameDescriptors,sizeof(UVC_VIDEO_FRAME *));
                currFrame=0;
                DLOG(LDEBUG,"Format added with frame descriptors %d and bits per pixel %d\n",streaming->formats[currFormat]->bNumFrameDescriptors,streaming->formats[currFormat]->bBitsPerPixel);
                break;
            case VS_FRAME_UNCOMPRESSED:
                DLOG(LDEBUG,"Adding frame %d...\n",currFrame);
                streaming->formats[currFormat]->frames[currFrame]=(UVC_VIDEO_FRAME *)calloc(1,sizeof(UVC_VIDEO_FRAME));
                streaming->formats[currFormat]->frames[currFrame]->bFrameIndex=data[3];
                streaming->formats[currFormat]->frames[currFrame]->bmCapabilities=data[4];
                streaming->formats[currFormat]->frames[currFrame]->wWidth=GET_UINT16(data,5);
                streaming->formats[currFormat]->frames[currFrame]->wHeight=GET_UINT16(data,7);
                streaming->formats[currFormat]->frames[currFrame]->dwMinBitRate=GET_UINT32(data,9);
                streaming->formats[currFormat]->frames[currFrame]->dwMaxBitRate=GET_UINT32(data,13);
                streaming->formats[currFormat]->frames[currFrame]->dwDefaultFrameInterval=GET_UINT32(data,21);
                streaming->formats[currFormat]->frames[currFrame]->bFrameIntervalType=data[25];
                if(streaming->formats[currFormat]->frames[currFrame]->bFrameIntervalType==0) {
                    streaming->formats[currFormat]->frames[currFrame]->dwMinFrameInterval=GET_UINT32(data,26);
                    streaming->formats[currFormat]->frames[currFrame]->dwMaxFrameInterval=GET_UINT32(data,30);
                    streaming->formats[currFormat]->frames[currFrame]->dwFrameIntervalStep=GET_UINT32(data,34);
                    
                } else {
                    streaming->formats[currFormat]->frames[currFrame]->dwFrameIntervals=(UInt32 *)calloc(streaming->formats[currFormat]->frames[currFrame]->bFrameIntervalType,sizeof(UInt32));
                    int i;
                    for(i=0;i<streaming->formats[currFormat]->frames[currFrame]->bFrameIntervalType;i++) {
                        streaming->formats[currFormat]->frames[currFrame]->dwFrameIntervals[i]=GET_UINT32(data,26+i*4);
                    }
                }
                DLOG(LDEBUG,"Frame added with frame index %d,%d,%d,%d;;;%u,%u,%u,%d\n",
                     streaming->formats[currFormat]->frames[currFrame]->bFrameIndex,
                     streaming->formats[currFormat]->frames[currFrame]->bmCapabilities,
                     streaming->formats[currFormat]->frames[currFrame]->wWidth,
                     streaming->formats[currFormat]->frames[currFrame]->wHeight,
                     (unsigned int)streaming->formats[currFormat]->frames[currFrame]->dwMinBitRate,
                     (unsigned int)streaming->formats[currFormat]->frames[currFrame]->dwMaxBitRate,
                     (unsigned int)streaming->formats[currFormat]->frames[currFrame]->dwDefaultFrameInterval,
                     streaming->formats[currFormat]->frames[currFrame]->bFrameIntervalType);
                for(i=0;i<streaming->formats[currFormat]->frames[currFrame]->bFrameIntervalType;i++) {
                    DLOG(LDEBUG,"Frame interval %u\n",(unsigned int)streaming->formats[currFormat]->frames[currFrame]->dwFrameIntervals[i]);
                }
                
                currFrame++;
                break;
            case VS_COLORFORMAT:
                streaming->formats[currFormat]->colorFormat=(UVC_VIDEO_COLOR_FORMAT *)calloc(1,sizeof(UVC_VIDEO_COLOR_FORMAT));
                streaming->formats[currFormat]->colorFormat->bColorPrimaries=data[3];
                streaming->formats[currFormat]->colorFormat->bTransferCharacteristics=data[4];
                streaming->formats[currFormat]->colorFormat->bMatrixCoefficients=data[5];
                break;
            default:
                break;
        }
        data+=data[0];
        length-=data[0];
    }
    //For quirky cameras with frame descriptors after endpoint
    streaming->bNumFormats=currFormat+1;
    DLOG(LINFO,"Streaming descriptors parsed...\n");
    return kIOReturnSuccess;
}
IOReturn usbdocument::UVCDevice::parse_control_interface(unsigned char *data, unsigned int length, UVC_VIDEO_CONTROL **ret) {
    UVC_VIDEO_CONTROL *control=(UVC_VIDEO_CONTROL *)calloc(1,sizeof(UVC_VIDEO_CONTROL));
    *ret=control;
    control->uvc=GET_UINT16(data,3);
    control->clockFrequency=GET_UINT32(data,7);
    DLOG(LDEBUG,"UVC version: %d; Clock Frequency: %lu\n",control->uvc,control->clockFrequency);
    data+=data[0];
    length-=data[0];
    while(length>0) {
        if(data[1]!=CS_INTERFACE) break;
        switch(data[2]) {
            {
            case VC_INPUT_TERMINAL:
                control->it=(UVC_INPUT_TERMINAL *)calloc(1,sizeof(UVC_INPUT_TERMINAL));
                control->it->tid=data[3];
                UInt32 flagMarker=1;
                int i;
                UInt32 flagMarker2=(1<< 17);
                DLOG(LINFO,"flagMarker2: %d",flagMarker2);
                for(i=0;i<32;i++) {
                    DLOG(LINFO,"%d",flagMarker);
                    flagMarker=flagMarker<< 1;
                }
                //01110100000000000100001001011000
                uint32_t flags=*(uint32_t *)&data[15];
                control->it->scanningMode=flags&(1 << 0)?1:0;
                control->it->autoExposureMode=flags&(1 << 1)?1:0;
                control->it->autoExposurePriority=flags&(1 << 2)?1:0;
                control->it->exposureTimeAbsolute=flags&(1 << 3)?1:0;
                control->it->exposureTimeRelative=flags&(1 << 4)?1:0;
                control->it->focusAbsolute=flags&(1 << 5)?1:0;
                control->it->focusRelative=flags&(1 << 6)?1:0;
                control->it->irisAbsolute=flags&(1 << 7)?1:0;
                control->it->irisRelative=flags&(1 << 8)?1:0;
                control->it->zoomAbsolute=flags&(1 << 9)?1:0;
                control->it->zoomRelative=flags&(1 << 10)?1:0;
                control->it->panTiltAbsolute=flags&(1 << 11)?1:0;
                control->it->panTiltRelative=flags&(1 << 12)?1:0;
                control->it->rollAbsolute=flags&(1 << 13)?1:0;
                control->it->rollRelative=flags&(1 << 14)?1:0;
                control->it->focusAuto=flags&(1 << 17)?1:0;
                control->it->privacy=flags&(1 << 18)?1:0;
                DLOG(LDEBUG,"IT id: %d, %d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d. FocusAuto: %d\n",
                     control->it->tid,
                     control->it->scanningMode,
                     control->it->autoExposureMode,
                     control->it->autoExposurePriority,
                     control->it->exposureTimeAbsolute,
                     control->it->exposureTimeRelative,
                     control->it->focusAbsolute,
                     control->it->focusRelative,
                     control->it->irisAbsolute,
                     control->it->irisRelative,
                     control->it->zoomAbsolute,
                     control->it->zoomRelative,
                     control->it->panTiltAbsolute,
                     control->it->panTiltRelative,
                     control->it->rollAbsolute,
                     control->it->rollRelative,
                     control->it->focusAuto,
                     control->it->privacy,
                     control->it->focusAuto);
                
                break;
            }
            case VC_OUTPUT_TERMINAL:
                DLOG(LDEBUG,"Ignore output terminal");
                break;
            case VC_SELECTOR_UNIT:
                DLOG(LDEBUG,"Ignore selector terminal");
                break;
            {
            case VC_PROCESSING_UNIT:
                control->pu=(UVC_PROCESSING_UNIT *)calloc(1,sizeof(UVC_PROCESSING_UNIT));
                control->pu->uid=data[3];
                UInt32 pflags=*(UInt16 *)&data[8];
                control->pu->brightness=pflags&(1 << 0)?1:0;
                control->pu->contrast=pflags&(1 << 1)?1:0;
                control->pu->hue=pflags&(1 << 2)?1:0;
                control->pu->saturation=pflags&(1 << 3)?1:0;
                control->pu->sharpness=pflags&(1 << 4)?1:0;
                control->pu->gamma=pflags&(1 << 5)?1:0;
                control->pu->whiteBalanceTemperature=pflags&(1 << 6)?1:0;
                control->pu->whiteBalanceComponent=pflags&(1 << 7)?1:0;
                control->pu->backlightCompensantion=pflags&(1 << 8)?1:0;
                control->pu->gain=pflags&(1 << 9)?1:0;
                control->pu->powerLineFrequency=pflags&(1 << 10)?1:0;
                control->pu->hueAuto=pflags&(1 << 11)?1:0;
                control->pu->whiteBalanceTemperatureAuto=pflags&(1 << 12)?1:0;
                control->pu->whiteBalanceComponentAuto=pflags&(1 << 13)?1:0;
                control->pu->digitalMultiplier=pflags&(1 << 14)?1:0;
                control->pu->digitalMultiplierLimit=pflags&(1 << 15)?1:0;
                control->pu->analogVideoStandard=pflags&(1 << 16)?1:0;
                control->pu->analogVideLockStatus=pflags&(1 << 17)?1:0;
                control->pu->contrastAuto=pflags&(1 << 18)?1:0;
                DLOG(LDEBUG,"PU id: %d; %d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d\n",
                     control->pu->uid,
                     control->pu->brightness,
                     control->pu->contrast,
                     control->pu->hue,
                     control->pu->saturation,
                     control->pu->sharpness,
                     control->pu->gamma,
                     control->pu->whiteBalanceTemperature,
                     control->pu->whiteBalanceComponent,
                     control->pu->backlightCompensantion,
                     control->pu->gain,
                     control->pu->powerLineFrequency);
                UInt8 vflags=data[12];
                control->pu->vsNone=vflags&(1<<0)?1:0;
                control->pu->ntsc525=vflags&(1<<1)?1:0;
                control->pu->pal625=vflags&(1<<2)?1:0;
                control->pu->secam=vflags&(1<<3)?1:0;
                control->pu->ntsc625=vflags&(1<<4)?1:0;
                control->pu->pal525=vflags&(1<<5)?1:0;
                break;
            }
            case VC_EXTENSION_UNIT:
                DLOG(LDEBUG,"Ignoring extension unit");
                break;
        }
        data+=data[0];
        length-=data[0];
    }
    return kIOReturnSuccess;
}

void usbdocument::UVCDevice::parse_descriptors(unsigned char *data, UInt16 length) {
    unsigned char *buffer=data;
    unsigned int tlength=0;
    char isDone=0;
    while(tlength<length && isDone !=2) {
        unsigned int dLength=buffer[0];
        unsigned int dType=buffer[1];
        unsigned int dClass=buffer[5];
        unsigned int dSubClass=buffer[6];
        if(dType==DESCRIPTOR_TYPE_INTERFACE && dClass==INTERFACE_CLASS_VIDEO) {
            switch(dSubClass) {
                case INTERFACE_SUBCLASS_STREAMING:
                    DLOG(LDEBUG,"Found streaming interface.\n");
                    parse_streaming_interface(buffer,length-tlength,&streaming);
                    isDone++;
                    break;
                case INTERFACE_SUBCLASS_CONTROL:
                    DLOG(LDEBUG,"Found control interface.\n");
                    parse_control_interface(buffer,length-tlength,&control);
                    isDone++;
                    break;
                default:
                    DLOG(LDEBUG,"Unexpected interface subclass\n");
            }
        }
        tlength+=dLength;
        buffer=data+tlength;
    }
}
IOReturn  usbdocument::UVCDevice::init_probe() {
    Utils::test_assert(control->uvc<0x0110,"Unsupported UVC version");
    probe=(UVC_PROBE *)calloc(1,sizeof(UVC_PROBE));
    return kIOReturnSuccess;
}
usbdocument::UVCDevice::UVCDevice(IOUSBDeviceInterface **device, vector<USBINTFV**> interfaces) {
    this->dev=device;
    this->interfaces=interfaces;
    IOUSBConfigurationDescriptorPtr configDesc;
    Utils::assert_error((*dev)->GetConfigurationDescriptorPtr(dev,0,&configDesc));
    parse_descriptors((unsigned char *)configDesc,configDesc->wTotalLength);
    init_probe();
    DLOG(LDEBUG,"Done initializing UVC device");
}
usbdocument::UVCDevice::~UVCDevice(void) {

}
UVC_VIDEO_STREAMING *usbdocument::UVCDevice::get_streaming_interface() {
    return streaming;
}
UVC_VIDEO_CONTROL *usbdocument::UVCDevice::get_control_interface() {
    return control;
}

IOReturn usbdocument::UVCDevice::commit_probe() {
    DLOG(LDEBUG,"Commiting probe...\n");
    Utils::watch_error(do_control_request(REQUEST_SET_CUR, 0, VS_COMMIT_CONTROL, (unsigned char *)probe, 26));
    memset(probe,sizeof(UVC_PROBE),0);
    Utils::watch_error(do_control_request(REQUEST_GET_CUR, 0, VS_COMMIT_CONTROL, (unsigned char *) probe, 26));
    return kIOReturnSuccess;
}
IOReturn usbdocument::UVCDevice::do_probe(unsigned char format, unsigned char frame, unsigned char frameInterval, UVC_PROBE *ret_probe, bool *is_accepted) {
    //Attempt to negotiate the frame, etc. Maximizes bandwidth usage
    //Get bus available bandwidth for interface
    //If payload size is enough then attempt to use that frame format
    //Test if the format has been succesfully set.
    probe->bmHint=1; //FrameInterval, we prefer video density to quality
    probe->bFormatIndex=format;
    int i;
    UVC_VIDEO_FRAME **frames=streaming->formats[format]->frames;
    DLOG(LDEBUG,"Iterating over %d frame descriptors...\n",streaming->formats[format]->bNumFrameDescriptors);
    for(i=frame;i<=frame;i++) {
        probe->bFrameIndex=frames[i]->bFrameIndex;
        int j;
        for(j=frameInterval;j<=frameInterval;j++) {
            probe->dwFrameInterval=frames[i]->dwFrameIntervals[j];
            probe->dwMaxPayloadTransferSize=0; //FIXME: calculate bandwidth
            DLOG(LDEBUG,"Sending probe request (size %lu) for frame index %d, frame interval %u (%d)...\n",sizeof(UVC_PROBE),i,(unsigned int)frames[i]->dwFrameIntervals[j],j);
            do_probe(probe,ret_probe,is_accepted);
        }
    }
    //Negotiation successful
    return kIOReturnSuccess;
}
IOReturn usbdocument::UVCDevice::do_probe(UVC_PROBE *set_probe,UVC_PROBE *ret_probe, bool *is_accepted) {
    Utils::watch_error(do_control_request(REQUEST_SET_CUR, 0, VS_PROBE_CONTROL, (unsigned char *)set_probe, 26));
    DLOG(LDEBUG,"Testing configuration...\n");
    Utils::watch_error(do_control_request(REQUEST_GET_CUR, 0, VS_PROBE_CONTROL, (unsigned char *) ret_probe, 26));
    char accepted=1;
    accepted&=set_probe->bFormatIndex==ret_probe->bFormatIndex;
    accepted&=set_probe->bFrameIndex==ret_probe->bFrameIndex;
    accepted&=set_probe->dwFrameInterval==ret_probe->dwFrameInterval;
    
    DLOG(LDEBUG,"Expected %d, found %d\n",set_probe->bFormatIndex,ret_probe->bFormatIndex);
    DLOG(LDEBUG,"Expected %d, found %d\n",set_probe->bFrameIndex,ret_probe->bFrameIndex);
    DLOG(LDEBUG,"Expected %u, found %u\n",(unsigned int)set_probe->dwFrameInterval,(unsigned int)ret_probe->dwFrameInterval);
    DLOG(LDEBUG,"Framing info: %d\n",set_probe->bmFramingInfo);
    *is_accepted=accepted;
    return kIOReturnSuccess;
}
void usbdocument::UVCDevice::set_probe(UVC_PROBE *set_probe) {
    memcpy(probe,set_probe,sizeof(UVC_PROBE));
}
IOReturn usbdocument::UVCDevice::do_control_request(UInt8 request, UInt8 unit, UInt8 selector, unsigned char *buffer, unsigned int length) {
    
    USBINTFV **interface;
    if(unit==3 || unit==1 || unit==2) {
        interface=interfaces[0];
    } else {
        interface=interfaces[1];
    }
    //Utils::watch_error(((*interface)->ClearPipeStallBothEnds(interface,0)));
    UInt8 number;
    Utils::assert_error((*interface)->GetInterfaceNumber(interface, &number));
    
    if(request & 0x80) {
        return do_control_device_in(interface,request, (selector << 8), (unit << 8) | number, length, buffer, kUSBClass, kUSBInterface);
    } else {
        return do_control_device_out(interface,request, (selector << 8), (unit << 8) | number, length, buffer, kUSBClass, kUSBInterface);
    }
}

IOReturn usbdocument::UVCDevice::do_control_device_in(IOUSBInterfaceInterface220 **interface, int bRequest, int wValue,
                                                   int wIndex, int wLength, void *buffer, int destination, int type) {
    IOUSBDevRequest request;
    DLOG(LINFO,"IN Control transfer; bRequest=%x, wValue=%x (%d), wIndex=%x (%d), wLength=%x(%d)\n",bRequest,
         wValue,wValue,wIndex,wIndex,wLength,wLength);
    request.bmRequestType=USBmakebmRequestType(kUSBIn,type,destination);
    request.bRequest=bRequest;
    request.wValue=wValue;
    request.wIndex=wIndex;
    request.wLength=wLength;
    request.pData=buffer;
    IOReturn kr;
    kr=Utils::watch_error((*interface)->ControlRequest(interface,0,&request));
    if(kr==kIOReturnSuccess) {
        //print_buffer_data((unsigned char *)buffer,wLength);
    }
    return kr;
}
IOReturn usbdocument::UVCDevice::do_control_device_out(IOUSBInterfaceInterface220 **interface, int bRequest, int wValue, int wIndex, int wLength, void *buffer, int destination, int type) {
    IOUSBDevRequest request;
    DLOG(LINFO,"OUT Control transfer; bRequest=%x, wValue=%x (%d), wIndex=%x (%d), wLength=%x(%d)",bRequest,
         wValue,wValue,wIndex,wIndex,wLength,wLength);
    DLOG(LINFO,"Data: ");
    //print_buffer_data((unsigned char *)buffer, wLength);
    request.bmRequestType=USBmakebmRequestType(kUSBOut,type,destination);
    request.bRequest=bRequest;
    request.wValue=wValue;
    request.wIndex=wIndex;
    request.wLength=wLength;
    request.pData=buffer;
    IOReturn kr;
    kr=(*interface)->ControlRequest(interface,0,&request);
    Utils::watch_error(kr);
    return kr;
}

IOReturn usbdocument::UVCUtils::decode_header(unsigned char *buffer, UVC_DECODE_HEADER *header) {
    header->bHeaderLength=buffer[0];
    header->bFrameId=buffer[1] & (1 << 0);
    header->bEndOfFrame=buffer[1] & (1 << 1);
    header->bPresentationTime=buffer[1] & (1 << 2);
    header->bSourceClockReference=buffer[1] & (1 << 3);
    header->bPayload=buffer[1] & (1 << 4);
    header->bStillImage=buffer[1] & (1 << 5);
    header->bError=buffer[1] & (1 << 6);
    header->bEndOfHeader=buffer[1] & (1 << 7);
    /*
     if(header->bError>0) {
     DLOG(LERROR,"Error transmiting frame\n");
     } else if (header->bStillImage) {
     DLOG(LINFO,"Still image frame.\n");
     }
     DLOG(LDEBUG,"Header. Length: %d, Frame Id: %d, End of Frame: %d, Presentantion time: %d, SourceClockReference: %d, Payload: %d, Still Image: %d, Error: %d, End of Header: %d\n",
		   header->bHeaderLength,
		   header->bFrameId,
		   header->bEndOfFrame,
		   header->bPresentationTime,
		   header->bSourceClockReference,
		   header->bPayload,
		   header->bStillImage,
		   header->bError,
		   header->bEndOfHeader);*/
    if(header->bPresentationTime) {
        header->dwPresentationTime=GET_UINT32(buffer,2);
        //DLOG(LDEBUG,"Presentation time: %u\n",header->dwPresentationTime);
    }
    if(header->bSourceClockReference) {
        header->srcSourceClock=GET_UINT32(buffer,8);
    }
    return kIOReturnSuccess;
}

#pragma mark Get/Set entities

SInt32 usbdocument::UVCDevice::get_setting_value_with_length(unsigned char *buffer, UInt32 length) {
    SInt32 value=0;
    if(length==1) {
        value=buffer[0];
    } else if(length==2) {
        value=(short)GET_UINT16(buffer,0);
    } else if(length==4) {
        value=GET_UINT32(buffer, 0);
    } else {
        throw "INVALID LENGTH FOR SETTING";
    }
    return value;
}
SInt32 usbdocument::UVCDevice::set_setting_value_with_length(UInt32 input, UInt32 length) {
    UInt32 value=0;
    if(length==1) {
        value=(UInt8)input;
    } else if(length==2) {
        value=SET_UINT16(input);
    } else if(length==4) {
        value=SET_UINT32(input);
    } else {
        throw "INVALID LENGTH FOR SET SETTING";
    }
    return value;
}
IOReturn usbdocument::UVCDevice::uvc_get_entity(UVC_ENTITY *entity, UInt8 uid, UVC_ENTITY_CAP *capabilities){
    unsigned char setupBuf[capabilities->length];
    if(capabilities->supports_get_def) {
        Utils::watch_error(do_control_request(REQUEST_GET_DEF,uid, entity->entity , setupBuf, capabilities->length));
        SInt32 value=get_setting_value_with_length(setupBuf, capabilities->length);
        entity->def=value;
    } else {
        entity->def=0;
    }
    DLOG(LINFO,"Entity %d get def: %d (%d)\n",entity->entity,entity->def, (short) entity->def);
    
    if(capabilities->supports_get_min) {
        Utils::watch_error(do_control_request(REQUEST_GET_MIN, uid, entity->entity , setupBuf, capabilities->length));
        SInt32 value=get_setting_value_with_length(setupBuf, capabilities->length);
        entity->min=value;
    } else {
        entity->min=0;
    }
    DLOG(LINFO,"Entity %d get min: %d (%d)\n",entity->entity,entity->min, (short) entity->min);
    
    if(capabilities->supports_get_max) {
        Utils::watch_error(do_control_request(REQUEST_GET_MAX, uid, entity->entity , setupBuf, capabilities->length));
        SInt32 value=get_setting_value_with_length(setupBuf, capabilities->length);
        entity->max=value;
    } else {
        entity->max=0;
    }
    DLOG(LINFO,"Entity %d get max: %d (%d)\n",entity->entity,entity->max, (short) entity->max);
    
    if(capabilities->supports_get_res) {
        Utils::watch_error(do_control_request(REQUEST_GET_RES, uid, entity->entity , setupBuf, capabilities->length));
        SInt32 value=get_setting_value_with_length(setupBuf, capabilities->length);
        entity->res=value;
    } else {
        entity->res=0;
    }
    DLOG(LINFO,"Entity %d get res: %d (%d)\n",entity->entity,entity->res, (short) entity->res);
    
    if(capabilities->supports_get_curr) {
        Utils::watch_error(do_control_request(REQUEST_GET_CUR, uid, entity->entity , setupBuf, capabilities->length));
        SInt32 value=get_setting_value_with_length(setupBuf, capabilities->length);
        entity->cur=value;
    } else {
        entity->cur=0;
    }
    DLOG(LINFO,"Entity %d get cur: %d (%d)\n",entity->entity,entity->cur, (short) entity->cur);
    entity->set=entity->cur;
    return kIOReturnSuccess;
}
IOReturn usbdocument::UVCDevice::uvc_set_entity(UVC_ENTITY *entity, UInt8 uid, UInt32 length) {
    UInt32 value=set_setting_value_with_length(entity->set, length);
    return do_control_request(REQUEST_SET_CUR, uid, entity->entity , (unsigned char *) &value, length);
}

