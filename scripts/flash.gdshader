shader_type canvas_item;
uniform float flash = 0.0;
uniform vec4 flash_col : source_color = vec4(1.0);
uniform vec4 tint : source_color = vec4(1.0);
uniform float dissolve = 0.0;

float hash(vec2 p) { return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453); }

void fragment() {
	vec4 c = texture(TEXTURE, UV) * tint;
	c.rgb = mix(c.rgb, flash_col.rgb, clamp(flash, 0.0, 1.0));
	if (dissolve > 0.0) {
		float n = hash(floor(UV / TEXTURE_PIXEL_SIZE / 2.0));
		if (n < dissolve) { c.a = 0.0; }
		else if (n < dissolve + 0.08) { c.rgb = vec3(1.0, 0.6, 0.2); }
	}
	COLOR = c * COLOR;
}
