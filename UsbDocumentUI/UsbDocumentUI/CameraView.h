//
//  CameraView.h
//  UsbDocumentUI
//
//  Created by AldoIlsant on 09/12/15.
//  Copyright © 2015 aldoilsant. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface CameraView : NSImageView {
    int width;
    int height;
    int currentRotation;
}
@property int width, height;
-(void) setRotation:(int) angle;
@end
