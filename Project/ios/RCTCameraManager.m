#import "RCTCameraManager.h"
#import "RCTCamera.h"
#import "RCTBridge.h"
#import "RCTEventDispatcher.h"
#import "RCTUtils.h"
#import "RCTLog.h"
#import "UIView+React.h"
#import <AssetsLibrary/ALAssetsLibrary.h>
#import <AVFoundation/AVFoundation.h>
#import <ImageIO/ImageIO.h>

@interface RCTCameraManager ()

@end

@implementation RCTCameraManager

RCT_EXPORT_MODULE();

- (UIView *)viewWithProps:(__unused NSDictionary *)props
{
    self.presetCamera = ((NSNumber *)props[@"type"]).integerValue;
    return [self view];
}

- (UIView *)view
{
    self.session = [AVCaptureSession new];
#if !(TARGET_IPHONE_SIMULATOR)
    self.previewLayer = [AVCaptureVideoPreviewLayer layerWithSession:self.session];
    self.previewLayer.videoGravity = AVLayerVideoGravityResizeAspectFill;
    self.previewLayer.needsDisplayOnBoundsChange = YES;
#endif
    
    if(!self.camera) {
        self.camera = [[RCTCamera alloc] initWithManager:self bridge:self.bridge];
    }
    return self.camera;
}

- (NSDictionary *)constantsToExport
{
    return @{
             @"BarCodeType": @{
                     @"upce": AVMetadataObjectTypeUPCECode,
                     @"code39": AVMetadataObjectTypeCode39Code,
                     @"code39mod43": AVMetadataObjectTypeCode39Mod43Code,
                     @"ean13": AVMetadataObjectTypeEAN13Code,
                     @"ean8":  AVMetadataObjectTypeEAN8Code,
                     @"code93": AVMetadataObjectTypeCode93Code,
                     @"code138": AVMetadataObjectTypeCode128Code,
                     @"pdf417": AVMetadataObjectTypePDF417Code,
                     @"qr": AVMetadataObjectTypeQRCode,
                     @"aztec": AVMetadataObjectTypeAztecCode
#ifdef AVMetadataObjectTypeInterleaved2of5Code
                     ,@"interleaved2of5": AVMetadataObjectTypeInterleaved2of5Code
# endif
#ifdef AVMetadataObjectTypeITF14Code
                     ,@"itf14": AVMetadataObjectTypeITF14Code
# endif
#ifdef AVMetadataObjectTypeDataMatrixCode
                     ,@"datamatrix": AVMetadataObjectTypeDataMatrixCode
# endif
                     },
             @"Type": @{
                     @"front": @(RCTCameraTypeFront),
                     @"back": @(RCTCameraTypeBack)
                     },
             @"TorchMode": @{
                     @"off": @(RCTCameraTorchModeOff),
                     @"on": @(RCTCameraTorchModeOn),
                     @"auto": @(RCTCameraTorchModeAuto)
                     }
             };
}


RCT_CUSTOM_VIEW_PROPERTY(type, NSInteger, RCTCamera) {
    NSInteger type = [RCTConvert NSInteger:json];
    
    self.presetCamera = type;
    if (self.session.isRunning) {
        dispatch_async(self.sessionQueue, ^{
            AVCaptureDevice *currentCaptureDevice = [self.videoCaptureDeviceInput device];
            AVCaptureDevicePosition position = (AVCaptureDevicePosition)type;
            AVCaptureDevice *captureDevice = [self deviceWithMediaType:AVMediaTypeVideo preferringPosition:(AVCaptureDevicePosition)position];
            
            if (captureDevice == nil) {
                return;
            }
            
            self.presetCamera = type;
            
            NSError *error = nil;
            AVCaptureDeviceInput *captureDeviceInput = [AVCaptureDeviceInput deviceInputWithDevice:captureDevice error:&error];
            
            if (error || captureDeviceInput == nil)
            {
                NSLog(@"%@", error);
                return;
            }
            
            [self.session beginConfiguration];
            
            [self.session removeInput:self.videoCaptureDeviceInput];
            
            if ([self.session canAddInput:captureDeviceInput])
            {
                [self.session addInput:captureDeviceInput];
                
                [NSNotificationCenter.defaultCenter removeObserver:self name:AVCaptureDeviceSubjectAreaDidChangeNotification object:currentCaptureDevice];
                
                [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(subjectAreaDidChange:) name:AVCaptureDeviceSubjectAreaDidChangeNotification object:captureDevice];
                self.videoCaptureDeviceInput = captureDeviceInput;
            }
            else
            {
                [self.session addInput:self.videoCaptureDeviceInput];
            }
            
            [self.session commitConfiguration];
        });
    }
}

RCT_CUSTOM_VIEW_PROPERTY(torchMode, NSInteger, RCTCamera) {
    dispatch_async(self.sessionQueue, ^{
        NSInteger *torchMode = [RCTConvert NSInteger:json];
        AVCaptureDevice *device = [self.videoCaptureDeviceInput device];
        NSError *error = nil;
        
        if (![device hasTorch]) return;
        if (![device lockForConfiguration:&error]) {
            NSLog(@"%@", error);
            return;
        }
        [device setTorchMode: torchMode];
        [device unlockForConfiguration];
    });
}

RCT_CUSTOM_VIEW_PROPERTY(barCodeTypes, NSArray, RCTCamera) {
    self.barCodeTypes = [RCTConvert NSArray:json];
}

- (NSArray *)customDirectEventTypes
{
    return @[];
}

- (id)init {
    if ((self = [super init])) {
        self.sessionQueue = dispatch_queue_create("cameraManagerQueue", DISPATCH_QUEUE_SERIAL);
    }
    return self;
}

RCT_EXPORT_METHOD(checkDeviceAuthorizationStatus:(RCTPromiseResolveBlock)resolve
                  reject:(__unused RCTPromiseRejectBlock)reject) {
    __block NSString *mediaType = AVMediaTypeVideo;
    
    [AVCaptureDevice requestAccessForMediaType:mediaType completionHandler:^(BOOL granted) {
        if (!granted) {
            resolve(@(granted));
        }
        else {
            mediaType = AVMediaTypeAudio;
            [AVCaptureDevice requestAccessForMediaType:mediaType completionHandler:^(BOOL granted) {
                resolve(@(granted));
            }];
        }
    }];
}

RCT_EXPORT_METHOD(changeOrientation:(NSInteger)orientation) {
    [self setOrientation:orientation];
}

- (void)startSession {
#if TARGET_IPHONE_SIMULATOR
    return;
#endif
    dispatch_async(self.sessionQueue, ^{
        if (self.presetCamera == AVCaptureDevicePositionUnspecified) {
            self.presetCamera = AVCaptureDevicePositionBack;
        }
        
        AVCaptureStillImageOutput *stillImageOutput = [[AVCaptureStillImageOutput alloc] init];
        if ([self.session canAddOutput:stillImageOutput])
        {
            stillImageOutput.outputSettings = @{AVVideoCodecKey : AVVideoCodecJPEG};
            [self.session addOutput:stillImageOutput];
            self.stillImageOutput = stillImageOutput;
        }
        
        AVCaptureMetadataOutput *metadataOutput = [[AVCaptureMetadataOutput alloc] init];
        if ([self.session canAddOutput:metadataOutput]) {
            [metadataOutput setMetadataObjectsDelegate:self queue:self.sessionQueue];
            [self.session addOutput:metadataOutput];
            [metadataOutput setMetadataObjectTypes:self.barCodeTypes];
            self.metadataOutput = metadataOutput;
        }
        
        __weak RCTCameraManager *weakSelf = self;
        [self setRuntimeErrorHandlingObserver:[NSNotificationCenter.defaultCenter addObserverForName:AVCaptureSessionRuntimeErrorNotification object:self.session queue:nil usingBlock:^(NSNotification *note) {
            RCTCameraManager *strongSelf = weakSelf;
            dispatch_async(strongSelf.sessionQueue, ^{
                // Manually restarting the session since it must have been stopped due to an error.
                [strongSelf.session startRunning];
            });
        }]];
        
        [self.session startRunning];
    });
}

- (void)stopSession {
#if TARGET_IPHONE_SIMULATOR
    return;
#endif
    dispatch_async(self.sessionQueue, ^{
        self.camera = nil;
        [self.previewLayer removeFromSuperlayer];
        [self.session commitConfiguration];
        [self.session stopRunning];
        for(AVCaptureInput *input in self.session.inputs) {
            [self.session removeInput:input];
        }
        
        for(AVCaptureOutput *output in self.session.outputs) {
            [self.session removeOutput:output];
        }
    });
}

- (void)captureOutput:(AVCaptureOutput *)captureOutput didOutputMetadataObjects:(NSArray *)metadataObjects fromConnection:(AVCaptureConnection *)connection {
    
    for (AVMetadataMachineReadableCodeObject *metadata in metadataObjects) {
        for (id barcodeType in self.barCodeTypes) {
            if ([metadata.type isEqualToString:barcodeType]) {
                // Transform the meta-data coordinates to screen coords
                AVMetadataMachineReadableCodeObject *transformed = (AVMetadataMachineReadableCodeObject *)[_previewLayer transformedMetadataObjectForMetadataObject:metadata];
                
                NSDictionary *event = @{
                                        @"type": metadata.type,
                                        @"data": metadata.stringValue
                                        };
                
                [self.bridge.eventDispatcher sendAppEventWithName:@"CameraBarCodeRead" body:event];
            }
        }
    }
}


- (void)initializeCaptureSessionInput:(NSString *)type {
    dispatch_async(self.sessionQueue, ^{
        if (type == AVMediaTypeAudio) {
            for (AVCaptureDeviceInput* input in [self.session inputs]) {
                if ([input.device hasMediaType:AVMediaTypeAudio]) {
                    // If an audio input has been configured we don't need to set it up again
                    return;
                }
            }
        }
        
        [self.session beginConfiguration];
        
        NSError *error = nil;
        AVCaptureDevice *captureDevice;
        
        if (type == AVMediaTypeAudio) {
            captureDevice = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeAudio];
        }
        else if (type == AVMediaTypeVideo) {
            captureDevice = [self deviceWithMediaType:AVMediaTypeVideo preferringPosition:self.presetCamera];
        }
        
        if (captureDevice == nil) {
            return;
        }
        
        AVCaptureDeviceInput *captureDeviceInput = [AVCaptureDeviceInput deviceInputWithDevice:captureDevice error:&error];
        
        if (error || captureDeviceInput == nil) {
            NSLog(@"%@", error);
            return;
        }
        
        if (type == AVMediaTypeVideo) {
            [self.session removeInput:self.videoCaptureDeviceInput];
        }
        
        if ([self.session canAddInput:captureDeviceInput]) {
            [self.session addInput:captureDeviceInput];
            
            if (type == AVMediaTypeAudio) {
                self.audioCaptureDeviceInput = captureDeviceInput;
            }
            else if (type == AVMediaTypeVideo) {
                self.videoCaptureDeviceInput = captureDeviceInput;
            }
            [self.metadataOutput setMetadataObjectTypes:self.metadataOutput.availableMetadataObjectTypes];
        }
        
        [self.session commitConfiguration];
    });
}

- (AVCaptureDevice *)deviceWithMediaType:(NSString *)mediaType preferringPosition:(AVCaptureDevicePosition)position
{
    NSArray *devices = [AVCaptureDevice devicesWithMediaType:mediaType];
    AVCaptureDevice *captureDevice = [devices firstObject];
    
    for (AVCaptureDevice *device in devices)
    {
        if ([device position] == position)
        {
            captureDevice = device;
            break;
        }
    }
    
    return captureDevice;
}


@end
