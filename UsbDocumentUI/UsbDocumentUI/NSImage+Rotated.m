//
//  NSImage+Rotated.m
//  UsbDocumentUI
//
//  Created by Aldo Ilsant on 24/10/15.
//  Copyright © 2015 aldoilsant. All rights reserved.
//

#import "NSImage+Rotated.h"

@implementation NSImage (Rotated)

- (NSImage *)imageRotated:(float)degrees {
    
    degrees = fmod(degrees, 360.);
    if (0 == degrees) {
        return self;
    }
    NSSize size = [self size];
    NSSize maxSize;
    if (90. == degrees || 270. == degrees || -90. == degrees || -270. == degrees) {
        maxSize = NSMakeSize(size.height, size.width);
    } else if (180. == degrees || -180. == degrees) {
        maxSize = size;
    } else {
        maxSize = NSMakeSize(20+MAX(size.width, size.height), 20+MAX(size.width, size.height));
    }
    NSAffineTransform *rot = [NSAffineTransform transform];
    [rot rotateByDegrees:degrees];
    NSAffineTransform *center = [NSAffineTransform transform];
    [center translateXBy:maxSize.width / 2. yBy:maxSize.height / 2.];
    [rot appendTransform:center];
    NSImage *image = [[NSImage alloc] initWithSize:maxSize];
    [image lockFocus];
    [rot concat];
    NSRect rect = NSMakeRect(0, 0, size.width, size.height);
    NSPoint corner = NSMakePoint(-size.width / 2., -size.height / 2.);
    [self drawAtPoint:corner fromRect:rect operation:NSCompositeCopy fraction:1.0];
    [image unlockFocus];
    return image;
}

@end