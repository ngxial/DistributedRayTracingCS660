//
//  NetworkServer.h
//  RayTracingCS660
//
//  Created by ngxial on 2025/11/24.
//

#ifndef NetworkServer_h
#define NetworkServer_h

#import <Foundation/Foundation.h>
#import "TaskManager.h"
#import "JsonMessage.h"
#import "WorkerConnection.h"  // 現在公開了！

@class NetworkServer;

@protocol NetworkServerDelegate <NSObject>
- (void)networkServer:(NetworkServer *)server didReceiveResult:(JsonMessage *)result fromWorker:(WorkerConnection *)worker;
- (void)networkServer:(NetworkServer *)server didReceiveBinaryResult:(NSData *)binary fromWorker:(WorkerConnection *)worker;
- (void)networkServer:(NetworkServer *)server workerDidConnect:(WorkerConnection *)worker;
- (void)networkServer:(NetworkServer *)server workerDidDisconnect:(WorkerConnection *)worker;

@end

@interface NetworkServer : NSObject

@property (nonatomic, weak) id<NetworkServerDelegate> delegate;
@property (nonatomic, strong, readonly) TaskManager *taskManager;
@property (nonatomic, assign, readonly) uint16_t port;
@property (nonatomic, assign, readonly) BOOL isRunning;
@property (nonatomic, strong, readonly) NSArray<WorkerConnection *> *workers;  // 加上這行！


- (instancetype)initWithPort:(uint16_t)port taskManager:(TaskManager *)taskManager;
- (BOOL)start;
- (void)stop;

- (void)sendMessage:(JsonMessage *)message toWorker:(WorkerConnection *)worker;
- (void)broadcastMessage:(JsonMessage *)message;

@end
#endif /* NetworkServer_h */
