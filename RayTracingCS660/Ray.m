//
//  Ray.m
//  RayTracingCS660
//
//  Created by ngxial on 2025/7/17.
//

#import <Foundation/Foundation.h>
#import "Ray.h"


@implementation Ray
- (instancetype)initWithOrigin:(vector_float3)origin direction:(vector_float3)direction {
    self = [super init];
    if (self) {
        _origin = origin;
  //      _direction = direction;
        _direction = simd_normalize(direction);
    }
    return self;
}

- (vector_float3)pointAtParameter:(float)t {
    return _origin + t * _direction;
}
@end
