shader_type canvas_item;
// Shared material for procedurally drawn plants and zombies (GDD 7.5).
//  flash   - white hit flash
//  tint    - status tint (frost slow)
//  frozen  - icy recolour + moving glints (Rime Lettuce freeze)
//  burn    - charred, flickering orange underlight
//  shimmer - gold light sweep for legendary plants
uniform float flash : hint_range(0.0, 1.0) = 0.0;
uniform vec4 tint : source_color = vec4(1.0);
uniform float frozen : hint_range(0.0, 1.0) = 0.0;
uniform float burn : hint_range(0.0, 1.0) = 0.0;
uniform float shimmer : hint_range(0.0, 1.0) = 0.0;
uniform float seed = 0.0;

varying vec2 local_pos;

void vertex() {
	local_pos = VERTEX;
}

void fragment() {
	vec4 c = COLOR;
	c.rgb *= tint.rgb;
	float luma = dot(c.rgb, vec3(0.299, 0.587, 0.114));
	if (frozen > 0.0) {
		vec3 ice = vec3(0.55, 0.82, 1.0) * (0.45 + 0.75 * luma);
		float glint = smoothstep(0.92, 1.0, sin((local_pos.x - local_pos.y) * 0.08 + TIME * 2.5 + seed));
		c.rgb = mix(c.rgb, ice + glint * 0.5, frozen * 0.75);
	}
	if (burn > 0.0) {
		float flick = 0.6 + 0.4 * sin(TIME * 21.0 + local_pos.y * 0.09 + seed);
		vec3 ember = vec3(1.0, 0.42, 0.08) * (0.35 + luma);
		c.rgb = mix(c.rgb * (1.0 - 0.35 * burn), ember, burn * 0.3 * flick);
	}
	if (shimmer > 0.0) {
		float band = fract((local_pos.x + local_pos.y * 0.6) * 0.0045 - TIME * 0.32 + seed);
		float sweep = smoothstep(0.0, 0.06, band) * (1.0 - smoothstep(0.06, 0.14, band));
		c.rgb += vec3(1.0, 0.86, 0.42) * sweep * 0.55 * shimmer;
	}
	c.rgb = mix(c.rgb, vec3(1.0), flash);
	COLOR = c;
}
