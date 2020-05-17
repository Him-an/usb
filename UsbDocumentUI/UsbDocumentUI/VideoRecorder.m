//
//  VideoRecorder.m
//  UsbDocumentUI
//
//  Created by Aldo Ilsant on 23/10/15.
//  Copyright © 2015 aldoilsant. All rights reserved.
//

#import "VideoRecorder.h"
#import "NSImage+Rotated.h"


@implementation VideoRecorder
-(id) init {
    self=[super init];
    recording=FALSE;
    lock=[[NSLock alloc] init];
    return self;
}
-(void) startRecordingInVideoFile:(NSString *) path withWidht:(int) width andHeight:(int) height {
    NSError *error=nil;
    [lock lock];
    writer = [[AVAssetWriter alloc] initWithURL:
              [NSURL fileURLWithPath:path] fileType:AVFileTypeQuickTimeMovie
                                          error:&error];
    NSDictionary *videoSettings = [NSDictionary dictionaryWithObjectsAndKeys:
                                   AVVideoCodecH264, AVVideoCodecKey,
                                   [NSNumber numberWithInt:width
                                    ], AVVideoWidthKey,
                                   [NSNumber numberWithInt:height], AVVideoHeightKey,
                                   nil];
    writerInput=[AVAssetWriterInput
                 assetWriterInputWithMediaType:AVMediaTypeVideo
                 outputSettings:videoSettings];
    [writer addInput:writerInput];
    NSDictionary *sourcePixelBufferAttributesDictionary = [NSDictionary dictionaryWithObjectsAndKeys:
                                                           [NSNumber numberWithInt:kCVPixelFormatType_32ARGB], kCVPixelBufferPixelFormatTypeKey, nil];
    adaptor = [AVAssetWriterInputPixelBufferAdaptor assetWriterInputPixelBufferAdaptorWithAssetWriterInput:writerInput sourcePixelBufferAttributes:sourcePixelBufferAttributesDictionary];
    [writer startWriting];
    [writer startSessionAtSourceTime:kCMTimeZero];
    frameNumber=0;
    recording=TRUE;
    startRecordingDate=nil;
    [lock unlock];
    
}
-(void) addFrame:(CGImageRef) frame {
    [lock lock];
    int64_t time=0;
    if(startRecordingDate!=nil) {
        NSDate *now=[NSDate date];
        time=[now timeIntervalSinceDate:startRecordingDate]*1000;
    } else {
        startRecordingDate=[NSDate date];
    }
    CVPixelBufferRef pixelBuffer = [self pixelBufferFromCGImage:frame];
    if(writerInput.readyForMoreMediaData) {
        NSLog(@"Appending frame at time: %lld",time);
        if(![adaptor appendPixelBuffer:pixelBuffer withPresentationTime:CMTimeMake(time, 1000)]) {
            NSLog(@"Failed to append");
        }
        frameNumber++;
    }
    CVPixelBufferRelease(pixelBuffer);
    [lock unlock];
}
- (CVPixelBufferRef) pixelBufferFromCGImage: (CGImageRef) image
{
    
    CGSize frameSize = CGSizeMake(CGImageGetWidth(image), CGImageGetHeight(image));
    NSDictionary *options = [NSDictionary dictionaryWithObjectsAndKeys:
                             [NSNumber numberWithBool:NO], kCVPixelBufferCGImageCompatibilityKey,
                             [NSNumber numberWithBool:NO], kCVPixelBufferCGBitmapContextCompatibilityKey,
                             nil];
    CVPixelBufferRef pxbuffer = NULL;
    CVReturn status = CVPixelBufferCreate(kCFAllocatorDefault, frameSize.width,
                                          frameSize.height,  kCVPixelFormatType_32ARGB, (__bridge CFDictionaryRef) options,
                                          &pxbuffer);
    NSParameterAssert(status == kCVReturnSuccess && pxbuffer != NULL);
    
    CVPixelBufferLockBaseAddress(pxbuffer, 0);
    void *pxdata = CVPixelBufferGetBaseAddress(pxbuffer);
    
    
    CGColorSpaceRef rgbColorSpace = CGColorSpaceCreateDeviceRGB();
    CGContextRef context = CGBitmapContextCreate(pxdata, frameSize.width,
                                                 frameSize.height, 8, CVPixelBufferGetBytesPerRow(pxbuffer), rgbColorSpace,
                                                 kCGImageAlphaPremultipliedFirst);
    
    CGContextDrawImage(context, CGRectMake(0, 0, CGImageGetWidth(image),
                                           CGImageGetHeight(image)), image);
    CGColorSpaceRelease(rgbColorSpace);
    CGContextRelease(context);
    
    CVPixelBufferUnlockBaseAddress(pxbuffer, 0);
    
    return pxbuffer;
}
-(void) stopRecording {
    [lock lock];
    recording=FALSE;
    [writerInput markAsFinished];
    [writer finishWritingWithCompletionHandler:^(void)  {
    }];
    [lock unlock];
}
-(CGImageRef) cgImageFromJPEG:(unsigned char *)data ofSize:(int) size {
    CGDataProviderRef dp=CGDataProviderCreateWithCFData(CFDataCreate(kCFAllocatorDefault, (const UInt8 *)data, size));
    CGImageRef cgImage=CGImageCreateWithJPEGDataProvider(dp, nil, true, kCGRenderingIntentDefault);
    return cgImage;
    
}
-(CGImageRef) cgImageFromNSImage:(NSImage *) image {
    NSRect imageRect = NSMakeRect(0, 0, image.size.width, image.size.height);
    CGImageRef cgImage = [image CGImageForProposedRect:&imageRect context:NULL hints:nil];
    return cgImage;
}
-(BOOL) isRecording {
    return recording;
}
@end
