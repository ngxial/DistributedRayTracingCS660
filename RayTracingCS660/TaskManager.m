
//
//  TaskManager.m
//  RayTracingCS660 - 生產級強化版
//

#import "TaskManager.h"



@interface TaskManager ()
@property (nonatomic, strong) NSMutableArray<Task *> *mutableTasks;
@property (nonatomic, strong) Uniforms *uniforms;
@property (nonatomic, assign) CGSize tileSize;

// 狀態集合
@property (nonatomic, strong) NSMutableSet<NSNumber *> *pendingTaskIds;
@property (nonatomic, strong) NSMutableSet<NSNumber *> *assignedTaskIds;
@property (nonatomic, strong) NSMutableSet<NSNumber *> *completedTaskIds;
@property (nonatomic, strong) NSMutableSet<NSNumber *> *failedTaskIds;

// 雙向映射（名稱與類型完全一致！）
@property (nonatomic, strong) NSMutableDictionary<NSNumber *, Task *> *connectionToTask;      // socketKey → Task
@property (nonatomic, strong) NSMutableDictionary<NSNumber *, NSNumber *> *taskIdToConnection; // taskId → socketKey
@end

@implementation TaskManager

- (instancetype)initWithImageWidth:(NSUInteger)width height:(NSUInteger)height tileSize:(CGSize)tileSize uniforms:(Uniforms *)uniforms {
    self = [super init];
    if (self) {
        _currentJobId = [NSString stringWithFormat:@"scene_%@", [[NSUUID UUID] UUIDString]];
        _tileSize = tileSize;
        _uniforms = uniforms;
        _mutableTasks = [NSMutableArray array];
        
        _pendingTaskIds = [NSMutableSet set];
        _assignedTaskIds = [NSMutableSet set];
        _completedTaskIds = [NSMutableSet set];
        _failedTaskIds = [NSMutableSet set];
        
        _connectionToTask = [NSMutableDictionary dictionary];
        _taskIdToConnection = [NSMutableDictionary dictionary];
        
        [self createTasksForWidth:width height:height];
        NSLog(@"TaskManager: Created %lu tasks for job %@", _mutableTasks.count, _currentJobId);
    }
    return self;
}

- (void)createTasksForWidth:(NSUInteger)width height:(NSUInteger)height {
    NSInteger tilesX = ceil(width / _tileSize.width);
    NSInteger tilesY = ceil(height / _tileSize.height);
    
    for (NSInteger y = 0; y < tilesY; y++) {
        for (NSInteger x = 0; x < tilesX; x++) {
            TileInfo *tile = [[TileInfo alloc] init];
            tile.x = x * _tileSize.width;
            tile.y = y * _tileSize.height;
            
            NSInteger tileW = MIN((NSInteger)_tileSize.width, width - tile.x);
            NSInteger tileH = MIN((NSInteger)_tileSize.height, height - tile.y);
            
            if (tileW <= 0 || tileH <= 0) continue;
            
            tile.width = tileW;
            tile.height = tileH;
            
            Task *task = [[Task alloc] init];
            task.taskId = _mutableTasks.count;  // taskId = array index
            task.tile = tile;
            task.status = TaskStatusPending;
            task.retryCount = 0;
            
            [_mutableTasks addObject:task];
            [_pendingTaskIds addObject:@(task.taskId)];
        }
    }
}

#pragma mark - 核心 API

- (BOOL)assignTaskToWorker:(WorkerConnection *)worker {
    
    // 關鍵！如果 worker 已經有 task，就不要再派！
    NSNumber *socketKey = @(worker.nativeSocket);
    if (_connectionToTask[socketKey]) {
        NSLog(@"[PROTECT] Worker %p already has task, skipping", worker);
        return NO;
    }
        
    if (_pendingTaskIds.count == 0) return NO;
    
    NSNumber *taskIdNum = [_pendingTaskIds anyObject];
    NSInteger taskId = taskIdNum.integerValue;
    Task *task = _mutableTasks[taskId];
    
    if (!task) return NO;
    
    task.status = TaskStatusAssigned;
    task.assignedTime = [NSDate date];
    task.worker = worker;
    task.retryCount++;
    
    [_pendingTaskIds removeObject:taskIdNum];
    [_assignedTaskIds addObject:taskIdNum];
    
    // 雙向映射（名稱與類型完全一致！）
    _connectionToTask[socketKey] = task;
    _taskIdToConnection[@(taskId)] = socketKey;
    
    JsonMessage *msg = [JsonMessage taskMessageWithJobId:_currentJobId
                                                  taskId:task.taskId
                                                    tile:task.tile
                                                uniforms:_uniforms
                                                 timeout:15000];
    task.assignedMessage = msg;
    
    if ([self.delegate respondsToSelector:@selector(taskManager:didAssignTask:toWorker:)]) {
        [self.delegate taskManager:self didAssignTask:msg toWorker:worker];
    }
    
    NSLog(@"Assigned task %ld to worker %p (socket: %ld)", task.taskId, worker, (long)worker.nativeSocket);
    return YES;
}

- (void)markTaskAsCompleted:(NSInteger)taskId fromWorker:(WorkerConnection *)worker pixelData:(NSData *)data {
   
    NSLog(@"[DEBUG] markTaskAsCompleted: taskId=%ld, worker=%p (socket=%ld)", taskId, worker, (long)worker.nativeSocket);
    NSNumber *taskIdNum = @(taskId);
    if ([_completedTaskIds containsObject:taskIdNum]) {
        NSLog(@"Task %ld already completed, ignoring duplicate", taskId);
        [self assignTaskToWorker:worker];  // 立刻再派下一個
        return;
    }
    
    Task *task = _mutableTasks[taskId];
    if (!task) {
        NSLog(@"Task %ld not found", taskId);
        return;
    }
    
    task.status = TaskStatusCompleted;
    [_assignedTaskIds removeObject:taskIdNum];
    [_completedTaskIds addObject:taskIdNum];
    
    
    // 關鍵修正！正確清理 mapping
    NSNumber *socketKey = _taskIdToConnection[taskIdNum];  // 用 taskId 找對應的 socket
    NSLog(@"[DEBUG] CLEANUP: socketKey=%@ for taskId=%ld", socketKey, taskId);
    
    [_connectionToTask removeObjectForKey:socketKey];      // 清理 socket → task
    [_taskIdToConnection removeObjectForKey:taskIdNum];    // 清理 taskId → socket
    
    NSLog(@"[DEBUG] After cleanup - connectionToTask count: %lu", (unsigned long)_connectionToTask.count);
    
    
    // 通知渲染
    if ([self.delegate respondsToSelector:@selector(taskManager:didCompleteTask:withPixelData:)]) {
        [self.delegate taskManager:self didCompleteTask:task withPixelData:data];
    }
    
    // 檢查是否全部完成
    if (_completedTaskIds.count == _mutableTasks.count) {
        if ([self.delegate respondsToSelector:@selector(taskManagerDidCompleteAllTasks:)]) {
            [self.delegate taskManagerDidCompleteAllTasks:self];
        }
    } else {
        // 立刻再派下一個任務給這個 worker
        if (_pendingTaskIds.count > 0) {
            NSLog(@"[DEBUG] Reassigning to worker, pending=%lu", (unsigned long)_pendingTaskIds.count);
            [self assignTaskToWorker:worker];
        }
    }
    
    NSLog(@"Task %ld completed by worker %p", taskId, worker);
}

- (TaskStatus)statusOfTaskId:(NSInteger)taskId {
    NSNumber *tid = @(taskId);
    if ([_completedTaskIds containsObject:tid]) return TaskStatusCompleted;
    if ([_assignedTaskIds containsObject:tid]) return TaskStatusAssigned;
    if ([_pendingTaskIds containsObject:tid]) return TaskStatusPending;
    if ([_failedTaskIds containsObject:tid]) return TaskStatusFailed;
    return TaskStatusPending;
}

- (Task *)taskForWorker:(WorkerConnection *)worker {
    NSNumber *socketKey = @(worker.nativeSocket);
    return _connectionToTask[socketKey];
}

- (NSInteger)completedCount {
    return _completedTaskIds.count;
}

- (NSArray<Task *> *)allTasks {
    return [_mutableTasks copy];
}

#pragma mark - 超時與重試

- (void)checkForTimeouts {
    NSDate *now = [NSDate date];
    for (NSNumber *taskIdNum in [_assignedTaskIds copy]) {
        Task *task = _mutableTasks[taskIdNum.integerValue];
        if ([now timeIntervalSinceDate:task.assignedTime] > 15.0) {
            NSLog(@"Task %ld timeout, reassigning...", task.taskId);
            [self markTaskAsTimeout:task.taskId];
        }
    }
}

/*
- (void)markTaskAsTimeout:(NSInteger)taskId {
    Task *task = _mutableTasks[taskId];
    if (!task) return;
    
    NSNumber *taskIdNum = @(taskId);
    NSNumber *socketKey = _taskIdToConnection[taskIdNum];
    WorkerConnection *worker = nil;
    
    // 從 socketKey 找 worker（如果有的話）
    if (socketKey) {
        for (WorkerConnection *w in [[NetworkServer shared] workers]) {
            if (@(w.nativeSocket) == socketKey) {
                worker = w;
                break;
            }
        }
    }
    
    task.status = TaskStatusFailed;
    task.worker = nil;
    
    [_assignedTaskIds removeObject:taskIdNum];
    [_failedTaskIds addObject:taskIdNum];
    [_connectionToTask removeObjectForKey:socketKey];
    [_taskIdToConnection removeObjectForKey:taskIdNum];
    
    [self retryFailedOrTimeoutTasks];
}
*/

- (void)markTaskAsTimeout:(NSInteger)taskId {
    Task *task = _mutableTasks[taskId];
    if (!task) return;
    
    NSNumber *taskIdNum = @(taskId);
    NSNumber *socketKey = _taskIdToConnection[taskIdNum];
    
    task.status = TaskStatusFailed;
    task.worker = nil;  // 清理 worker 參考
    
    [_assignedTaskIds removeObject:taskIdNum];
    [_failedTaskIds addObject:taskIdNum];
    [_connectionToTask removeObjectForKey:socketKey];
    [_taskIdToConnection removeObjectForKey:taskIdNum];
    
    [self retryFailedOrTimeoutTasks];
}





- (void)retryFailedOrTimeoutTasks {
    for (NSNumber *taskIdNum in [_failedTaskIds copy]) {
        if ([_pendingTaskIds containsObject:taskIdNum]) continue;
        [_pendingTaskIds addObject:taskIdNum];
        [_failedTaskIds removeObject:taskIdNum];
    }
}

@end

