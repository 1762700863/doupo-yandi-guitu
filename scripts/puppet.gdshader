shader_type canvas_item;
// 程序化“木偶”动画：在单张立绘上做局部形变（呼吸 / 迈腿 / 衣摆 / 前倾 / 兽类四足与蛇行）
// 纹理四周已留 PAD 像素透明边，形变不会被裁切
uniform float flash = 0.0;
uniform vec4 flash_col : source_color = vec4(1.0);
uniform vec4 tint : source_color = vec4(1.0);
uniform float dissolve = 0.0;
uniform float pad = 4.0;
uniform float walk = 0.0;      // 步伐相位
uniform float move = 0.0;      // 0 静止 … 1 全速
uniform float lean = 0.0;      // 纹理空间的前倾（像素），正值=向右
uniform float breathe = 0.0;   // 呼吸相位
uniform float sway = 1.0;      // 衣摆/发梢摆动强度
uniform int kind = 0;          // 0 人形 1 四足兽 2 蛇/长尾 3 漂浮（灵体）

float hash(vec2 p) { return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453); }

void fragment() {
	vec2 ps = TEXTURE_PIXEL_SIZE;
	vec2 tsz = 1.0 / ps;
	vec2 px = UV * tsz;                    // 像素坐标
	vec2 inner = tsz - 2.0 * pad;
	float cy = clamp((px.y - pad) / inner.y, 0.0, 1.0);   // 0 头顶 … 1 脚底
	float cx = (px.x - pad) / inner.x - 0.5;              // -0.5 左 … 0.5 右
	float up = 1.0 - cy;
	vec2 d = vec2(0.0);
	float idle = 1.0 - move;
	// 呼吸：上半身轻微上下
	d.y += (sin(breathe) * 0.5 + 0.5) * smoothstep(0.75, 0.0, cy) * 1.1 * idle;
	// 前倾（攻击/奔跑）：越高偏得越多
	d.x += lean * pow(up, 1.3);
	if (kind == 0) {
		// 迈腿：腿部区域左右两腿反向前后摆
		float leg = smoothstep(0.64, 0.98, cy);
		float side = cx < 0.0 ? 1.0 : -1.0;
		d.x += sin(walk) * move * 3.2 * leg * side;
		d.y += max(0.0, sin(walk * (cx < 0.0 ? 1.0 : -1.0))) * move * 1.4 * leg;
		// 衣摆/袖口随风：下半身外侧
		d.x += sin(TIME * 2.3 + cy * 6.0) * 0.7 * sway * smoothstep(0.45, 1.0, cy) * clamp(abs(cx) * 2.4, 0.0, 1.0);
		// 发梢：顶部外缘
		d.x += sin(TIME * 1.7 + cy * 9.0) * 0.5 * sway * smoothstep(0.3, 0.0, cy) * clamp(abs(cx) * 2.0, 0.0, 1.0);
	} else if (kind == 1) {
		// 四足：前后腿交替，身体起伏
		float leg = smoothstep(0.55, 0.95, cy);
		float fr = cx > 0.0 ? 1.0 : -1.0;
		d.x += sin(walk + (cx > 0.15 ? 0.0 : 3.14159) + (abs(cx) < 0.15 ? 1.57 : 0.0)) * move * 3.0 * leg;
		d.y += sin(walk * 2.0 + cx * 5.0) * move * 0.9 * up;
		d.y += (sin(breathe) * 0.5 + 0.5) * 0.9 * up * idle;
		// 尾巴（左侧外缘）摆动
		d.y += sin(TIME * 4.0) * 1.2 * smoothstep(-0.3, -0.5, cx);
	} else if (kind == 2) {
		// 蛇行：自下而上的波
		d.x += sin(TIME * 3.5 - cy * 7.0 + walk) * (0.8 + move * 1.6) * smoothstep(0.35, 1.0, cy);
		d.x += sin(TIME * 1.6 + cy * 8.0) * 0.5 * sway * smoothstep(0.35, 0.0, cy) * clamp(abs(cx) * 2.0, 0.0, 1.0);
	} else {
		// 漂浮：整体缓慢波动，下摆飘散
		d.x += sin(TIME * 2.0 + cy * 5.0) * 1.2 * smoothstep(0.3, 1.0, cy);
		d.y += sin(TIME * 1.5) * 0.8;
	}
	vec2 suv = (px - d) * ps;
	vec4 c = texture(TEXTURE, suv);
	if (suv.x < 0.0 || suv.y < 0.0 || suv.x > 1.0 || suv.y > 1.0) { c.a = 0.0; }
	c *= tint;
	c.rgb = mix(c.rgb, flash_col.rgb, clamp(flash, 0.0, 1.0));
	if (dissolve > 0.0) {
		float n = hash(floor(suv / ps / 2.0));
		if (n < dissolve) { c.a = 0.0; }
		else if (n < dissolve + 0.08) { c.rgb = vec3(1.0, 0.6, 0.2); }
	}
	COLOR = c * COLOR;
}
