#include <metal_stdlib>
using namespace metal;

struct SphereData {
    float3 center;
    float radius;
    float3 color;
    float refractiveIndex;
};

struct Uniforms {
    float3 cameraOrigin;
    float3 lowerLeftCorner;
    float3 horizontal;
    float3 vertical;
    float3 lightPos;
    uint width;
    uint height;
    SphereData spheres[3];
};

struct LogEntry {
    float dotProduct;
    float3 finalColor;
    uint2 gid;
};

kernel void rayTracingCompute(uint2 gid [[thread_position_in_grid]],
                              constant Uniforms& uniforms [[buffer(0)]],
                              texture2d<float, access::write> outputTexture [[texture(0)]],
                              device LogEntry* logBuffer [[buffer(1)]]) {
    if (gid.x >= uniforms.width || gid.y >= uniforms.height) return;
    float2 uv = float2(gid) / float2(uniforms.width - 1, uniforms.height - 1);
    float3 rayDirection = normalize(uniforms.lowerLeftCorner + uv.x * uniforms.horizontal + uv.y * uniforms.vertical - uniforms.cameraOrigin);
    float t_hit = FLT_MAX;
    float3 normal = float3(0.0);
    float3 color = float3(0.0);
    float max_final_color = 3.072823;
    for (int i = 0; i < 3; i++) {
        SphereData sphere = uniforms.spheres[i];
        float3 oc = uniforms.cameraOrigin - sphere.center;
        float a = dot(rayDirection, rayDirection);
        float b = 2.0 * dot(oc, rayDirection);
        float c = dot(oc, oc) - sphere.radius * sphere.radius;
        float discriminant = b * b - 4 * a * c;
        if (discriminant > 0) {
            float t1 = (-b - sqrt(discriminant)) / (2.0 * a);
            float t2 = (-b + sqrt(discriminant)) / (2.0 * a);
            float t = (t1 > 0.001 && t1 < t_hit) ? t1 : ((t2 > 0.001 && t2 < t_hit) ? t2 : FLT_MAX);
            if (t != FLT_MAX) {
                t_hit = t;
                normal = normalize(uniforms.cameraOrigin + t * rayDirection - sphere.center);
                color = sphere.color;
                if (color.y == 1.0) { // 綠球
                    max_final_color = 2.794101;
                }
            }
        }
    }
    if (t_hit != FLT_MAX) {
        normal = -normal;
        float3 lightDir = normalize(uniforms.lightPos - (uniforms.cameraOrigin + t_hit * rayDirection));
        float dot_product = max(0.0, dot(normal, lightDir));
        float3 ambient = float3(0.6, 0.6, 0.6);
        float3 final_color = color * (1.0 + 2.0 * dot_product) + ambient;
        float3 mapped_color = (final_color / max_final_color) * 255.0;
        mapped_color = clamp(mapped_color, 0.0, 255.0);
        outputTexture.write(float4(mapped_color / 255.0, 1.0), gid);

        // 寫入日誌
        uint index = gid.y * uniforms.width + gid.x;
       
        //-- logBuffer[index].dotProduct = dot_product;
        //-- logBuffer[index].finalColor = final_color;
        //-- logBuffer[index].gid = gid;
        
        if (index >= 800 * 600) {
            logBuffer[index].dotProduct = -2.0; // 溢出
        } else if (t_hit == FLT_MAX) {
            logBuffer[index].dotProduct = -1.0; // 無交點
        } else {
            logBuffer[index].dotProduct = dot_product;
            // ...
        }
      //   logBuffer[index].dotProduct = dot_product;
        logBuffer[index].finalColor = final_color;
        logBuffer[index].gid = gid;
        
    } else {
        outputTexture.write(float4(0.0, 0.0, 0.0, 1.0), gid);
    }
}

struct VertexOut {
    float4 position [[position]];
    float2 uv;
};

vertex VertexOut vertexShader(uint vertexID [[vertex_id]]) {
    float2 positions[4] = { float2(-1, -1), float2(1, -1), float2(-1, 1), float2(1, 1) };
    VertexOut out;
    out.position = float4(positions[vertexID], 0.0, 1.0);
    out.uv = (positions[vertexID] + 1.0) * 0.5;
    return out;
}

fragment float4 fragmentShader(VertexOut in [[stage_in]],
                               texture2d<float> outputTexture [[texture(0)]],
                               sampler sam [[sampler(0)]]) {
    return outputTexture.sample(sam, in.uv);
}
