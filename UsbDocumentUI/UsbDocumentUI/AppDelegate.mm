//
//  AppDelegate.m
//  UsbDocumentUI
//
//  Created by Aldo Ilsant on 20/10/15.
//  Copyright © 2015 aldoilsant. All rights reserved.
//

#import "AppDelegate.h"
#import <usbdocumentlib/usbdocumentlib.hpp>
#import <usbdocumentlib/UsbDocumentUVCDriver.hpp>
#import "SettingObject.h"
#import "VideoRecorder.h"
#import "NSImage+Rotated.h"
#import "CameraView.h"

using namespace usbdocument;


class TestUVCDriverDelegate : public UVCDriverDelegate {
private:
    AppDelegate *owner;
public:
    TestUVCDriverDelegate(AppDelegate *owner) {
        this->owner=owner;
    }
    void on_camera_added(unsigned long  index) {
        [owner on_camera_added:index];
    }
    void on_camera_removed(unsigned long  index) {
        [owner on_camera_removed:index];
    }
};

class TestUVCCameraDelegate : public UVCCameraDelegate {
private:
    AppDelegate *owner;
public:
    TestUVCCameraDelegate(AppDelegate *owner) {
        this->owner=owner;
    }
    void on_new_frame(unsigned char * buffer, UInt64 size) {
        [owner on_new_frame:buffer withSize:size];
    }
    void on_interrupt() {
        [owner onInterrupt];
    }
    
};

@interface AppDelegate () {
    UVCDriver *driver;
    UVCCamera *camera;
    TestUVCDriverDelegate *delegateProxy;
    TestUVCCameraDelegate *delegateCameraProxy;
    IBOutlet NSButton *playStopButton;
    unsigned char *last_frame;
    UInt64 last_size;
    IBOutlet CameraView *cameraView;
    IBOutlet NSPopUpButton *resPopupButton;
    int curr_format;
    NSString *currentSnapshotDirectory;
    IBOutlet NSTextField *snapshotDirectoryField;
    IBOutlet NSWindow *settingsWindow;
    IBOutlet NSButton *settingsButton;
    IBOutlet NSTableView *settingsTableView;
    IBOutlet NSButton *recordStopButton;
    IBOutlet NSButton *snapshotButton;
    IBOutlet NSButton *rotateLeftButton;
    IBOutlet NSButton *rotateRightButton;
    IBOutlet NSButton *focusButton;
    IBOutlet NSButton *restoreDefaultsButton;
    IBOutlet NSWindow *snapshotWindow;
    IBOutlet NSImageView *snapshotImageView;
    NSMutableArray *settingObjectArray;
    VideoRecorder *videoRecorder;
    NSLock *frameLock;
    IBOutlet NSScrollView *scrollView;
    IBOutlet NSScrollView *snapshotScrollView;
    IBOutlet NSButton *applyResolutionButton;
    int rotateAngle;
    NSTextField *recordingCounterTextField;
    BOOL restoredSettingsFromDefaults;
    BOOL firstInterruptIgnored;
    BOOL rendering;
}

@property (weak) IBOutlet NSWindow *window;
@end

@implementation AppDelegate
-(void) restoreSnapshotDirectoryFromUserDefaults {
    NSString *path=[[NSUserDefaults standardUserDefaults] objectForKey:@"snapshotDirectory"];
    if(path!=nil) {
        [self updateSnapshotDirectory:path];
    }
}
- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    [playStopButton setEnabled:FALSE];
    [self setupRecordingCounter];
    [self unsetupCamera];
    camera=NULL;
    driver=new DocumentUVCDriver();
    UVCCameraDescription *description=new UVCCameraDescription(0x090C,0x037D);
    driver->add_camera_description(description);
    delegateProxy=new TestUVCDriverDelegate(self);
    driver->set_delegate(delegateProxy);
    driver->start();
    NSArray * paths = NSSearchPathForDirectoriesInDomains (NSDesktopDirectory, NSUserDomainMask, YES);
    NSString * desktopPath = [paths objectAtIndex:0];
    [self restoreSnapshotDirectoryFromUserDefaults];
    if(currentSnapshotDirectory==nil) {
        [self updateSnapshotDirectory:desktopPath];
    }
    [self.window makeKeyAndOrderFront:nil];
    videoRecorder=[[VideoRecorder alloc] init];
    [recordStopButton setEnabled:FALSE];
    [focusButton setEnabled:FALSE];
    [snapshotButton setEnabled:FALSE];
    [rotateLeftButton setEnabled:FALSE];
    [rotateRightButton setEnabled:FALSE];
    frameLock=[[NSLock alloc] init];
    rotateAngle=0;
    [cameraView setImageScaling:NSImageScaleNone];
    /*NSAlert *alert = [[NSAlert alloc] init];
    [alert setMessageText:@"This is a trial version for the Final Version Milestone."];
    [alert runModal];*/
}
-(void) setupRecordingCounter {
    recordingCounterTextField=[[NSTextField alloc] initWithFrame:NSMakeRect(0,self.window.contentView.frame.size.height-100,200,50)];
    [recordingCounterTextField setWantsLayer:TRUE];
    [recordingCounterTextField setBezeled:NO];
    [recordingCounterTextField setDrawsBackground:NO];
    [recordingCounterTextField setEditable:NO];
    [recordingCounterTextField setSelectable:NO];
    [recordingCounterTextField setStringValue:@"0.0s"];
    [recordingCounterTextField setHidden:TRUE];
    [recordingCounterTextField setTextColor:[NSColor redColor]];
    [recordingCounterTextField setAlignment:NSLeftTextAlignment];
    [recordingCounterTextField setFont:[NSFont systemFontOfSize:17]];
    [recordingCounterTextField setAutoresizingMask:(NSViewMaxXMargin | NSViewMinYMargin)];
    [self.window.contentView addSubview:recordingCounterTextField];
}
-(void) saveSnapshotDirectoryToUserDefaults {
    [[NSUserDefaults standardUserDefaults] setObject:currentSnapshotDirectory forKey:@"snapshotDirectory"];
    [[NSUserDefaults standardUserDefaults] synchronize];
}
-(void) updateSnapshotDirectory:(NSString *) path {
    currentSnapshotDirectory=path;
    [self saveSnapshotDirectoryToUserDefaults];
    [snapshotDirectoryField setStringValue:currentSnapshotDirectory];
}

- (void)applicationWillTerminate:(NSNotification *)aNotification {
    if(camera!=NULL) {
        if(camera->started()) {
            camera->stop();
        }
        camera->close();
    }
    driver->stop();
}
-(void) on_camera_added:(unsigned long ) index {
    NSLog(@"New camera added, index %lu",index);
    if(camera==NULL) {
        NSLog(@"Using camera at index %lu",index);
        camera=driver->get_camera(index);
        delegateCameraProxy=new TestUVCCameraDelegate(self);
        camera->set_delegate(delegateCameraProxy);
        camera->open();
        dispatch_async(dispatch_get_main_queue(), ^{
            [self setupCamera];
        });
    } else {
        NSLog(@"A camera is already claimed, ignore");
    }
}
-(void) on_camera_removed:(unsigned long ) index {
    NSLog(@"Camera removed at index %lu",index);
    UVCCamera *removed_camera=driver->get_camera(index);
    if(removed_camera==camera) {
        [self unsetupCamera];
    }
}
-(void) enableSettings {
    for(SettingObject *o in settingObjectArray) {
        [o enable:TRUE];
    }
    [restoreDefaultsButton setEnabled:TRUE];
    [self updateFocusSettings];
}
-(void) restoreSettingsFromDefaults {
    for(SettingObject *o in settingObjectArray) {
        [o restoreFromDefaults];
    }
}

-(void) disableSettings {
    for(SettingObject *o in settingObjectArray) {
        [o enable:FALSE];
    }
    [restoreDefaultsButton setEnabled:FALSE];
}
-(void) reloadSettings {
    for(SettingObject *o in settingObjectArray) {
        [o reload];
    }
}
-(void) unsetupCamera {
    [playStopButton setEnabled:FALSE];
    [playStopButton setImage:[NSImage imageNamed:@"4427_Preview-38x40.png"]];
    [resPopupButton setEnabled:FALSE];
    [applyResolutionButton setEnabled:FALSE];
    [resPopupButton removeAllItems];
    [settingObjectArray removeAllObjects];
    [settingsTableView reloadData];
    [restoreDefaultsButton setEnabled:FALSE];
    camera=NULL;
}
-(void) setupCamera {
    //firstInterruptIgnored=FALSE;
    [playStopButton setEnabled:TRUE];
    [playStopButton setImage:[NSImage imageNamed:@"4427_Preview-38x40.png"]];
    [resPopupButton setEnabled:TRUE];
    [applyResolutionButton setEnabled:TRUE];
    [resPopupButton removeAllItems];
    size_t num_formats=camera->get_num_formats();
    for(size_t i=0;i<num_formats;i++) {
        UVCFormat *format=camera->get_format(i);
        if(format->width!=320) {
            NSString *sformat=[NSString stringWithFormat:@"%dx%d",format->width,format->height];
            [resPopupButton addItemWithTitle:sformat];
        }
    }
    [resPopupButton selectItemAtIndex:0];
    curr_format=0;
    //Setup settings
    settingObjectArray=[NSMutableArray array];
    for(size_t i=0;i<camera->get_num_settings();i++) {
        SettingObject *so=[[SettingObject alloc] initWithCamera:camera andSettingIndex:i];
        [settingObjectArray addObject:so];
        [so setDelegate:self];
    }
    [settingsTableView reloadData];
    [self disableSettings];
    [self restoreResolutionFromUserDefaults];
    restoredSettingsFromDefaults=FALSE;

}
-(void) renderFrame {
    dispatch_async(dispatch_get_main_queue(), ^{
        rendering=TRUE;
        NSData *mjpeg_frame=[self getFrame];
        if(mjpeg_frame!=NULL) {
            @autoreleasepool {
                NSImage *image=[[NSImage alloc] initWithData:mjpeg_frame];
                cameraView.image=image;
                //[scrollView setNeedsDisplay:TRUE];
            }
        }
        if([videoRecorder isRecording]) {
            NSData *frame=[self getFrame];
            CGImageRef cgImage=[videoRecorder cgImageFromJPEG:(unsigned char *)frame.bytes ofSize:frame.length];
            [videoRecorder addFrame:cgImage];
            CGImageRelease(cgImage);
        }
        rendering=FALSE;
    });
}
-(void) on_new_frame:(unsigned char *) frame withSize:(UInt64) size {
    unsigned char *old_frame=last_frame;
    unsigned char *new_frame=(unsigned char *)calloc(1,size);
    memcpy(new_frame,frame,size);
    [frameLock lock];
    if(old_frame!=NULL) {
        free(old_frame);
    }
    last_frame=new_frame;
    last_size=size;
    [frameLock unlock];
    if(!rendering) {
        [self renderFrame];
    }
}
-(IBAction)onPlayStop:(id)sender {
    if(camera->started()) {
        if([videoRecorder isRecording]) {
            [self doStopRecording];
        }
        [recordStopButton setEnabled:FALSE];
        [focusButton setEnabled:FALSE];
        [snapshotButton setEnabled:FALSE];
        camera->stop();
        [playStopButton setImage:[NSImage imageNamed:@"4427_Preview-38x40.png"]];
        [rotateLeftButton setEnabled:FALSE];
        [rotateRightButton setEnabled:FALSE];
        [self disableSettings];
    
        rotateAngle=0;
        [cameraView setRotation:0];
    } else {
        camera->set_format(curr_format);
        camera->start();
        //[playStopButton setImage:[NSImage imageNamed:@"stop.png"]];
        UVCFormat *current=camera->get_format(curr_format);
        [scrollView.documentView  setFrame:NSMakeRect(0,0,current->width,current->height)];
        [cameraView setFrame:NSMakeRect(0,0,current->width,current->height)];
        cameraView.width=current->width;
        cameraView.height=current->height;
        [scrollView setNeedsDisplay:TRUE];
        [recordStopButton setEnabled:TRUE];
        [focusButton setEnabled:TRUE];
        [snapshotButton setEnabled:TRUE];
        [rotateLeftButton setEnabled:TRUE];
        [rotateRightButton setEnabled:TRUE];
        [self enableSettings];
        if(!restoredSettingsFromDefaults) {
            restoredSettingsFromDefaults=TRUE;
            [self restoreSettingsFromDefaults];
        }
    }
}
-(NSData *) getFrame {
    [frameLock lock];
    if(last_frame==NULL)  {
        [frameLock unlock];
       return nil;
    }  else {
        NSData *data=[[NSData alloc] initWithBytes:last_frame length:last_size];
        [frameLock unlock];
        return data;
    }
}
-(void) saveResolutionToUserDefaults:(NSString *) resolution {
    [[NSUserDefaults standardUserDefaults] setObject:resolution forKey:@"resolution"];
    [[NSUserDefaults standardUserDefaults] synchronize];
}
-(void) restoreResolutionFromUserDefaults {
    NSString *resolution=[[NSUserDefaults standardUserDefaults] objectForKey:@"resolution"];
    if(resolution!=nil) {
        [resPopupButton selectItemWithTitle:resolution];
        [self onSetResolution:applyResolutionButton];
    }
}
-(IBAction) onSetResolution:(id) sender {
    BOOL cameraWasStarted=FALSE;
    if(camera->started()) {
        cameraWasStarted=TRUE;
        [self onPlayStop:nil];
    }
    cameraView.image=nil;
    NSString *title=[resPopupButton titleOfSelectedItem];
    [self saveResolutionToUserDefaults:title];
    NSArray *parts=[title componentsSeparatedByString:@"x"];
    int width=[[parts objectAtIndex:0] intValue];
    size_t num_formats=camera->get_num_formats();
    for(size_t i=0;i<num_formats;i++) {
        UVCFormat *format=camera->get_format(i);
        if(format->width==width) {
            curr_format=i;
        }
    }
    [self resizeWindow:self.window];
    if(cameraWasStarted) {
        [NSThread sleepForTimeInterval:1.0f];
        [self onPlayStop:nil];
    }
}
-(void) resizeWindow:(NSWindow *) window {
    UVCFormat *format=camera->get_format(curr_format);
    int width=format->width;
    int height=format->height;
    NSRect e = [[NSScreen mainScreen] frame];
    if(width>e.size.width) {
        width=e.size.width;
    }
    if(height>e.size.height) {
        height=e.size.height;
    }
    NSRect frame=self.window.frame;
    frame.size.width=width;
    frame.size.height=height;
    [window setFrame:frame display:TRUE];
    [window center];
}
-(void) saveSnapshot {
    NSData *snapshot=[self getFrame];
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    [formatter setDateFormat: @"yyyy-MM-dd HH:mm:ss"];
    NSString *stringFromDate = [formatter stringFromDate:[NSDate date]];
    NSString *fileName=[NSString stringWithFormat:@"snapshot-%@.jpg",stringFromDate];
    NSString *fullpath=[currentSnapshotDirectory stringByAppendingPathComponent:fileName];
    
    NSImage *image=[[NSImage alloc] initWithData:snapshot];
    if(rotateAngle!=0) {
        image=[image imageRotated:rotateAngle];
    }
    CGImageRef cgRef = [image CGImageForProposedRect:NULL
                                             context:nil
                                               hints:nil];
    NSBitmapImageRep *newRep = [[NSBitmapImageRep alloc] initWithCGImage:cgRef];
    [newRep setSize:[image size]];   // if you want the same resolution
    NSData *pngData = [newRep representationUsingType:NSPNGFileType properties:[NSDictionary dictionary]];
    
    [pngData writeToFile:fullpath atomically:NO];
    [snapshotScrollView.documentView  setFrame:NSMakeRect(0,0,image.size.width,image.size.height)];
    [snapshotScrollView setNeedsDisplay:TRUE];
    [snapshotImageView setFrame:NSMakeRect(0,0,image.size.width,image.size.height)];
    [snapshotImageView setNeedsDisplay:TRUE];
    NSImage *snapshotImage=[[NSImage alloc] initWithContentsOfFile:fullpath];
    snapshotImageView.image=snapshotImage;
    [snapshotWindow makeKeyAndOrderFront:self];
    int width=image.size.width;
    int height=image.size.height;
    //Resize window properly
    NSRect e = [[NSScreen mainScreen] frame];
    if(width>e.size.width) {
        width=e.size.width;
    }
    if(height>e.size.height) {
        height=e.size.height;
    }
    NSRect frame=self.window.frame;
    frame.size.width=width;
    frame.size.height=height;
    [snapshotWindow setFrame:frame display:TRUE];
    [snapshotWindow center];
}
-(void) onInterrupt {
    if(!firstInterruptIgnored && 0) {
        firstInterruptIgnored=TRUE;
    } else {
        NSLog(@"INTERRUPT RECEIVED");
        dispatch_async(dispatch_get_main_queue(), ^{
            [self saveSnapshot];
        });
    }
}
-(IBAction)onChangeSnapshotDirectory:(id)sender {
    NSOpenPanel* openDlg = [NSOpenPanel openPanel];
    
    // Enable the selection of files in the dialog.
    [openDlg setCanChooseFiles:NO];
    
    // Enable the selection of directories in the dialog.
    [openDlg setCanChooseDirectories:YES];
    
    // Change "Open" dialog button to "Select"
    [openDlg setPrompt:@"Select"];
    
    [openDlg setAllowsMultipleSelection:NO];
    
    // Display the dialog.  If the OK button was pressed,
    // process the files.
    if ( [openDlg runModal] == NSOKButton )
    {
        NSArray* files = [openDlg URLs];
        NSString *path=[[files objectAtIndex:0] path];
        [self updateSnapshotDirectory:path];
    }
}
-(IBAction)onTakeSnapshot:(id)sender {
    [self saveSnapshot];
}
-(IBAction)onShowSettings:(id)sender {
    [settingsWindow makeKeyAndOrderFront:nil];
}
-(NSInteger) numberOfRowsInTableView:(NSTableView *)tableView {
    return [settingObjectArray count];
}
- (CGFloat)tableView:(NSTableView *)tableView heightOfRow:(NSInteger)row {
    return 37;
}
-(NSView *) tableView:(NSTableView *)tableView viewForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row {
    SettingObject *so=[settingObjectArray objectAtIndex:row];
    NSView *view=[so getView];
    return view;
}
-(void) doStartRecording {
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    [formatter setDateFormat: @"yyyy-MM-dd HH:mm:ss"];
    NSString *stringFromDate = [formatter stringFromDate:[NSDate date]];
    NSString *fileName=[NSString stringWithFormat:@"video-%@.mov",stringFromDate];
    NSString *fullpath=[currentSnapshotDirectory stringByAppendingPathComponent:fileName];
    UVCFormat *current=camera->get_format(curr_format);
    [videoRecorder startRecordingInVideoFile:fullpath withWidht:current->width andHeight:current->height];
    [recordStopButton setImage:[NSImage imageNamed:@"stop.png"]];
    [self startRecordingCounter];
}
-(void) updateRecordingCounterInBackground {
    dispatch_async(dispatch_get_main_queue(), ^{
        [recordingCounterTextField setHidden:FALSE];
    });
    float seconds=0;
    while([videoRecorder isRecording]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [recordingCounterTextField setStringValue:[NSString stringWithFormat:@"%.1fs",seconds]];
        });
        [NSThread sleepForTimeInterval:0.2];
        seconds+=0.2;
    }
    dispatch_async(dispatch_get_main_queue(), ^{
        [recordingCounterTextField setHidden:TRUE];
    });
}
-(void) startRecordingCounter {
    [self performSelectorInBackground:@selector(updateRecordingCounterInBackground) withObject:nil];
}
-(void) doStopRecording {
    [videoRecorder stopRecording];
    [recordStopButton setImage:[NSImage imageNamed:@"4427_Video-40x38.png"]];
}
-(IBAction)onRecordStop:(id)sender {
    if([videoRecorder isRecording]) {
        [self doStopRecording];
    } else {
        [self doStartRecording];
    }
}
-(void) doRotate {
    UVCFormat *current=camera->get_format(curr_format);
    [cameraView setRotation:rotateAngle];
    if (90 == rotateAngle || 270 == rotateAngle || -90 == rotateAngle || -270 == rotateAngle) {
        [scrollView.documentView  setFrame:NSMakeRect(0,0,current->height,current->width)];
        [cameraView setFrame:NSMakeRect(0,0,current->height,current->width)];
    } else {
        [scrollView.documentView  setFrame:NSMakeRect(0,0,current->width,current->height)];
        [cameraView setFrame:NSMakeRect(0,0,current->width,current->height)];
    }


}
-(IBAction)onRotateLeft:(id)sender {
    rotateAngle+=90;
    rotateAngle%=360;
    NSLog(@"Rotate angle: %d",rotateAngle);
    [self doRotate];
}
-(IBAction)onRotateRight:(id)sender {
    rotateAngle-=90;
    rotateAngle%=360;
    NSLog(@"Rotate angle: %d",rotateAngle);
    [self doRotate];
}
-(IBAction)onFocus:(id)sender {
    int index=camera->get_setting_index_by_type(UVC_FOCUS_AUTO);
    UVCSetting setting=camera->get_setting(index);
    SInt32 value=0;
    if(setting.curr>0) {
        value=0;
    } else {
        value=1;
    }
    camera->set_setting(index, value);
    [self reloadSettings];
}
-(void) onAutoFocusChanged:(BOOL) set {
    [self updateFocusSettings];
}
-(void) updateFocusSettings {
    SettingObject *focusAbsoluteObject=nil;
    SettingObject *autoFocusObject=nil;
    
    for(SettingObject * o in settingObjectArray) {
        int index=[o getSettingIndex];
        UVCSetting setting=camera->get_setting(index);
        if(setting.type==UVC_FOCUS_ABSOLUTE) {
            focusAbsoluteObject=o;
        } else if(setting.type==UVC_FOCUS_AUTO) {
            autoFocusObject=o;
        }
    }
    if(focusAbsoluteObject!=nil) {
        UVCSetting focusAutoSetting=camera->get_setting([autoFocusObject getSettingIndex]);
        NSLog(@"Updating focus setting with curr: %d",focusAutoSetting.curr);
        if(focusAutoSetting.curr>0) {
            //AutoFocus is enabled
            [focusAbsoluteObject enable:FALSE];
        } else {
            [focusAbsoluteObject enable:TRUE];
        }
    }
}
-(IBAction) onRestoreDefaults:(id) sender {
    camera->restore_default_settings();
    [self reloadSettings];
}

@end
