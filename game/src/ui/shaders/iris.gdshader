shader_type canvas_item;
// Storybook iris wipe: progress 0 = fully open, 1 = fully closed.

uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform vec2 center = vec2(0.5, 0.5);
uniform int shape = 0; // 0 circle, 1 star
uniform vec4 ink : source_color = vec4(0.13, 0.08, 0.05, 1.0);
uniform vec4 rim : source_color = vec4(0.98, 0.93, 0.78, 1.0);

void fragment() {
	vec2 res = 1.0 / SCREEN_PIXEL_SIZE;
	float aspect = res.x / res.y;
	vec2 p = UV - center;
	p.x *= aspect;
	float r = length(p);
	if (shape == 1) {
		float a = atan(p.y, p.x) + 1.5708;
		float star = 0.72 + 0.28 * cos(5.0 * a);
		r = r / star;
	}
	float radius = (1.0 - progress) * 1.35;
	float edge = 1.5 / res.y;
	float outside = smoothstep(radius - edge, radius + edge, r);
	// thin cream rim around the opening, like a cut paper edge
	float rim_band = smoothstep(radius - 0.012 - edge, radius - 0.012, r) * (1.0 - outside);
	vec4 col = mix(vec4(rim.rgb, rim_band), ink, outside);
	if (progress <= 0.0001) {
		col.a = 0.0;
	}
	COLOR = col;
}
