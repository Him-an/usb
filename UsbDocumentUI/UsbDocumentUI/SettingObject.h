//
//  SettingObject.h
//  UsbDocumentUI
//
//  Created by Aldo Ilsant on 22/10/15.
//  Copyright © 2015 aldoilsant. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <Cocoa/Cocoa.h>
#import <usbdocumentlib/usbdocumentlib.hpp>

@protocol SettingObjectDelegate
-(void) onAutoFocusChanged:(BOOL) set;
@end

@interface SettingObject : NSObject {
    IBOutlet NSTextField *nameField;
    IBOutlet NSTextField *rangeField;
    IBOutlet NSSlider *slider;
    IBOutlet NSTextField *valueField;
    IBOutlet NSButton *applyButton;
    IBOutlet NSView *mainView;
    usbdocument::UVCCamera *camera;
    int settingIndex;
    BOOL enabled;
    NSObject<SettingObjectDelegate> *delegate;
}
-(id) initWithCamera:(usbdocument::UVCCamera *) camera andSettingIndex:(int) index;
-(NSView *) getView;
-(int) getSettingIndex;
-(void) enable:(BOOL) enable;
-(void) setDelegate:(NSObject<SettingObjectDelegate> *) del;
-(void) reload;
-(void) restoreFromDefaults;
@end
