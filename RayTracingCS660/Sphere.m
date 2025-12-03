//
//  Sphere.m
//  RayTracingCS660
//
//  Created by ngxial on 2025/7/28.
//

#import "Sphere.h"
#import "Ray.h"
#import "Sphere.h"

@implementation Sphere
- (instancetype)initWithCenter:(vector_float3)center radius:(float)radius color:(vector_float3)color refractiveIndex:(float)refractiveIndex {
    self = [super init];
    if (self) {
        _center = center;
        _radius = radius;
        _color = color;
        _refractiveIndex = refractiveIndex;
    }
    return self;
}

- (BOOL)hitWithRay:(Ray *)ray tMin:(float)tMin tMax:(float)tMax t:(float *)t normal:(vector_float3 *)normal {
    vector_float3 oc = ray.origin - _center;
    float a = simd_dot(ray.direction, ray.direction);
    float b = 2.0 * simd_dot(oc, ray.direction);
    float c = simd_dot(oc, oc) - _radius * _radius;
    float discriminant = b * b - 4 * a * c;

    
    if (discriminant > 0) {
        
        float temp = (-b - sqrt(discriminant)) / (2.0 * a);
        //debug info
        
        NSLog(@"Discriminant: %f, temp1: %f, temp2: %f", discriminant, temp, (-b + sqrt(discriminant)) / (2.0 * a));

        if (temp < tMax && temp > tMin) {
            *t = temp;
            *normal = simd_normalize((ray.origin + temp * ray.direction) - _center); // 法線
            return YES;
        }
        temp = (-b + sqrt(discriminant)) / (2.0 * a);
        if (temp < tMax && temp > tMin) {
            *t = temp;
            *normal = simd_normalize((ray.origin + temp * ray.direction) - _center); // 法線
            return YES;
        }
    }
    return NO;
}
@end
