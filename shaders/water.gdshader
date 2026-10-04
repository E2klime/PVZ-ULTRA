shader_type canvas_item;
// Pool water for Board water cells. UVs come from world position so neighbouring
// cells tile seamlessly whatever the water mask looks like.
uniform sampler2D water_tex : repeat_enable, filter_linear_mipmap;
uniform sampler2D caustics_tex : repeat_enable, filter_linear_mipmap;
uniform float tile_px = 512.0;
uniform float caustic_strength = 0.55;

varying vec2 world;

void vertex() {
	world = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

void fragment() {
	vec2 uv = world / tile_px;
	float t = TIME;
	vec2 wob = vec2(sin(uv.y * 9.0 + t * 1.3), cos(uv.x * 8.0 + t * 1.1)) * 0.006;
	vec3 base = texture(water_tex, uv * 1.0 + vec2(t * 0.012, t * 0.006) + wob).rgb;
	float c1 = texture(caustics_tex, uv * 1.15 + vec2(t * 0.025, -t * 0.012) + wob * 2.0).a;
	float c2 = texture(caustics_tex, uv * 0.9 + vec2(-t * 0.018, t * 0.02) - wob * 2.0).a;
	float c = min(c1, c2) * 1.6 + max(c1, c2) * 0.15;
	vec3 col = base + vec3(0.75, 0.95, 1.0) * c * caustic_strength;
	// gentle sparkle
	float sp = pow(max(0.0, sin(uv.x * 61.0 + t * 2.3) * sin(uv.y * 53.0 - t * 1.7)), 24.0);
	col += vec3(sp) * 0.35;
	COLOR = vec4(col, 1.0) * COLOR;
}
