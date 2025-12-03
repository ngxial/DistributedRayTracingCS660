import numpy as np
import math
from PIL import Image

# Uniforms 結構
class SphereData:
    def __init__(self, center, radius, color, refractiveIndex):
        self.center = np.array(center, dtype=np.float32)
        self.radius = radius
        self.color = np.array(color, dtype=np.float32)
        self.refractiveIndex = refractiveIndex

class Uniforms:
    def __init__(self):
        self.cameraOrigin = np.array([0.0, 0.0, 0.0], dtype=np.float32)
        self.lowerLeftCorner = np.array([-2.0, -1.5, -1.0], dtype=np.float32)
        self.horizontal = np.array([4.0, 0.0, 0.0], dtype=np.float32)
        self.vertical = np.array([0.0, 3.0, 0.0], dtype=np.float32)
    #    self.lightPos = np.array([2.0, 0.0, -2.0], dtype=np.float32)  # 調整光源 1
    #    self.lightPos = np.array([0.0, 2.0, -2.0], dtype=np.float32)  # 調整光源 2 紅球和綠球 final_color 達 3.072823，建議全局 max_final_color = 3.072823。
        self.lightPos = np.array([0.0, 0.0, -2.0], dtype=np.float32)  # 後方光源 3
    #    self.lightPos = np.array([2.0, 0.0, -2.0], dtype=np.float32)  # 調整光源
    #    self.lightPos = np.array([0.0, 0.0, 2.0], dtype=np.float32)  # 前方光源
        self.width = 200
        self.height = 150
        self.spheres = [
            SphereData([-1.0, 0.0, -1.0], 0.5, [1.0, 0.0, 0.0], 1.5),
            SphereData([0.0, 0.0, -1.0], 0.5, [0.0, 1.0, 0.0], 1.5),
            SphereData([1.0, 0.0, -1.0], 0.5, [0.0, 0.0, 1.0], 1.5)
        ]

def normalize(v):
    norm = np.linalg.norm(v)
    return v / norm if norm > 0 else np.array([0.0, 0.0, 0.0])

def hit_sphere(ray_origin, ray_direction, sphere):
    oc = ray_origin - sphere.center
    a = np.dot(ray_direction, ray_direction)
    b = 2.0 * np.dot(oc, ray_direction)
    c = np.dot(oc, oc) - sphere.radius * sphere.radius
    discriminant = b * b - 4 * a * c
    if discriminant > 0:
        t1 = (-b - math.sqrt(discriminant)) / (2.0 * a)
        t2 = (-b + math.sqrt(discriminant)) / (2.0 * a)
        if t1 > 0.001:
            return t1, normalize(ray_origin + t1 * ray_direction - sphere.center)
        if t2 > 0.001:
            return t2, normalize(ray_origin + t2 * ray_direction - sphere.center)
    return float('inf'), np.array([0.0, 0.0, 0.0])

# 主計算邏輯
uniforms = Uniforms()
# 創建圖像陣列
image = np.zeros((uniforms.height, uniforms.width, 3), dtype=np.uint8)
# max_final_color = 0.0  # 動態跟踪最大 final_color
max_final_color = 2.662796 #修正 max_final_color
with open('ray_tracing_log_reduced.txt', 'w') as f:
    for y in range(uniforms.height):
        for x in range(uniforms.width):
            
            max_final_color = 2.662796 #確保 max_final_color 2.662796
            uv = np.array([x / (uniforms.width - 1), y / (uniforms.height - 1)], dtype=np.float32)
            ray_direction = normalize(uniforms.lowerLeftCorner + uv[0] * uniforms.horizontal + uv[1] * uniforms.vertical - uniforms.cameraOrigin)
            t_hit = float('inf')
            normal = np.array([0.0, 0.0, 0.0], dtype=np.float32)
            color = np.array([0.0, 0.0, 0.0], dtype=np.float32)
            for i, sphere in enumerate(uniforms.spheres):
                t, n = hit_sphere(uniforms.cameraOrigin, ray_direction, sphere)
                if t < t_hit and t > 0.001:
                    t_hit = t
                    normal = n
                    color = sphere.color
    #       if t_hit != float('inf') and color[1] == 1.0:  # 僅處理紅球
            if t_hit != float('inf'):  # 僅處理紅球
                if color[1] == 1.0:
                    max_final_color=2.794101
                else:
                    max_final_color = 3.072823

                normal = -normal
                hit_point = uniforms.cameraOrigin + t_hit * ray_direction
                light_dir = normalize(uniforms.lightPos - hit_point)
                dot_product = np.dot(normal, light_dir)
                print(f"Dot product: {dot_product}")  # 調試輸出
                diffuse_factor = max(0.0, dot_product)
                ambient = np.array([0.2, 0.2, 0.2])
                final_color = color * (1.0 + 2.0 * diffuse_factor) + ambient  # 原始增益
                #max_final_color = max(max_final_color, final_color[0])  # 跟踪最大 R 分量
                max_final_color = min(max_final_color,max(max_final_color, final_color[0]))  # 跟踪最大 R 分量
                mapped_color = (final_color / max_final_color) * 255  # 動態映射
                mapped_color = np.clip(mapped_color, 0, 255).astype(np.uint8)  # 確保在有效範圍
                image[y, x] = mapped_color  # 使用映射後的顏色
                print(f"Pixel ({x}, {y}), uv=({uv[0]:.6f}, {uv[1]:.6f}), t_hit={t_hit:.6f}, normal=({normal[0]:.6f}, {normal[1]:.6f}, {normal[2]:.6f}), "
                      f"lightDir=({light_dir[0]:.6f}, {light_dir[1]:.6f}, {light_dir[2]:.6f}), dot_product={dot_product:.6f}, "
                      f"final_color=({final_color[0]:.6f}, {final_color[1]:.6f}, {final_color[2]:.6f}), max_final_color={max_final_color:.6f}, mapped_color=({mapped_color[0]:.6f}, {mapped_color[1]:.6f}, {mapped_color[2]:.6f})\n")
                f.write(f"Pixel ({x}, {y}), uv=({uv[0]:.6f}, {uv[1]:.6f}), t_hit={t_hit:.6f}, normal=({normal[0]:.6f}, {normal[1]:.6f}, {normal[2]:.6f}), "
                        f"lightDir=({light_dir[0]:.6f}, {light_dir[1]:.6f}, {light_dir[2]:.6f}), dot_product={dot_product:.6f}, "
                        f"final_color=({final_color[0]:.6f}, {final_color[1]:.6f}, {final_color[2]:.6f}), max_final_color={max_final_color:.6f}, mapped_color=({mapped_color[0]:.6f}, {mapped_color[1]:.6f}, {mapped_color[2]:.6f})\n")
                f.flush()  # 強制寫入
            else:
                continue  # 忽略其他像素，不寫入日誌
  # 保存為 PNG
img = Image.fromarray(image)
img.save('ray_tracing_log_reduced_remove_clipped_color_for_red_sphere.png')
print("Log file 'ray_tracing_log_reduced.txt' and PNG file 'ray_tracing_log_reduced_remove_clipped_color_for_red_sphere.png' generated.")