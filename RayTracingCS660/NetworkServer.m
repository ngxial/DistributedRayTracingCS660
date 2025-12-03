//
//  NetworkServer.m
//  RayTracingCS660
//
//  Created by ngxial on 2025/11/24.
//

#import <Foundation/Foundation.h>
#import "NetworkServer.h"
#import "WorkerConnection.h"
#import <CFNetwork/CFNetwork.h>
// 必須加入這些 POSIX header 才能使用 socket 常數
#import <sys/socket.h>
#import <netinet/in.h>
#import <arpa/inet.h>
#import <unistd.h>


@interface NetworkServer () <NSStreamDelegate>
// 關鍵！去掉泛型！
@property (nonatomic, strong) NSMutableArray *workers;
@property (nonatomic, assign) CFSocketRef listeningSocket;
@end

@implementation NetworkServer

// init 裡保持不變
- (instancetype)initWithPort:(uint16_t)port taskManager:(TaskManager *)taskManager {
    self = [super init];
    if (self) {
        _port = port;
        _taskManager = taskManager;
        _workers = [NSMutableArray array];  // 這裡是 NSMutableArray！
        _isRunning = NO;
    }
    return self;
}

// 加上 getter，讓外部拿到只讀版本
- (NSArray<WorkerConnection *> *)workers {
    return [_workers copy];  // 外部拿到不可變副本
}

- (BOOL)start {
    if (_isRunning) return YES;
    
    CFSocketContext context = {0, (__bridge void *)self, NULL, NULL, NULL};
    _listeningSocket = CFSocketCreate(
        kCFAllocatorDefault,
        PF_INET,      // 現在可編譯
        SOCK_STREAM,  // 現在可編譯
        IPPROTO_TCP,  // 現在可編譯
        kCFSocketAcceptCallBack,
        AcceptCallback,
        &context
    );
    
    if (!_listeningSocket) {
        NSLog(@"[NetworkServer] Failed to create socket");
        return NO;
    }
    
    int yes = 1;
    setsockopt(CFSocketGetNative(_listeningSocket),
               SOL_SOCKET,     // 現在可編譯
               SO_REUSEADDR,   // 現在可編譯
               &yes, sizeof(yes));
    
    struct sockaddr_in addr = {0};
    addr.sin_len = sizeof(addr);
    addr.sin_family = AF_INET;           // 現在可編譯
    addr.sin_port = htons(self.port);
    addr.sin_addr.s_addr = htonl(INADDR_ANY);  // 現在可編譯
    
    CFDataRef addressData = CFDataCreate(NULL, (UInt8 *)&addr, sizeof(addr));
    CFSocketError err = CFSocketSetAddress(_listeningSocket, addressData);
    CFRelease(addressData);
    
    if (err != kCFSocketSuccess) {
        CFRelease(_listeningSocket);
        _listeningSocket = NULL;
        NSLog(@"[NetworkServer] Failed to bind to port %d", self.port);
        return NO;
    }
    
    CFRunLoopSourceRef source = CFSocketCreateRunLoopSource(kCFAllocatorDefault, _listeningSocket, 0);
    CFRunLoopAddSource(CFRunLoopGetCurrent(), source, kCFRunLoopCommonModes);
    CFRelease(source);
    
    _isRunning = YES;
    NSLog(@"[NetworkServer] Listening on 192.168.1.107:%d", self.port);
    return YES;
}

static void AcceptCallback(CFSocketRef s, CFSocketCallBackType type, CFDataRef address, const void *data, void *info) {
    if (type != kCFSocketAcceptCallBack) return;
    
    NetworkServer *server = (__bridge NetworkServer *)info;
    CFSocketNativeHandle nativeSocket = *(CFSocketNativeHandle *)data;
    [server handleNewConnection:nativeSocket];
}

- (void)handleNewConnection:(CFSocketNativeHandle)nativeSocketHandle {
    CFReadStreamRef readStream = NULL;
    CFWriteStreamRef writeStream = NULL;
    CFStreamCreatePairWithSocket(kCFAllocatorDefault, nativeSocketHandle, &readStream, &writeStream);
    
    if (!readStream || !writeStream) {
        close(nativeSocketHandle);
        return;
    }
    
    // 正確做法：只用 initWithNativeSocket: 設定一次
    WorkerConnection *worker = [[WorkerConnection alloc] initWithNativeSocket:nativeSocketHandle];
    worker.inputStream = (__bridge_transfer NSInputStream *)readStream;
    worker.outputStream = (__bridge_transfer NSOutputStream *)writeStream;
    
    // 設定 delegate 與 run loop
    [worker.inputStream setDelegate:self];
    [worker.outputStream setDelegate:self];
    [worker.inputStream scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
    [worker.outputStream scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
    [worker.inputStream open];
    [worker.outputStream open];
    
    // 加入管理陣列
 
    [_workers addObject:worker];

    
    
    
    
    NSLog(@"[NetworkServer] New worker connected (total: %lu)", (unsigned long)self.workers.count);
    
    // 通知 delegate
    if ([self.delegate respondsToSelector:@selector(networkServer:workerDidConnect:)]) {
        [self.delegate networkServer:self workerDidConnect:worker];
    }
    
    // 立即派送任務！
   //-- [self.taskManager dispatchNextAvailableTaskToWorker:worker];
    [self.taskManager assignTaskToWorker:worker];
}
/*
- (void)stream:(NSStream *)stream handleEvent:(NSStreamEvent)eventCode {
    if (eventCode & NSStreamEventHasBytesAvailable) {
        NSInputStream *input = (NSInputStream *)stream;
        uint8_t buffer[65536];
        NSInteger len = [input read:buffer maxLength:sizeof(buffer)];
        if (len > 0) {
            WorkerConnection *worker = [self workerForStream:input];
            if (worker) {
                [worker.incomingBuffer appendBytes:buffer length:len];
                [self processIncomingDataForWorker:worker];
            }
        }
    }
    
    if (eventCode & NSStreamEventEndEncountered) {
        WorkerConnection *worker = [self workerForStream:stream];
        if (worker) {
            [self disconnectWorker:worker];
        }
    }
}
 */

- (void)stream:(NSStream *)stream handleEvent:(NSStreamEvent)eventCode {
    if (eventCode & NSStreamEventHasBytesAvailable) {
        NSInputStream *input = (NSInputStream *)stream;
        uint8_t buffer[65536];
        NSInteger len = [input read:buffer maxLength:sizeof(buffer)];
        if (len > 0) {
            WorkerConnection *worker = [self workerForStream:input];
            if (worker) {
                [worker.incomingBuffer appendBytes:buffer length:len];
                if (worker.incomingBuffer.length >= 40000) {
                    NSData *pixelData = [worker.incomingBuffer subdataWithRange:NSMakeRange(0, 40000)];
                    [worker.incomingBuffer replaceBytesInRange:NSMakeRange(0, 40000) withBytes:NULL length:0];
                    NSLog(@"[NetworkServer] Received 40000 bytes binary from worker %p", worker);  // 加這行
                    if ([self.delegate respondsToSelector:@selector(networkServer:didReceiveBinaryResult:fromWorker:)]) {
                        [self.delegate networkServer:self didReceiveBinaryResult:pixelData fromWorker:worker];
                    }
                }
                // 立即再派下一個任務！（長連線的精髓）
                [self.taskManager assignTaskToWorker:worker];  // 加這行
            }
        }
    }
    
    if (eventCode & NSStreamEventEndEncountered) {
        WorkerConnection *worker = [self workerForStream:stream];
        if (worker) {
            [self disconnectWorker:worker];
        }
    }
}

- (WorkerConnection *)workerForStream:(NSStream *)stream {
    for (WorkerConnection *w in self.workers) {
        if (w.inputStream == stream || w.outputStream == stream) {
            return w;
        }
    }
    return nil;
}

- (void)processIncomingDataForWorker:(WorkerConnection *)worker {
    // 目前只支援 Jetson 回傳 40000 bytes binary（不含 JSON）
    if (worker.incomingBuffer.length >= 40000) {
        NSData *pixelData = [worker.incomingBuffer subdataWithRange:NSMakeRange(0, 40000)];
        [worker.incomingBuffer replaceBytesInRange:NSMakeRange(0, 40000) withBytes:NULL length:0];
        
        // 建立假的 result message（之後會改成完整 JsonMessage）
        JsonMessage *fakeResult = [JsonMessage resultMessageWithTaskId:0
                                                                 jobId:self.taskManager.currentJobId
                                                                status:YES
                                                             pixelData:pixelData
                                                         computeTimeMs:100
                                                                 error:nil];
        
        if ([self.delegate respondsToSelector:@selector(networkServer:didReceiveResult:fromWorker:)]) {
            [self.delegate networkServer:self didReceiveResult:fakeResult fromWorker:worker];
        }
        
        // 收到結果，馬上派下一個任務
        //--    [self.taskManager dispatchNextAvailableTaskToWorker:worker];
        [self.taskManager assignTaskToWorker:worker];
    }
}

#pragma mark - Message Sending

- (void)sendMessage:(JsonMessage *)message toWorker:(WorkerConnection *)worker {
    NSString *json = [message toJsonString];
    NSData *data = [json dataUsingEncoding:NSUTF8StringEncoding];
    
    // 改成：永遠嘗試送，不檢查 hasSpaceAvailable
    NSInteger totalWritten = 0;
    while (totalWritten < data.length) {
        NSInteger written = [worker.outputStream write:(uint8_t*)data.bytes + totalWritten
                                           maxLength:data.length - totalWritten];
        if (written <= 0) {
            NSLog(@"[NetworkServer] Failed to send message to worker (wrote %ld/%lu)",
                  (long)totalWritten, (unsigned long)data.length);
            return;
        }
        totalWritten += written;
        
        // 如果一次沒送完，稍微等一下
        if (written < data.length - totalWritten) {
            usleep(1000);  // 1ms
        }
    }
    
    NSLog(@"[NetworkServer] Sent %ld bytes to worker", (long)totalWritten);
}

- (void)broadcastMessage:(JsonMessage *)message {
    NSLog(@"[NetworkServer] Broadcasting message to %lu workers", (unsigned long)self.workers.count);
    for (WorkerConnection *worker in self.workers) {
        [self sendMessage:message toWorker:worker];
    }
}

- (void)disconnectWorker:(WorkerConnection *)worker {

    [_workers removeObject:worker];
    
    [worker.inputStream close];
    [worker.outputStream close];
    [worker.inputStream removeFromRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
    [worker.outputStream removeFromRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
    NSLog(@"[NetworkServer] Worker disconnected, %d remaining", (int)self.workers.count);
    
    if ([self.delegate respondsToSelector:@selector(networkServer:workerDidDisconnect:)]) {
        [self.delegate networkServer:self workerDidDisconnect:worker];
    }
}

- (void)stop {
    if (_listeningSocket) {
        CFSocketInvalidate(_listeningSocket);
        CFRelease(_listeningSocket);
        _listeningSocket = NULL;
    }
    for (WorkerConnection *w in self.workers) {
        [self disconnectWorker:w];
    }

    [_workers removeAllObjects];
    _isRunning = NO;
}

- (void)dealloc {
    [self stop];
}

@end
