//
//  WorkerConnection.h
//  RayTracingCS660
//
//  Created by ngxial on 2025/11/25.
//

#ifndef WorkerConnection_h
#define WorkerConnection_h
#import <Foundation/Foundation.h>

@interface WorkerConnection : NSObject

@property (nonatomic, assign) CFSocketNativeHandle nativeSocket;
@property (nonatomic, strong) NSInputStream *inputStream;
@property (nonatomic, strong) NSOutputStream *outputStream;
@property (nonatomic, strong) NSMutableData *incomingBuffer;

- (instancetype)initWithNativeSocket:(CFSocketNativeHandle)socket;

@end

#endif /* WorkerConnection_h */
