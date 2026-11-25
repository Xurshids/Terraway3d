shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

group_uniforms water_color;
uniform vec3 shallow_color : source_color = vec3(0.08, 0.36, 0.35);
uniform vec3 deep_color : source_color = vec3(0.02, 0.11, 0.17);
uniform vec3 sky_tint : source_color = vec3(0.55, 0.74, 0.88);
uniform vec3 absorption_rgb = vec3(0.50, 0.16, 0.10);
uniform float clarity : hint_range(0.1, 8.0, 0.05) = 1.75;
uniform float min_opacity : hint_range(0.1, 1.0, 0.02) = 0.62;
uniform float edge_fade_depth : hint_range(0.01, 0.6, 0.01) = 0.06;

group_uniforms flow_and_ripples;
uniform float flow_speed : hint_range(0.0, 4.0, 0.02) = 0.48;
uniform float ripple_scale : hint_range(0.2, 8.0, 0.05) = 1.85;
uniform float ripple_strength : hint_range(0.0, 1.5, 0.02) = 0.42;

group_uniforms optics;
uniform float refraction_strength : hint_range(0.0, 0.08, 0.002) = 0.025;
uniform float fresnel_power : hint_range(1.0, 8.0, 0.1) = 4.5;
uniform float water_roughness : hint_range(0.01, 0.35, 0.005) = 0.035;
uniform float water_specular : hint_range(0.0, 1.0, 0.05) = 0.85;
uniform float caustics_strength : hint_range(0.0, 1.0, 0.02) = 0.32;

group_uniforms water_textures;
uniform bool use_normal_textures = false;
uniform sampler2D water_normal_a : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D water_normal_b : hint_normal, filter_linear_mipmap, repeat_enable;
uniform vec2 normal_tiling = vec2(1.0, 1.0);
uniform float normal_texture_strength : hint_range(0.0, 2.0, 0.01) = 0.6;
uniform bool use_foam_texture = false;
uniform sampler2D foam_texture : filter_linear_mipmap, repeat_enable;
uniform float foam_texture_scale : hint_range(0.1, 10.0, 0.1) = 1.0;

group_uniforms shore_foam;
uniform vec3 foam_color : source_color = vec3(0.88, 0.93, 0.95);
uniform float foam_depth : hint_range(0.0, 0.5, 0.01) = 0.10;
uniform float foam_intensity : hint_range(0.0, 1.0, 0.02) = 0.30;

// Mobile va Android uchun depth_texture da filter_nearest majburiy!
uniform sampler2D depth_texture : hint_depth_texture, repeat_disable, filter_nearest;
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear;

varying vec3 v_world_pos;
varying vec2 v_flow_uv;
varying float v_edge_mask;

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

// Katta to'lqin yo'q — faqat tabiiy daryo oqimidagi mayin burmalar va mikro-jimir
vec3 river_ripples(vec2 uv, float speed_mul) {
	float t = TIME * flow_speed * speed_mul;

	// Sekin tabiiy oqim egriligi (domain warp)
	vec2 warp_n = vec2(
		noise_deriv(uv * 0.45 - vec2(t * 0.25, 0.0)).x,
		noise_deriv(uv * 0.45 + vec2(3.7, -t * 0.20)).x
	) - 0.5;
	vec2 wuv = uv + warp_n * 0.35;

	vec2 p1 = wuv * vec2(0.95, 1.55) * ripple_scale - vec2(t * 0.85, t * 0.14);
	vec3 n1 = noise_deriv(p1);

	vec2 p2 = wuv * vec2(2.15, 2.55) * ripple_scale - vec2(t * 1.30, -t * 0.20);
	vec3 n2 = noise_deriv(p2);

	vec2 p3 = wuv * vec2(5.2, 5.6) * ripple_scale - vec2(t * 1.85, t * 0.10);
	vec3 n3 = noise_deriv(p3);

	float h = n1.x * 0.48 + n2.x * 0.34 + n3.x * 0.18;
	vec2 grad = n1.yz * 0.48 + n2.yz * 0.46 + n3.yz * 0.38;
	return vec3(h, grad);
}

vec3 reconstruct_view_pos(vec2 suv, float raw_depth, mat4 inv_proj) {
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
	float ndc_z = raw_depth * 2.0 - 1.0;
#else
	float ndc_z = raw_depth;
#endif
	vec4 clip = inv_proj * vec4(suv * 2.0 - 1.0, ndc_z, 1.0);
	return clip.xyz / clip.w;
}

void vertex() {
	v_flow_uv = UV;
	v_edge_mask = COLOR.a;
	v_world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float center_speed = mix(0.60, 1.12, smoothstep(0.0, 0.5, 0.5 - abs(v_flow_uv.y - 0.5)));
	vec3 ripple = river_ripples(v_flow_uv, center_speed);

	vec3 base_normal = normalize(NORMAL);
	vec3 tangent_v = normalize(TANGENT);
	vec3 binormal_v = normalize(BINORMAL);

	vec2 tex_grad = vec2(0.0);
	if (use_normal_textures) {
		float tt = TIME * flow_speed;
		vec2 uv_a = v_flow_uv * normal_tiling + vec2(-tt * 0.18, tt * 0.03);
		vec2 uv_b = v_flow_uv * normal_tiling * 1.7 + vec2(-tt * 0.27, -tt * 0.05) + vec2(0.37, 0.11);
		vec3 na = texture(water_normal_a, uv_a).xyz * 2.0 - 1.0;
		vec3 nb = texture(water_normal_b, uv_b).xyz * 2.0 - 1.0;
		tex_grad = (na.xy + nb.xy) * 0.5;
	}

	vec3 perturbed_normal = normalize(
		base_normal
		+ tangent_v * (-(ripple.y * ripple_strength + tex_grad.x * normal_texture_strength))
		+ binormal_v * (-(ripple.z * ripple_strength + tex_grad.y * normal_texture_strength))
	);
	NORMAL = perturbed_normal;

	vec3 n_delta = perturbed_normal - base_normal;
	vec2 refract_uv = clamp(
		SCREEN_UV + vec2(n_delta.x, -n_delta.y) * refraction_strength,
		vec2(0.002),
		vec2(0.998)
	);

	float raw_depth = texture(depth_texture, SCREEN_UV).r;
	vec3 bg_view = reconstruct_view_pos(SCREEN_UV, raw_depth, INV_PROJECTION_MATRIX);

	float raw_ref_depth = texture(depth_texture, refract_uv).r;
	vec3 ref_view = reconstruct_view_pos(refract_uv, raw_ref_depth, INV_PROJECTION_MATRIX);

	bool valid_refract = ref_view.z < VERTEX.z - 0.015;
	vec2 final_uv = valid_refract ? refract_uv : SCREEN_UV;
	vec3 final_view = valid_refract ? ref_view : bg_view;

	float ray_depth = max(0.0, VERTEX.z - final_view.z);
	vec3 bed_world = (INV_VIEW_MATRIX * vec4(final_view, 1.0)).xyz;
	float vertical_depth = max(0.0, v_world_pos.y - bed_world.y);

	float optical_depth = mix(vertical_depth, ray_depth, 0.35) / clarity;
	vec3 transmittance = exp(-absorption_rgb * optical_depth * 2.2);
	vec3 water_tint = mix(deep_color, shallow_color, clamp(exp(-optical_depth * 1.1), 0.0, 1.0));

	vec3 under_color = texture(screen_texture, final_uv).rgb;

	if (caustics_strength > 0.001 && vertical_depth > 0.02 && vertical_depth < 2.8) {
		vec2 c_uv = bed_world.xz * 0.90 - vec2(TIME * flow_speed * 0.35, TIME * flow_speed * 0.12);
		float c1 = noise_deriv(c_uv * 2.3).x;
		float c2 = noise_deriv(c_uv * 3.2 + vec2(4.2, -2.7)).x;
		float caustic = pow(clamp(1.0 - abs(c1 - c2) * 3.2, 0.0, 1.0), 3.0);
		float caustic_fade = exp(-vertical_depth * 1.25) * smoothstep(0.0, 0.14, vertical_depth);
		under_color += vec3(0.76, 0.92, 0.96) * caustic * caustics_strength * caustic_fade;
	}

	vec3 refracted_water = mix(
		water_tint,
		under_color * transmittance + water_tint * (1.0 - transmittance) * 0.35,
		clamp(transmittance.b, 0.0, 1.0)
	);

	// Schlick Fresnel (F0 = 0.02, IOR = 1.333) + osmon aks ettirishi
	float ndotv = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float fresnel = 0.02 + 0.98 * pow(1.0 - ndotv, fresnel_power);
	vec3 water_col = mix(refracted_water, sky_tint, clamp(fresnel * 0.55, 0.0, 0.65));

	// Qirg'oq ko'pigi faqat juda sayoz suv chetida
	float shore_factor = 1.0 - smoothstep(0.0, max(foam_depth, 0.001), vertical_depth);
	float foam_noise = noise_deriv(v_flow_uv * vec2(5.5, 8.0) - vec2(TIME * flow_speed * 1.1, 0.0)).x;
	if (use_foam_texture) {
		foam_noise = texture(foam_texture, v_flow_uv * vec2(1.0, 1.5) * foam_texture_scale - vec2(TIME * flow_speed * 0.5, 0.0)).r;
	}
	float foam_mask = smoothstep(0.48, 0.74, foam_noise + shore_factor * 0.32) * shore_factor * foam_intensity * smoothstep(0.0, 0.02, vertical_depth);

	ALBEDO = mix(water_col, foam_color, clamp(foam_mask, 0.0, 1.0));
	ROUGHNESS = mix(water_roughness, 0.55, foam_mask);
	METALLIC = 0.0;
	SPECULAR = mix(water_specular, 0.1, foam_mask) * mix(0.65, 1.0, fresnel);

	float depth_alpha = smoothstep(0.0, edge_fade_depth, max(ray_depth, vertical_depth));
	float base_alpha = max(depth_alpha, min_opacity);
	ALPHA = clamp(max(base_alpha, foam_mask) * v_edge_mask, 0.0, 1.0);
}