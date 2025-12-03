//
//  WorkerConnection.m
//  RayTracingCS660
//
//  Created by ngxial on 2025/11/25.
//

#import <Foundation/Foundation.h>
#import "WorkerConnection.h"

@implementation WorkerConnection

- (instancetype)initWithNativeSocket:(CFSocketNativeHandle)socket {
    self = [super init];
    if (self) {
        _nativeSocket = socket;
        _incomingBuffer = [NSMutableData data];
    }
    return self;
}

@end
