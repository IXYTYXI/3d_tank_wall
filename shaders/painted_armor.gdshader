shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;
uniform vec4 paint_color : source_color = vec4(0.29, 0.33, 0.23, 1.0);
uniform vec4 patch_color : source_color = vec4(0.12, 0.16, 0.13, 1.0);
uniform float camouflage = 1.0;
varying vec3 part_position;
float hash(vec3 p) { return fract(sin(dot(p, vec3(127.1,311.7,74.7))) * 43758.5453); }
float noise3(vec3 p) {
	vec3 i = floor(p); vec3 f = fract(p); f = f*f*(3.0-2.0*f);
	return mix(mix(mix(hash(i),hash(i+vec3(1,0,0)),f.x), mix(hash(i+vec3(0,1,0)),hash(i+vec3(1,1,0)),f.x),f.y),
		mix(mix(hash(i+vec3(0,0,1)),hash(i+vec3(1,0,1)),f.x),mix(hash(i+vec3(0,1,1)),hash(i+vec3(1,1,1)),f.x),f.y),f.z);
}
void vertex() { part_position = VERTEX; }
void fragment() {
	vec3 p = part_position;
	float blotch = noise3(p*2.2 + vec3(3.4,1.0,0.0)) + noise3(p*5.0)*0.22;
	float camo = smoothstep(0.49,0.57,blotch) * camouflage;
	float grain = noise3(p*145.0);
	float scratches = step(0.80,noise3(p*vec3(14.0,290.0,90.0))) * step(0.55,grain);
	float chips = smoothstep(0.79,0.88,noise3(p*55.0));
	vec3 color = mix(paint_color.rgb,patch_color.rgb,camo*0.65);
	color *= 0.94 + grain*0.12;
	color = mix(color,vec3(0.35,0.32,0.25),chips*0.7);
	ALBEDO = mix(color,vec3(0.48,0.49,0.43),scratches*0.55);
	METALLIC = 0.18 + scratches*0.55;
	ROUGHNESS = clamp(0.58 + grain*0.15 - scratches*0.3,0.25,0.85);
}
