shader_type canvas_item;
// 地面：按低频噪声平滑混合 4 种地块变体 + 大尺度明暗/色调变化，避免 64px 方格感
uniform sampler2D tiles : filter_nearest, repeat_disable;
uniform vec2 origin = vec2(0.0);      // 该节点左上角的世界坐标
uniform float organic = 1.0;          // 1=草地/沙地等自然地面（错位采样）；0=石板（保持网格）
uniform float seed = 0.0;
uniform vec4 tint_a : source_color = vec4(1.0);
uniform vec4 tint_b : source_color = vec4(1.0);
// 道路：低分辨率遮罩（线性采样）+ 噪声扰动边缘
uniform sampler2D roads : filter_linear, repeat_disable;
uniform sampler2D road_tex : filter_nearest, repeat_enable;
uniform float has_roads = 0.0;
uniform vec2 mask_origin = vec2(0.0);
uniform vec2 mask_size = vec2(1.0);
varying vec2 wpos;

void vertex() { wpos = VERTEX + origin; }

float hash(vec2 p) { p = fract(p * vec2(123.34, 456.21) + seed); p += dot(p, p + 45.32); return fract(p.x * p.y); }
float vnoise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), u.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), u.x), u.y);
}
float fbm(vec2 p) { float v = 0.0; float a = 0.5; for (int k = 0; k < 4; k++) { v += a * vnoise(p); p *= 2.03; a *= 0.5; } return v; }

vec4 tile(int k, vec2 p) {
	vec2 q = p;
	if (organic > 0.5) { q += vec2(float(k) * 97.0, float(k) * 61.0); if (k == 2) q = vec2(q.y, -q.x); if (k == 3) q = -q; }
	vec2 local = mod(floor(q), 256.0);
	vec2 ts = vec2(textureSize(tiles, 0));
	return texture(tiles, (vec2(float(k) * 256.0, 0.0) + local + 0.5) / ts);
}

void fragment() {
	vec2 p = floor(wpos);   // 像素对齐
	float n1 = fbm(p / 260.0);
	float n2 = fbm(p / 170.0 + 11.7);
	float n3 = fbm(p / 120.0 + 5.3);
	// 变体权重：主地块为 0；其余按噪声斑块出现，边缘柔和
	float w1 = smoothstep(0.52, 0.64, n1);
	float w2 = smoothstep(0.55, 0.68, n2) * (1.0 - w1 * 0.6);
	float w3 = smoothstep(0.60, 0.72, n3) * 0.8;
	vec4 c = tile(0, p);
	c = mix(c, tile(1, p), w1);
	c = mix(c, tile(2, p), w2);
	c = mix(c, tile(3, p), w3);
	// 大尺度明暗与色调
	float big = fbm(p / 520.0 + 3.1);
	float light = 0.9 + big * 0.2;
	vec3 tint = mix(tint_a.rgb, tint_b.rgb, smoothstep(0.35, 0.7, fbm(p / 700.0 + 8.0)));
	c.rgb *= light * tint;
	if (has_roads > 0.5) {
		float m = texture(roads, (wpos - mask_origin) / mask_size).r;
		float e = m + (fbm(p / 18.0 + 2.0) - 0.5) * 0.32 + (hash(floor(p / 2.0)) - 0.5) * 0.06;
		float road = step(0.5, e);
		float rim = smoothstep(0.22, 0.5, e) * (1.0 - road);
		vec2 rs = vec2(textureSize(road_tex, 0));
		vec4 rc = texture(road_tex, (mod(p, rs) + 0.5) / rs);
		rc.rgb *= 0.92 + big * 0.14;
		c.rgb = mix(c.rgb * (1.0 - rim * 0.22), rc.rgb, road);
		// 路边一圈稍亮的踩踏边
		c.rgb *= 1.0 + step(0.5, e + 0.035) * (1.0 - road) * 0.10;
	}
	// 细小颗粒
	c.rgb *= 0.97 + hash(floor(p / 2.0)) * 0.05;
	COLOR = vec4(c.rgb, 1.0);
}
