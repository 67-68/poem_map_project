shader_type canvas_item;

// --- 灾变控制台 ---
uniform float infection_progress : hint_range(0.0, 1.0) = 0.0;
uniform vec2 origin_point = vec2(0.75, 0.25); 
uniform sampler2D noise_texture : repeat_enable;

uniform vec4 blood_color : source_color = vec4(0.5, 0.05, 0.05, 1.0); 
uniform vec4 edge_color : source_color = vec4(1.0, 0.0, 0.0, 1.0);   
uniform float edge_width : hint_range(0.0, 0.2) = 0.03;
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_nearest; // <-- 新增这     

void fragment() {
    vec4 original_color = texture(screen_texture, SCREEN_UV);
    
    if (original_color.a < 0.1) {
        COLOR = original_color;
    } else {
        float dist = distance(UV, origin_point);
        float noise_val = texture(noise_texture, UV).r;
        float distorted_dist = dist + (noise_val - 0.5) * 0.3; 
        
        float current_radius = infection_progress * 1.5;
        
        float is_infected = step(distorted_dist, current_radius);
        float is_edge = step(distorted_dist, current_radius) - step(distorted_dist, current_radius - edge_width);
        
        // 提取底图灰度，乘以暗红色
        float luminance = dot(original_color.rgb, vec3(0.299, 0.587, 0.114));
        vec3 dead_map = vec3(luminance) * blood_color.rgb * 2.5; 
        
        // 高频闪烁边缘
        float flicker = 0.7 + 0.6 * fract(sin(dot(UV + TIME * 4.0, vec2(12.9898, 78.233))) * 43758.5453);
        
        vec3 final_rgb = mix(original_color.rgb, dead_map, is_infected);
        final_rgb = mix(final_rgb, edge_color.rgb * flicker, is_edge * is_infected);
        
        COLOR = vec4(final_rgb, original_color.a);
    }
}