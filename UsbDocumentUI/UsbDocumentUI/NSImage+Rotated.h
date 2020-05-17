//
//  NSImage+Rotated.h
//  UsbDocumentUI
//
//  Created by Aldo Ilsant on 24/10/15.
//  Copyright © 2015 aldoilsant. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface NSImage (Rotated)
- (NSImage *)imageRotated:(float)degrees;
@end