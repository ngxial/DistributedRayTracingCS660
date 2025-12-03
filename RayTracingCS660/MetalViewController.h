//
//  MetalViewController.h
//  RayTracingCS660
//
//  Created by ngxial on 2025/7/17.
//
#ifndef MetalViewController_h
#define MetalViewController_h
//
//  MetalViewController.h
//  RayTracingCS660
//  最終版：macOS + SwiftUI 完全相容
//

#import <Cocoa/Cocoa.h>
#import <MetalKit/MetalKit.h>
#import "TaskManager.h"
#import "NetworkServer.h"

@interface MetalViewController : NSViewController <MTKViewDelegate, TaskManagerDelegate, NetworkServerDelegate>

// 必須公開給 SwiftUI 呼叫！
- (void)setupWithDevice:(id<MTLDevice>)device view:(MTKView *)view;
- (void)mtkView:(MTKView *)view drawableSizeWillChange:(CGSize)size;

// 其餘屬性
@property (nonatomic, strong) MTKView *metalView;
@property (nonatomic, strong) id<MTLDevice> device;
@property (nonatomic, strong) id<MTLCommandQueue> commandQueue;
@property (nonatomic, strong) id<MTLRenderPipelineState> displayPipelineState;
@property (nonatomic, strong) id<MTLSamplerState> samplerState;
@property (nonatomic, strong) id<MTLTexture> finalTexture;

@property (nonatomic, strong) TaskManager *taskManager;
@property (nonatomic, strong) NetworkServer *networkServer;

@property (nonatomic, strong) NSButton *startButton;
@property (nonatomic, strong) NSProgressIndicator *progressIndicator;
@property (nonatomic, strong) NSTextField *statusLabel;

- (void)startDistributedRendering;

@end
#endif /* MetalViewController_h */
