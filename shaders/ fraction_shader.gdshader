// 势力染色的东西
uniform sampler2D color_to_idx_map: hint_default_black, filter_nearest, repeat_disable;
uniform sampler2D faction_lut: filter_nearest, repeat_disable;
uniform float faction_intensity: hint_range(0.0, 1.0) = 1.0