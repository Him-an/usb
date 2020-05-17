//
//  CameraView.m
//  UsbDocumentUI
//
//  Created by AldoIlsant on 09/12/15.
//  Copyright © 2015 aldoilsant. All rights reserved.
//

#import "CameraView.h"

@implementation CameraView
@synthesize width,height;
-(void) setRotation:(int) angle {
    NSLog(@"ROTATING FOR %d",angle);
    [self rotateByAngle:-currentRotation];
    [self rotateByAngle:angle];
    currentRotation=angle;
}
@end
