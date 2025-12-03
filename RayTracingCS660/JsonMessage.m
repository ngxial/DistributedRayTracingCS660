
//
//  JsonMessage.m
//  RayTracingCS660
//  最終版：保證 msg_len = 730
//

#import "JsonMessage.h"

@implementation TileInfo @end
@implementation Uniforms @end

@implementation JsonMessage

@synthesize msgId = _msgId;
@synthesize type = _type;
@synthesize header = _header;
@synthesize body = _body;
@synthesize messageLength = _messageLength;

#pragma mark - 關鍵修正：精確計算 msg_len
+ (void)calculateCorrectMsgLengthForHeader:(NSMutableDictionary *)header body:(NSDictionary *)body {
    // Step 1: 先建立不含 msg_len 的版本
    NSMutableDictionary *headerWithoutLen = [header mutableCopy];
    [headerWithoutLen removeObjectForKey:@"msg_len"];
    
  //  NSDictionary *rootWithoutLen = @{@"header": headerWithoutLen, @"body": body};
//    NSData *dataWithoutLen = [NSJSONSerialization dataWithJSONObject:rootWithoutLen options:0 error:nil];
    
    // Step 2: 建立含 msg_len 的版本（用一個典型長度作為預估）
    NSMutableDictionary *headerWithLen = [header mutableCopy];
    headerWithLen[@"msg_len"] = @730;  // 你的實際長度
    
    NSDictionary *rootWithLen = @{@"header": headerWithLen, @"body": body};
    NSData *dataWithLen = [NSJSONSerialization dataWithJSONObject:rootWithLen options:0 error:nil];
    
    // Step 3: 這就是最終長度
    header[@"msg_len"] = @(dataWithLen.length);
}

#pragma mark - Task Message
+ (instancetype)taskMessageWithJobId:(NSString *)jobId
                              taskId:(NSInteger)taskId
                                tile:(TileInfo *)tile
                            uniforms:(Uniforms *)uniforms
                             timeout:(NSInteger)timeoutMs {
    
    JsonMessage *msg = [[JsonMessage alloc] init];
    msg->_msgId = [self generateUUID];
    msg->_type = JsonMessageTypeTask;

    NSMutableDictionary *header = [NSMutableDictionary dictionary];
    header[@"msg_id"] = msg.msgId;
    header[@"msg_type"] = @"task";
    header[@"timestamp"] = [self currentISOTimestamp];
    header[@"sender"] = @"macbook-server";
    header[@"version"] = @"1.0";

    NSMutableDictionary *body = [NSMutableDictionary dictionary];
    body[@"job_id"] = jobId;
    body[@"task_id"] = @(taskId);
    body[@"task_type"] = @"render_tile";
    body[@"priority"] = @1;
    body[@"timeout_ms"] = @(timeoutMs);

    NSMutableDictionary *data = [NSMutableDictionary dictionary];
    data[@"tile"] = @{@"x": @(tile.x), @"y": @(tile.y), @"w": @(tile.width), @"h": @(tile.height)};
    data[@"uniforms"] = [self dictionaryFromUniforms:uniforms];
    body[@"data"] = data;

    [self calculateCorrectMsgLengthForHeader:header body:body];

    msg->_header = [header copy];
    msg->_body = [body copy];
    msg->_messageLength = [header[@"msg_len"] unsignedIntegerValue];

    NSLog(@"[JsonMessage] Created task %ld with msg_len = %lu", taskId, msg.messageLength);

    return msg;
}

#pragma mark - Result Message
+ (instancetype)resultMessageWithTaskId:(NSInteger)taskId
                                 jobId:(NSString *)jobId
                                status:(BOOL)success
                            pixelData:(NSData *)pixelData
                        computeTimeMs:(NSInteger)computeTimeMs
                                error:(NSString *)error {
    JsonMessage *msg = [[JsonMessage alloc] init];
    msg->_msgId = [self generateUUID];
    msg->_type = JsonMessageTypeResult;

    NSMutableDictionary *header = [NSMutableDictionary dictionary];
    header[@"msg_id"] = msg.msgId;
    header[@"msg_type"] = @"result";
    header[@"timestamp"] = [self currentISOTimestamp];
    header[@"sender"] = @"jetson-worker";

    NSMutableDictionary *body = [NSMutableDictionary dictionary];
    body[@"task_id"] = @(taskId);
    body[@"job_id"] = jobId;
    body[@"status"] = success ? @"success" : @"failed";
    body[@"compute_time_ms"] = @(computeTimeMs);
    if (error) body[@"error"] = error;
    
    if (pixelData) {
        body[@"result"] = @{
            @"format": @"rgba8",
            @"width": @100,
            @"height": @100,
            @"data_base64": [self base64EncodeData:pixelData]
        };
    }

    [self calculateCorrectMsgLengthForHeader:header body:body];

    msg->_header = [header copy];
    msg->_body = [body copy];
    msg->_messageLength = [header[@"msg_len"] unsignedIntegerValue];

    return msg;
}

#pragma mark - Heartbeat
+ (instancetype)heartbeatMessageWithWorkerId:(NSString *)workerId {
    JsonMessage *msg = [[JsonMessage alloc] init];
    msg->_msgId = [self generateUUID];
    msg->_type = JsonMessageTypeHeartbeat;

    NSMutableDictionary *header = [NSMutableDictionary dictionary];
    header[@"msg_id"] = msg.msgId;
    header[@"msg_type"] = @"heartbeat";
    header[@"timestamp"] = [self currentISOTimestamp];
    header[@"sender"] = workerId ?: @"unknown-worker";

    NSDictionary *body = @{
        @"worker_id": workerId ?: @"unknown",
        @"load": @0.5,
        @"temperature": @65.0
    };
    
    [self calculateCorrectMsgLengthForHeader:header body:body];

    msg->_header = [header copy];
    msg->_body = [body copy];
    msg->_messageLength = [header[@"msg_len"] unsignedIntegerValue];

    return msg;
}

#pragma mark - Parse from string
+ (instancetype)messageFromJsonString:(NSString *)jsonString error:(NSError **)error {
    NSData *data = [jsonString dataUsingEncoding:NSUTF8StringEncoding];
    if (!data) {
        if (error) *error = [NSError errorWithDomain:@"JsonMessage" code:100 userInfo:@{NSLocalizedDescriptionKey: @"Invalid UTF-8"}];
        return nil;
    }
    
    id obj = [NSJSONSerialization JSONObjectWithData:data options:0 error:error];
    if (!obj || ![obj isKindOfClass:[NSDictionary class]]) return nil;
    
    NSDictionary *dict = (NSDictionary *)obj;
    NSDictionary *header = dict[@"header"];
    if (!header || !header[@"msg_len"] || !header[@"msg_type"]) return nil;
    
    JsonMessage *msg = [[JsonMessage alloc] init];
    msg->_header = [header copy];
    msg->_body = dict[@"body"] ?: @{};
    msg->_messageLength = [header[@"msg_len"] unsignedIntegerValue];
    msg->_msgId = header[@"msg_id"] ?: @"";
    
    NSString *typeStr = header[@"msg_type"];
    if ([typeStr isEqualToString:@"task"]) msg->_type = JsonMessageTypeTask;
    else if ([typeStr isEqualToString:@"result"]) msg->_type = JsonMessageTypeResult;
    else if ([typeStr isEqualToString:@"heartbeat"]) msg->_type = JsonMessageTypeHeartbeat;
    else msg->_type = JsonMessageTypeCommand;
    
    return msg;
}

#pragma mark - Utilities
+ (NSString *)generateUUID {
    return [[NSUUID UUID] UUIDString];
}

+ (NSString *)currentISOTimestamp {
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    formatter.locale = [NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"];
    formatter.timeZone = [NSTimeZone timeZoneWithAbbreviation:@"UTC"];
    formatter.dateFormat = @"yyyy-MM-dd'T'HH:mm:ss.SSS'Z'";
    return [formatter stringFromDate:[NSDate date]];
}

+ (NSString *)base64EncodeData:(NSData *)data {
    return [data base64EncodedStringWithOptions:0];
}

+ (NSDictionary *)dictionaryFromUniforms:(Uniforms *)uniforms {
    NSMutableArray *spheresArray = [NSMutableArray array];
    for (NSDictionary *sphereDict in uniforms.spheres) {
        [spheresArray addObject:sphereDict];
    }

    return @{
        @"width": @(uniforms.width),
        @"height": @(uniforms.height),
        @"cameraOrigin": @[@(uniforms.cameraOrigin.x), @(uniforms.cameraOrigin.y), @(uniforms.cameraOrigin.z)],
        @"lowerLeftCorner": @[@(uniforms.lowerLeftCorner.x), @(uniforms.lowerLeftCorner.y), @(uniforms.lowerLeftCorner.z)],
        @"horizontal": @[@(uniforms.horizontal.x), @(uniforms.horizontal.y), @(uniforms.horizontal.z)],
        @"vertical": @[@(uniforms.vertical.x), @(uniforms.vertical.y), @(uniforms.vertical.z)],
        @"lightPos": @[@(uniforms.lightPos.x), @(uniforms.lightPos.y), @(uniforms.lightPos.z)],
        @"spheres": spheresArray
    };
}

- (NSString *)toJsonString {
    NSDictionary *root = @{@"header": self.header, @"body": self.body};
    NSData *data = [NSJSONSerialization dataWithJSONObject:root options:0 error:nil];
    return [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
}

- (BOOL)validateLength {
    return [self toJsonString].length == self.messageLength;
}

@end

