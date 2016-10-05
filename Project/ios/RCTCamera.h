#import <AVFoundation/AVFoundation.h>
#import <UIKit/UIKit.h>

@class RCTCameraManager;

@interface RCTCamera : UIView

- (id)initWithManager:(RCTCameraManager *)manager bridge:(RCTBridge *)bridge;

@end