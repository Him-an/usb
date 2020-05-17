//
//  AppDelegate.h
//  UsbDocumentUI
//
//  Created by Aldo Ilsant on 20/10/15.
//  Copyright © 2015 aldoilsant. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "SettingObject.h"

@interface AppDelegate : NSObject <NSApplicationDelegate, NSTableViewDelegate,NSTableViewDataSource,SettingObjectDelegate>
-(void) on_camera_added:(unsigned long ) index;
-(void) on_camera_removed:(unsigned long ) index;
-(void) on_new_frame:(unsigned char *) frame withSize:(UInt64) size;
-(NSData *) getFrame;
-(void) onInterrupt;
@end

