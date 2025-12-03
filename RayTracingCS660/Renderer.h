//
//  Renderer.h
//  RayTracingCS660
//
//  Created by ngxial on 2025/7/17.
//

#ifndef Renderer_h
#define Renderer_h
// Renderer.h
#import <MetalKit/MetalKit.h>
#import "Ray.h"

@interface Renderer : NSObject <MTKViewDelegate>
@property (nonatomic, strong) id<MTLDevice> device;
@property (nonatomic, strong) id<MTLCommandQueue> commandQueue;
- (instancetype)initWithMetalKitView:(MTKView *)view;
@end
#endif /* Renderer_h */
