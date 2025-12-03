//
//  TaskManager.h
//  RayTracingCS660 - 生產級強化版
//

#import <Foundation/Foundation.h>
#import "JsonMessage.h"
#import "TileInfo.h"
#import "Uniforms.h"
#import "WorkerConnection.h"

@class TaskManager;

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

@protocol TaskManagerDelegate <NSObject>
- (void)taskManager:(TaskManager *)manager didCompleteTask:(Task *)task withPixelData:(NSData *)pixelData;
- (void)taskManagerDidCompleteAllTasks:(TaskManager *)manager;

// 新增這一行！
- (void)taskManager:(TaskManager *)manager didAssignTask:(JsonMessage *)taskMessage toWorker:(WorkerConnection *)worker;
@end

@interface TaskManager : NSObject

@property (nonatomic, weak) id<TaskManagerDelegate> delegate;
@property (nonatomic, strong, readonly) NSArray<Task *> *allTasks;
@property (nonatomic, assign, readonly) NSInteger completedCount;
@property (nonatomic, strong, readonly) NSString *currentJobId;

- (instancetype)initWithImageWidth:(NSUInteger)width
                             height:(NSUInteger)height
                           tileSize:(CGSize)tileSize
                           uniforms:(Uniforms *)uniforms;

// 核心 API
- (BOOL)assignTaskToWorker:(WorkerConnection *)worker;
- (void)markTaskAsCompleted:(NSInteger)taskId fromWorker:(WorkerConnection *)worker pixelData:(NSData *)data;
- (void)markTaskAsTimeout:(NSInteger)taskId;
- (void)retryFailedOrTimeoutTasks;

- (TaskStatus)statusOfTaskId:(NSInteger)taskId;
- (Task *)taskForWorker:(WorkerConnection *)worker;

@end
