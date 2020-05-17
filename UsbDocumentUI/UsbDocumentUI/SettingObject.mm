//
//  SettingObject.m
//  UsbDocumentUI
//
//  Created by Aldo Ilsant on 22/10/15.
//  Copyright © 2015 aldoilsant. All rights reserved.
//

#import "SettingObject.h"

using namespace usbdocument;

@implementation SettingObject

-(id) initWithCamera:(UVCCamera *) pcamera andSettingIndex:(int) index {
    self=[super init];
    [NSBundle loadNibNamed:@"SettingView" owner:self];
    self->camera=pcamera;
    self->settingIndex=index;
    [self applySetting];
    return self;
}
-(NSString *) uvcSettingToString:(UVC_SETTING_TYPE) setting {
    switch (setting) {
        case usbdocument::UVC_BRIGHTNESS:
            return @"Brightness";
            break;
        case usbdocument::UVC_CONTRAST:
            return @"Contrast";
        case usbdocument::UVC_HUE:
            return @"Hue";
        case usbdocument::UVC_SATURATION:
            return @"Saturation";
        case usbdocument::UVC_SHARPNESS:
            return @"Sharpness";
        case usbdocument::UVC_GAMMA:
            return @"Gamma";
        case usbdocument::UVC_WHITE_BALANCE_TEMPERATURE:
            return @"White Balance T.";
        case usbdocument::UVC_BACKLIGHT_COMPENSATION:
            return @"Backlight Comp.";
        case usbdocument::UVC_GAIN:
            return @"Gain";
        case usbdocument::UVC_POWER_LINE_FREQUENCY:
            return @"Power Line Frequency";
        case usbdocument::UVC_WHITE_BALANCE_TEMPERATURE_AUTO:
            return @"White Balance T. Auto.";
        case usbdocument::UVC_AUTO_EXPOSURE_MODE:
            return @"Auto Exposure Mode";
        case usbdocument::UVC_AUTO_EXPOSURE_PRIORITY:
            return @"Auto Exposure Priority";
        case usbdocument::UVC_EXPOSURE_TIME_ABSOLUTE:
            return @"Exposure Time (Abs.)";
        case usbdocument::UVC_FOCUS_ABSOLUTE:
            return @"Focus (Abs.)";
        case usbdocument::UVC_FOCUS_AUTO:
            return @"Focus (Auto)";
        default:
            return @"Unknown";
            break;
    }
}
-(void) applySetting {
    UVCSetting setting=camera->get_setting(settingIndex);
    NSString *name=[self uvcSettingToString:setting.type];
    [nameField setStringValue:name];
    int min=(int) setting.min;
    int max=(int) setting.max;
    [slider setMinValue:(double)min];
    [slider setMaxValue:(double)max];
    NSString *range=[NSString stringWithFormat:@"(%d,%d)",min,max];
    [rangeField setStringValue:range];
    int curr=(int) setting.curr;
    [valueField setStringValue:[NSString stringWithFormat:@"%d",curr]];
    [slider setIntValue:curr];
}
-(IBAction)onApply:(id)sender {
    int value=[valueField intValue];
    [self doApplyValue:value];
}
-(IBAction)onSliderChange:(id)sender {
    int value=[slider intValue];
    [valueField setIntValue:value];
    [self doApplyValue:value];
}
-(void) saveToUserDefaults:(int) value {
    NSString *name=[NSString stringWithFormat:@"setting_%d",settingIndex];
    [[NSUserDefaults standardUserDefaults] setObject:[NSNumber numberWithInt:value] forKey:name];
    [[NSUserDefaults standardUserDefaults] synchronize];
}
-(void) clearUserDefaults {
    NSString *name=[NSString stringWithFormat:@"setting_%d",settingIndex];
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:name];
    [[NSUserDefaults standardUserDefaults] synchronize];
}
-(void) doApplyValue:(int) value {
    UVCSetting setting=camera->get_setting(settingIndex);
    int min=(int) setting.min;
    int max=(int) setting.max;
    if(value<min) {
        value=min;
    } else if(value>max) {
        value=max;
    }
    NSLog(@"Setting value: %d",value);
    camera->set_setting(settingIndex, value);
    [self saveToUserDefaults:value];
    if(setting.type==UVC_FOCUS_AUTO) {
        BOOL set=value>0;
        [delegate onAutoFocusChanged:set];
    }
}
-(NSView *) getView {
    return mainView;
}
-(void) enable:(BOOL) enable {
    enabled=enable;
    if(enabled) {
        [slider setEnabled:TRUE];
        [valueField setEnabled:TRUE];
        [applyButton setEnabled:TRUE];
    } else {
        [slider setEnabled:FALSE];
        [valueField setEnabled:FALSE];
        [applyButton setEnabled:FALSE];
    }
}
-(void) setDelegate:(NSObject<SettingObjectDelegate> *) del {
    delegate=del;
}
-(int) getSettingIndex {
    return settingIndex;
}
-(void) reload {
    [self applySetting];
    UVCSetting setting=camera->get_setting(settingIndex);
    [self clearUserDefaults];
}
-(void) restoreFromDefaults {
    NSString *name=[NSString stringWithFormat:@"setting_%d",settingIndex];
    NSNumber *value=[[NSUserDefaults standardUserDefaults] objectForKey:name];
    if(value!=nil) {
        [self doApplyValue:[value intValue]];
        [self reload];
    }
}
@end
