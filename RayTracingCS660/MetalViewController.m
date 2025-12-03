
//
//  MetalViewController.m
//  RayTracingCS660
//  完全相容 macOS + SwiftUI + NSViewRepresentable
//

#import "MetalViewController.h"
#import "Uniforms.h"
#import "TileInfo.h"

@implementation MetalViewController

- (void)loadView {
    self.view = [[NSView alloc] initWithFrame:CGRectMake(0, 0, 800, 600)];
    self.view.wantsLayer = YES;
    self.view.layer.backgroundColor = NSColor.blackColor.CGColor;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
   // [self setupMetal];
    // [self setupUI];
    // [self setupDistributedSystem];
     
}

- (void)setupMetal {
    self.device = MTLCreateSystemDefaultDevice();
    self.metalView = [[MTKView alloc] initWithFrame:self.view.bounds device:self.device];
    self.metalView.delegate = self;
    self.metalView.preferredFramesPerSecond = 60;
    self.metalView.framebufferOnly = NO;
    self.metalView.colorPixelFormat = MTLPixelFormatBGRA8Unorm;
    self.metalView.clearColor = MTLClearColorMake(0, 0, 0, 1);
    self.metalView.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    
    [self.view addSubview:self.metalView];
    
    self.commandQueue = [self.device newCommandQueue];
    
    
    //added for saving file
    // 建立 finalTexture：必須是 Shared 模式！
    MTLTextureDescriptor *textureDesc = [MTLTextureDescriptor texture2DDescriptorWithPixelFormat:MTLPixelFormatBGRA8Unorm
                                                                                              width:800
                                                                                             height:600
                                                                                          mipmapped:NO];
    textureDesc.storageMode = MTLStorageModeShared;      // 關鍵！
    textureDesc.usage = MTLTextureUsageShaderRead | MTLTextureUsageRenderTarget;
        
    self.finalTexture = [self.device newTextureWithDescriptor:textureDesc];
        
    // 清除為黑色
    [self.finalTexture replaceRegion:MTLRegionMake2D(0, 0, 800, 600)
                            mipmapLevel:0
                              withBytes:calloc(800*600*4, 1)
                            bytesPerRow:4*800];
    
    
    // 建立顯示用 pipeline
    id<MTLLibrary> library = [self.device newDefaultLibrary];
    MTLRenderPipelineDescriptor *desc = [MTLRenderPipelineDescriptor new];
    desc.vertexFunction = [library newFunctionWithName:@"vertexShader"];
    desc.fragmentFunction = [library newFunctionWithName:@"fragmentShader"];
    desc.colorAttachments[0].pixelFormat = MTLPixelFormatBGRA8Unorm;
    self.displayPipelineState = [self.device newRenderPipelineStateWithDescriptor:desc error:nil];
    
    self.samplerState = [self.device newSamplerStateWithDescriptor:[MTLSamplerDescriptor new]];
}

// 加上這段，解決 SwiftUI 呼叫問題
- (void)setupWithDevice:(id<MTLDevice>)device view:(MTKView *)view {
    NSLog(@"setupWithDevice:view: called");
    
    // 防止重複初始化（關鍵！）
    if (self.device != nil) {
        NSLog(@"Already setup, skipping");
        return;
    }
    
    self.device = device;
    self.metalView = view;
    self.metalView.delegate = self;
    
    self.commandQueue = [self.device newCommandQueue];
    
    // 建立 pipeline（只做一次）
    id<MTLLibrary> library = [self.device newDefaultLibrary];
    MTLRenderPipelineDescriptor *desc = [MTLRenderPipelineDescriptor new];
    desc.vertexFunction = [library newFunctionWithName:@"vertexShader"];
    desc.fragmentFunction = [library newFunctionWithName:@"fragmentShader"];
    desc.colorAttachments[0].pixelFormat = MTLPixelFormatBGRA8Unorm;
    self.displayPipelineState = [self.device newRenderPipelineStateWithDescriptor:desc error:nil];
    self.samplerState = [self.device newSamplerStateWithDescriptor:[MTLSamplerDescriptor new]];
    
    // 只建立一次 UI 和系統！
    [self setupUI];
    [self setupDistributedSystem];
}

- (void)setupUI {
    // Start Button
    self.startButton = [NSButton buttonWithTitle:@"Start Distributed Rendering"
                                          target:self
                                          action:@selector(startDistributedRendering)];
    self.startButton.frame = CGRectMake(50, 50, 400, 60);
    self.startButton.font = [NSFont systemFontOfSize:20 weight:NSFontWeightSemibold];
    self.startButton.bezelStyle = NSBezelStyleRounded;
    [self.view addSubview:self.startButton];
    
    // Progress
    self.progressIndicator = [[NSProgressIndicator alloc] initWithFrame:CGRectMake(50, 130, 400, 20)];
    self.progressIndicator.style = NSProgressIndicatorStyleBar;
    self.progressIndicator.indeterminate = NO;
    self.progressIndicator.doubleValue = 0;
    [self.view addSubview:self.progressIndicator];
    
    // Status Label
    self.statusLabel = [[NSTextField alloc] initWithFrame:CGRectMake(50, 170, 500, 40)];
    self.statusLabel.editable = NO;
    self.statusLabel.bezeled = NO;
    self.statusLabel.drawsBackground = NO;
    self.statusLabel.stringValue = @"Ready";
    self.statusLabel.textColor = [NSColor whiteColor];
    self.statusLabel.font = [NSFont systemFontOfSize:18];
    [self.view addSubview:self.statusLabel];
    
    // macOS 專用：用 layer zPosition 控制層級
    self.startButton.layer.zPosition = 1000;
    self.progressIndicator.layer.zPosition = 1000;
    self.statusLabel.layer.zPosition = 1000;
    
    // 確保 MTKView 在最底層
    self.metalView.layer.zPosition = -1000;
}

- (void)setupDistributedSystem {
    Uniforms *uniforms = [[Uniforms alloc] init];
    uniforms.cameraOrigin = (vector_float3){0, 0, 0};
    uniforms.lowerLeftCorner = (vector_float3){-2, -1.5, -1};
    uniforms.horizontal = (vector_float3){4, 0, 0};
    uniforms.vertical = (vector_float3){0, 3, 0};
    uniforms.lightPos = (vector_float3){0, 0, -2};
    uniforms.width = 800;
    uniforms.height = 600;
    uniforms.spheres = @[
        @{@"center": @[@(-1), @(0), @(-1)], @"radius": @0.5, @"color": @[@1,@0,@0], @"refractiveIndex": @1.5},
        @{@"center": @[@(0), @(0), @(-1)], @"radius": @0.5, @"color": @[@0,@1,@0], @"refractiveIndex": @1.5},
        @{@"center": @[@(1), @(0), @(-1)], @"radius": @0.5, @"color": @[@0,@0,@1], @"refractiveIndex": @1.5}
    ];
    
    self.taskManager = [[TaskManager alloc] initWithImageWidth:800
                                                        height:600
                                                      tileSize:CGSizeMake(100, 100)
                                                      uniforms:uniforms];
    self.taskManager.delegate = self;
    
    self.networkServer = [[NetworkServer alloc] initWithPort:8080 taskManager:self.taskManager];
    self.networkServer.delegate = self;
    [self.networkServer start];
    
    self.statusLabel.stringValue = @"Server running on 192.168.1.107:8080";
}

- (void)startDistributedRendering {
    self.statusLabel.stringValue = @"Waiting for workers...";
    self.progressIndicator.doubleValue = 0;
}

#pragma mark - TaskManagerDelegate（推薦使用這個！）

- (void)taskManager:(TaskManager *)manager didCompleteTask:(Task *)task withPixelData:(NSData *)pixelData {
    [self updateFinalTextureWithPixelData:pixelData atTile:task.tile];
    
    float progress = (float)manager.completedCount / manager.allTasks.count;
    dispatch_async(dispatch_get_main_queue(), ^{
        self.progressIndicator.doubleValue = progress * 100;
        self.statusLabel.stringValue = [NSString stringWithFormat:@"Completed %ld/48", manager.completedCount];
    });
}

- (void)taskManagerDidCompleteAllTasks:(TaskManager *)manager {
    dispatch_async(dispatch_get_main_queue(), ^{
        self.statusLabel.stringValue = @"All tasks completed! Saving...";
        // [self saveFinalImage];
    });
}

#pragma mark - 顯示最終圖像

- (void)updateFinalTextureWithPixelData:(NSData *)data atTile:(TileInfo *)tile {
    if (!self.finalTexture) {
        MTLTextureDescriptor *desc = [MTLTextureDescriptor texture2DDescriptorWithPixelFormat:MTLPixelFormatRGBA8Unorm
                                                                                       width:800
                                                                                      height:600
                                                                                   mipmapped:NO];
        desc.usage = MTLTextureUsageShaderRead;
        self.finalTexture = [self.device newTextureWithDescriptor:desc];
    }
    
    MTLRegion region = MTLRegionMake2D(tile.x, tile.y, tile.width, tile.height);
    [self.finalTexture replaceRegion:region
                         mipmapLevel:0
                           withBytes:data.bytes
                         bytesPerRow:tile.width * 4];
    
    // macOS 專用：不能用 setNeedsDisplay
    self.metalView.needsDisplay = YES;
}



- (void)drawInMTKView:(MTKView *)view {
    if (!self.finalTexture) return;
    
    id<MTLCommandBuffer> commandBuffer = [self.commandQueue commandBuffer];
    id<MTLRenderCommandEncoder> encoder = [commandBuffer renderCommandEncoderWithDescriptor:view.currentRenderPassDescriptor];
    
    [encoder setRenderPipelineState:self.displayPipelineState];
    [encoder setFragmentTexture:self.finalTexture atIndex:0];
    [encoder setFragmentSamplerState:self.samplerState atIndex:0];
    [encoder drawPrimitives:MTLPrimitiveTypeTriangleStrip vertexStart:0 vertexCount:4];
    
    [encoder endEncoding];
    [commandBuffer presentDrawable:view.currentDrawable];
    [commandBuffer commit];
}



- (void)mtkView:(MTKView *)view drawableSizeWillChange:(CGSize)size {
    // 什麼都不做也沒關係，但一定要有這個方法！
    // 否則 SwiftUI 的 MTKView 會呼叫它，導致 crash
}

#pragma mark - NetworkServerDelegate


- (void)networkServer:(NetworkServer *)server workerDidConnect:(WorkerConnection *)worker {
    NSLog(@"[MetalViewController] Worker 連線成功，立即派送任務");
    self.statusLabel.stringValue = [NSString stringWithFormat:@"Workers: %lu", (unsigned long)server.workers.count];
    // 新 worker 連進來，馬上派任務（TaskManager 已經自動處理）
}

- (void)networkServer:(NetworkServer *)server workerDidDisconnect:(WorkerConnection *)worker {
    NSLog(@"[MetalViewController] Worker 斷線");
    self.statusLabel.stringValue = [NSString stringWithFormat:@"Workers: %lu", (unsigned long)server.workers.count];
}


// 加入這段！
- (void)taskManager:(TaskManager *)manager didAssignTask:(JsonMessage *)taskMessage toWorker:(WorkerConnection *)worker {
    [self.networkServer sendMessage:taskMessage toWorker:worker];
}

- (void)networkServer:(NetworkServer *)server didReceiveBinaryResult:(NSData *)binary fromWorker:(WorkerConnection *)worker {
    NSLog(@"[DEBUG] Worker %p (socket: %ld) received binary", worker, (long)worker.nativeSocket);
    
    Task *task = [self.taskManager taskForWorker:worker];
    if (!task) {
        NSLog(@"[DEBUG] NO TASK FOUND for worker %p", worker);
        return;
    }
    
    NSLog(@"[DEBUG] Rendering task %ld (tile: %ld,%ld) for worker %p",
          task.taskId, (long)task.tile.x, (long)task.tile.y, worker);
    
    if (binary.length != 40000) {
        NSLog(@"Invalid binary length: %lu", (unsigned long)binary.length);
        return;
    }
    
    [self updateFinalTextureWithPixelData:binary atTile:task.tile];
    [self.taskManager markTaskAsCompleted:task.taskId fromWorker:worker pixelData:binary];
    // 全部完成就存圖！
    if (self.taskManager.completedCount == 48) {
        NSLog(@"所有 48 個 tile 完成！開始存圖...");
        [self saveFinalTextureAsPNG];
    }
}

#pragma mark - Legacy (為了協議相容)
- (void)networkServer:(NetworkServer *)server didReceiveResult:(JsonMessage *)result fromWorker:(WorkerConnection *)worker {
    // 現在用純 binary，不處理 JSON result
    NSLog(@"[Legacy] Received JSON result (ignored)");
}

// 新增這個方法！
// 關鍵修正：上下翻轉！
// 目前是配合 cuda client 的計算,之後要考慮其他異質 client 平台
/*
 
 來源平台傳回的 binary 第0行代表在 macOS Metal 上貼是否正確？存 PNG 時是否需要翻轉？Jetson (CUDA)畫面最上面正確（直接貼）需要！（存圖時）MacBook (Metal)畫面最上面正確（直接貼）需要！（存圖時）Windows (CUDA)畫面最上面正確（直接貼）需要！（存圖時）
 顯示永遠正確（因為 Metal 吃得懂）
 存圖永遠需要手動翻轉（因為 CGContext 吃不懂）
 
 
 */
- (void)saveFinalTextureAsPNG {
    if (!self.finalTexture) return;
    
    // 1. 複製到 CPU buffer
    NSUInteger w = 800, h = 600, rowBytes = 4 * w;
    id<MTLBuffer> buffer = [self.device newBufferWithLength:rowBytes * h
                                                    options:MTLResourceStorageModeShared];
    id<MTLCommandBuffer> cmd = [self.commandQueue commandBuffer];
    id<MTLBlitCommandEncoder> blit = [cmd blitCommandEncoder];
    [blit copyFromTexture:self.finalTexture
              sourceSlice:0 sourceLevel:0 sourceOrigin:MTLOriginMake(0,0,0)
               sourceSize:MTLSizeMake(w,h,1)
                 toBuffer:buffer destinationOffset:0
           destinationBytesPerRow:rowBytes destinationBytesPerImage:0];
    [blit endEncoding];
    [cmd commit];
    [cmd waitUntilCompleted];
    
    uint8_t *src = buffer.contents;
    
    // 2. 手動翻轉（永遠需要！）
    uint8_t *flipped = malloc(rowBytes * h);
    for (int y = 0; y < h; y++) {
        memcpy(flipped + y * rowBytes,
               src + (h - 1 - y) * rowBytes,
               rowBytes);
    }
    
    // 3. 用翻轉後的資料存圖
    CGColorSpaceRef cs = CGColorSpaceCreateDeviceRGB();
    CGContextRef ctx = CGBitmapContextCreate(flipped, w, h, 8, rowBytes, cs,
                                             kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big);
    CGImageRef img = CGBitmapContextCreateImage(ctx);
    
    NSString *path = [NSSearchPathForDirectoriesInDomains(NSDesktopDirectory, NSUserDomainMask, YES).firstObject
                      stringByAppendingPathComponent:@"distribute_ray_tracing_output.png"];
    CFURLRef url = (__bridge CFURLRef)[NSURL fileURLWithPath:path];
    CGImageDestinationRef dest = CGImageDestinationCreateWithURL(url, kUTTypePNG, 1, NULL);
    CGImageDestinationAddImage(dest, img, nil);
    CGImageDestinationFinalize(dest);
    
    CFRelease(dest);
    CGImageRelease(img);
    CGContextRelease(ctx);
    CGColorSpaceRelease(cs);
    free(flipped);
    
    NSLog(@"完美圖片已儲存（已修正方向）：%@", path);
}

@end
