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
	float grain = noise3(p*72.0);
	float scratches = smoothstep(0.86,0.94,noise3(p*vec3(8.0,110.0,40.0))) * step(0.55,grain);
	float chips = smoothstep(0.79,0.88,noise3(p*55.0));
	vec3 color = mix(paint_color.rgb,patch_color.rgb,camo*0.65);
	float grime = noise3(p*8.0+vec3(0,9,0));
	color *= 0.86 + grain*0.16 + noise3(p*0.8)*0.14;
	color = mix(color,vec3(0.12,0.105,0.075),smoothstep(0.60,0.82,grime)*0.28);
	color = mix(color,vec3(0.35,0.32,0.25),chips*0.7);
	ALBEDO = mix(color,vec3(0.48,0.49,0.43),scratches*0.3);
	METALLIC = 0.12 + scratches*0.35;
	ROUGHNESS = clamp(0.47 + grain*0.20 + grime*0.13 - scratches*0.3,0.25,0.85);
}
