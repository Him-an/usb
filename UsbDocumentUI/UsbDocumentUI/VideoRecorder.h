//
//  VideoRecorder.h
//
//  Created by Aldo Ilsant on 23/10/15.
//  Copyright © 2015 aldoilsant. All rights reserved.
//
//
//  VideoRecorder.h
//  UsbDocumentUI
//
//  Created by Aldo Ilsant on 23/10/15.
//  Copyright © 2015 aldoilsant. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>


@interface VideoRecorder : NSObject {
    AVAssetWriter *writer;
    AVAssetWriterInput *writerInput;
    AVAssetWriterInputPixelBufferAdaptor *adaptor;
    int frameNumber;
    BOOL recording;
    NSLock *lock;
    NSDate *startRecordingDate;
}
-(id) init;
-(BOOL) isRecording;
-(void) startRecordingInVideoFile:(NSString *) path withWidht:(int) width andHeight:(int) height;
-(void) addFrame:(CGImageRef) frame;
-(void) stopRecording;
-(CGImageRef) cgImageFromJPEG:(unsigned char *)data ofSize:(int) size;
-(CGImageRef) cgImageFromNSImage:(NSImage *) image;

@end
