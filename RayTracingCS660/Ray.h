//
//  Ray.h
//  RayTracingCS660
//
//  Created by ngxial on 2025/7/17.
//

#ifndef Ray_h
#define Ray_h

#import <Metal/Metal.h>
#import <simd/simd.h> // 確保包含 SIMD 支援

@interface Ray : NSObject
@property (nonatomic, assign) vector_float3 origin;
@property (nonatomic, assign) vector_float3 direction;
- (instancetype)initWithOrigin:(vector_float3)origin direction:(vector_float3)direction;
- (vector_float3)pointAtParameter:(float)t;
@end

#endif /* Ray_h */
