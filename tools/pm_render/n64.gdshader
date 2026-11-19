shader_type spatial;
// Paper Mario 64 look: unshaded, texture x vertex colour, alpha cut-outs.
render_mode unshaded, cull_disabled, depth_draw_opaque;
uniform sampler2D tex : source_color, filter_linear_mipmap, repeat_enable;
uniform bool clamp_uv = false;
uniform bool has_tex = true;
uniform bool use_vc = true;
uniform vec4 tint : source_color = vec4(1.0);
uniform vec2 uv_scale = vec2(1.0);
uniform vec2 uv_offset = vec2(0.0);
uniform float zmin = -1e9;
uniform float zmax = 1e9;
uniform float shown = 1.0;
varying vec3 wpos;
void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}
void fragment() {
	if (shown < 0.5 || wpos.z < zmin || wpos.z > zmax) {
		discard;
	}
	vec2 uv = UV * uv_scale + uv_offset;
	vec4 t = vec4(1.0);
	if (has_tex) {
		if (clamp_uv) {
			// keep cut-outs from bleeding their opposite edge (no wrap)
			vec2 half_texel = 0.5 / vec2(textureSize(tex, 0));
			uv = clamp(uv, half_texel, 1.0 - half_texel);
		}
		t = texture(tex, uv);
	}
	vec3 c = t.rgb * tint.rgb;
	if (use_vc) {
		c *= COLOR.rgb;
	}
	ALBEDO = c;
	ALPHA = t.a * tint.a;
	ALPHA_SCISSOR_THRESHOLD = 0.5;
}
