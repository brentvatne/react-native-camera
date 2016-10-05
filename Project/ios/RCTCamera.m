#import "RCTBridge.h"
#import "RCTCamera.h"
#import "RCTCameraManager.h"
#import "RCTLog.h"
#import "RCTUtils.h"
#import "RCTEventDispatcher.h"

#import "UIView+React.h"

#import <AVFoundation/AVFoundation.h>

@interface RCTCamera ()

@property (nonatomic, weak) RCTCameraManager *manager;
@property (nonatomic, weak) RCTBridge *bridge;

@end

@implementation RCTCamera

- (id)initWithManager:(RCTCameraManager*)manager bridge:(RCTBridge *)bridge
{
    
    if ((self = [super init])) {
        self.manager = manager;
        self.bridge = bridge;
        [self.manager initializeCaptureSessionInput:AVMediaTypeVideo];
        [self.manager startSession];
        [self changePreviewOrientation:[UIApplication sharedApplication].statusBarOrientation];
        [[NSNotificationCenter defaultCenter] addObserver:self  selector:@selector(orientationChanged:)    name:UIDeviceOrientationDidChangeNotification  object:nil];
    }
    return self;
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    self.manager.previewLayer.frame = self.bounds;
    [self setBackgroundColor:[UIColor blackColor]];
    [self.layer insertSublayer:self.manager.previewLayer atIndex:0];
}

- (void)insertReactSubview:(UIView *)view atIndex:(NSInteger)atIndex
{
    [self insertSubview:view atIndex:atIndex + 1];
    return;
}

- (void)removeReactSubview:(UIView *)subview
{
    [subview removeFromSuperview];
    return;
}

- (void)removeFromSuperview
{
    [self.manager stopSession];
    [super removeFromSuperview];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIDeviceOrientationDidChangeNotification object:nil];
}

- (void)orientationChanged:(NSNotification *)notification {
    UIInterfaceOrientation orientation = [[UIApplication sharedApplication] statusBarOrientation];
    [self changePreviewOrientation:orientation];
}

- (void)changePreviewOrientation:(NSInteger)orientation
{
    dispatch_async(dispatch_get_main_queue(), ^{
        if (self.manager.previewLayer.connection.isVideoOrientationSupported) {
            self.manager.previewLayer.connection.videoOrientation = orientation;
        }
    });
}

@end
