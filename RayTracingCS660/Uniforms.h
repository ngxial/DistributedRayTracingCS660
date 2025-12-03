//
//  Uniforms.h
//  RayTracingCS660
//
//  Created by ngxial on 2025/11/24.
//

#ifndef Uniforms_h
#define Uniforms_h
// Uniforms.h
#import <Foundation/Foundation.h>
#import <simd/simd.h>

@interface Uniforms : NSObject
@property (nonatomic, assign) vector_float3 cameraOrigin;
@property (nonatomic, assign) vector_float3 lowerLeftCorner;
@property (nonatomic, assign) vector_float3 horizontal;
@property (nonatomic, assign) vector_float3 vertical;
@property (nonatomic, assign) vector_float3 lightPos;
@property (nonatomic, assign) NSUInteger width;
@property (nonatomic, assign) NSUInteger height;
@property (nonatomic, strong) NSArray<NSDictionary *> *spheres;
@end
#endif /* Uniforms_h */
