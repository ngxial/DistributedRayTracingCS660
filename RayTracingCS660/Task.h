//
//  Task.h
//  RayTracingCS660
//
//  Created by ngxial on 2025/11/27.
//

#ifndef Task_h
#define Task_h
#import <Foundation/Foundation.h>
#import "TileInfo.h"
#import "JsonMessage.h"
#import "WorkerConnection.h"

typedef NS_ENUM(NSInteger, TaskStatus) {
    TaskStatusPending,
    TaskStatusAssigned,
    TaskStatusCompleted,
    TaskStatusFailed
};

@interface Task : NSObject

@property (nonatomic, assign) NSInteger taskId;
@property (nonatomic, strong) TileInfo *tile;
@property (nonatomic, strong) JsonMessage *assignedMessage;
@property (nonatomic, assign) TaskStatus status;
@property (nonatomic, assign) NSInteger retryCount;
@property (nonatomic, strong) NSDate *assignedTime;
@property (nonatomic, weak) WorkerConnection *worker;

@end

#endif /* Task_h */
