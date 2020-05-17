//
//  BackgroundView.m
//  UsbDocumentUI
//
//  Created by AldoIlsant on 14/11/15.
//  Copyright © 2015 aldoilsant. All rights reserved.
//

#import "BackgroundView.h"

@implementation BackgroundView
- (void)drawRect:(NSRect)aRect
{
    [[NSColor grayColor] set];
    NSRectFill([self bounds]);
}
@end
