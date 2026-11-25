shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

group_uniforms road_appearance;
uniform vec3 road_color : source_color = vec3(0.16, 0.16, 0.17);
uniform vec3 wear_color : source_color = vec3(0.22, 0.22, 0.23);
uniform vec3 shoulder_color : source_color = vec3(0.26, 0.23, 0.19);
uniform float road_roughness : hint_range(0.2, 1.0, 0.02) = 0.88;
uniform float grain_scale : hint_range(1.0, 30.0, 0.5) = 12.0;
uniform float bump_strength : hint_range(0.0, 1.0, 0.02) = 0.18;
uniform float edge_blend : hint_range(0.0, 0.25, 0.01) = 0.08;
uniform float shoulder_amount : hint_range(0.0, 1.0, 0.01) = 0.65;
uniform float tire_wear_strength : hint_range(0.0, 1.0, 0.01) = 0.35;

group_uniforms road_markings;
uniform bool show_center_line = false;
uniform vec3 line_color : source_color = vec3(0.86, 0.73, 0.28);
uniform float line_width : hint_range(0.004, 0.1, 0.001) = 0.016;
uniform bool solid_center_line = false;
uniform float dash_period : hint_range(0.5, 10.0, 0.1) = 2.5;
uniform float dash_fill : hint_range(0.1, 0.95, 0.01) = 0.56;
uniform bool show_edge_lines = false;
uniform vec3 edge_line_color : source_color = vec3(0.9, 0.9, 0.88);
uniform float edge_line_inset : hint_range(0.02, 0.25, 0.005) = 0.08;

group_uniforms optional_textures;
uniform bool use_textures = false;
uniform bool use_normal_texture = false;
uniform bool use_roughness_texture = false;
uniform bool use_ao_texture = false;
uniform sampler2D albedo_texture : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D normal_texture : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D roughness_texture : hint_roughness_r, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D ao_texture : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec3 texture_tint = vec3(1.0);
uniform vec2 texture_tiling = vec2(1.0, 1.0);
uniform vec2 texture_offset = vec2(0.0, 0.0);
uniform float texture_normal_strength : hint_range(0.0, 4.0, 0.05) = 1.0;
uniform float texture_roughness : hint_range(0.0, 1.0, 0.01) = 0.85;

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

vec3 noise_deriv(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * f * (f * (f * 6.0 - 15.0) + 10.0);
	vec2 du = 30.0 * f * f * (f * (f - 2.0) + 1.0);

	float a = hash12(i);
	float b = hash12(i + vec2(1.0, 0.0));
	float c = hash12(i + vec2(0.0, 1.0));
	float d = hash12(i + vec2(1.0, 1.0));

	float k1 = b - a;
	float k2 = c - a;
	float k3 = a - b - c + d;

	float val = a + k1 * u.x + k2 * u.y + k3 * u.x * u.y;
	vec2 grad = du * vec2(k1 + k3 * u.y, k2 + k3 * u.x);
	return vec3(val, grad);
}

void fragment() {
	vec2 road_uv = UV;
	float v = clamp(road_uv.y, 0.0, 1.0);
	// COLOR.g < 0.5: chorraha/aylana yuzasi (dunyo UV, chiziq va chet ranglarisiz)
	if (COLOR.g < 0.5) {
		v = 0.4;
	}

	vec3 grain_coarse = noise_deriv(road_uv * grain_scale);
	vec3 grain_fine = noise_deriv(road_uv * grain_scale * 3.8);
	float macro_var = noise_deriv(road_uv * 0.35).x;

	vec3 base = road_color;
	float rough = clamp(road_roughness + (macro_var - 0.5) * 0.16, 0.2, 1.0);

	// Prosedural qatlam (har doim hisoblanadi, tekstura bo'lsa ustiga yoziladi)
	float track_l = exp(-pow((v - 0.28) * 10.0, 2.0));
	float track_r = exp(-pow((v - 0.72) * 10.0, 2.0));
	float tire_wear = clamp(track_l + track_r, 0.0, 1.0) * tire_wear_strength;
	vec3 proc = mix(road_color, wear_color, tire_wear);
	proc *= mix(0.88, 1.12, grain_coarse.x * 0.6 + grain_fine.x * 0.4);
	proc *= mix(0.92, 1.08, macro_var);
	float shoulder = smoothstep(0.18, 0.0, min(v, 1.0 - v));
	proc = mix(proc, shoulder_color, shoulder * shoulder_amount);

	vec2 tex_uv = road_uv * texture_tiling + texture_offset;

	if (use_textures) {
		base = texture(albedo_texture, tex_uv).rgb * texture_tint;
	} else {
		base = proc;
		vec2 grad = grain_coarse.yz * 0.45 + grain_fine.yz * 0.55;
		NORMAL = normalize(NORMAL + TANGENT * (-grad.x * bump_strength) + BINORMAL * (-grad.y * bump_strength));
	}

	if (use_normal_texture) {
		NORMAL_MAP = texture(normal_texture, tex_uv).xyz;
		NORMAL_MAP_DEPTH = texture_normal_strength;
	}

	if (use_roughness_texture) {
		rough = clamp(texture(roughness_texture, tex_uv).r * (texture_roughness / 0.85), 0.04, 1.0);
	} else if (use_textures) {
		rough = texture_roughness;
	}

	if (use_ao_texture) {
		AO = texture(ao_texture, tex_uv).r;
		AO_LIGHT_AFFECT = 0.6;
	}

	if (show_center_line) {
		float line_v = 1.0 - smoothstep(line_width * 0.75, line_width, abs(v - 0.5));
		float dash = solid_center_line ? 1.0 : smoothstep(1.0 - dash_fill - 0.02, 1.0 - dash_fill + 0.02, fract(road_uv.x / dash_period));
		float wear_break = smoothstep(0.25, 0.75, grain_coarse.x);
		base = mix(base, line_color, line_v * dash * mix(0.65, 0.95, wear_break));
	}

	if (show_edge_lines) {
		float e1 = 1.0 - smoothstep(line_width * 0.75, line_width, abs(v - edge_line_inset));
		float e2 = 1.0 - smoothstep(line_width * 0.75, line_width, abs(v - (1.0 - edge_line_inset)));
		float wear_break2 = smoothstep(0.2, 0.7, grain_fine.x);
		base = mix(base, edge_line_color, clamp(e1 + e2, 0.0, 1.0) * mix(0.6, 0.95, wear_break2));
	}

	ALBEDO = base;
	ROUGHNESS = rough;
	SPECULAR = 0.32;

	// COLOR.r = 0 bo'lsa (ko'prik usti) chet xiralashuvi o'chiriladi
	float edge_alpha = COLOR.a;
	if (edge_blend > 0.001) {
		float d_edge = min(v, 1.0 - v);
		edge_alpha *= mix(smoothstep(0.0, edge_blend, d_edge), 1.0, 1.0 - COLOR.r);
	}
	ALPHA = clamp(edge_alpha, 0.0, 1.0);
}
