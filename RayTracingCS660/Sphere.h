//
//  Sphere.h
//  RayTracingCS660
//
//  Created by ngxial on 2025/7/28.
//
#ifndef Sphere_h
#define Sphere_h
#import <Foundation/Foundation.h>
#import <simd/simd.h>
#import "Ray.h"

@interface Sphere : NSObject
@property (nonatomic, assign) vector_float3 center;
@property (nonatomic, assign) float radius;
@property (nonatomic, assign) vector_float3 color;
@property (nonatomic, assign) float refractiveIndex;
- (instancetype)initWithCenter:(vector_float3)center radius:(float)radius color:(vector_float3)color refractiveIndex:(float)refractiveIndex;
- (BOOL)hitWithRay:(Ray *)ray tMin:(float)tMin tMax:(float)tMax t:(float *)t normal:(vector_float3 *)normal;
@end

#endif /* Sphere_h */
