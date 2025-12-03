//
//  JsonMessage.h
//  RayTracingCS660
//
//  Created by ngxial on 2025/11/24.
//

#ifndef JsonMessage_h
#define JsonMessage_h

#import <Foundation/Foundation.h>
#import <simd/simd.h>
// 直接 import 獨立的 header，不再自己定義
#import "TileInfo.h"
#import "Uniforms.h"

typedef NS_ENUM(NSInteger, JsonMessageType) {
    JsonMessageTypeTask,
    JsonMessageTypeResult,
    JsonMessageTypeCommand,
    JsonMessageTypeStatus,
    JsonMessageTypeHeartbeat
};





@interface JsonMessage : NSObject

@property (nonatomic, strong, readonly) NSString *msgId;
@property (nonatomic, assign, readonly) JsonMessageType type;
@property (nonatomic, strong, readonly) NSDictionary *header;
@property (nonatomic, strong, readonly) NSDictionary *body;
@property (nonatomic, assign, readonly) NSUInteger messageLength;

// 工廠方法：建立任務訊息
+ (instancetype)taskMessageWithJobId:(NSString *)jobId
                              taskId:(NSInteger)taskId
                                tile:(TileInfo *)tile
                            uniforms:(Uniforms *)uniforms
                             timeout:(NSInteger)timeoutMs;

// 工廠方法：建立結果訊息（Jetson 回傳用）
+ (instancetype)resultMessageWithTaskId:(NSInteger)taskId
                                 jobId:(NSString *)jobId
                                status:(BOOL)success
                            pixelData:(NSData *)pixelData
                        computeTimeMs:(NSInteger)computeTimeMs
                                error:(NSString *)error;

// 工廠方法：心跳
+ (instancetype)heartbeatMessageWithWorkerId:(NSString *)workerId;

// 從完整 JSON 字串解析
+ (instancetype)messageFromJsonString:(NSString *)jsonString error:(NSError **)error;

// 序列化成字串（含正確的 msg_len）
- (NSString *)toJsonString;

// 驗證 msg_len 是否正確
- (BOOL)validateLength;

@end
#endif /* JsonMessage_h */

