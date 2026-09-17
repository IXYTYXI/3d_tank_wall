shader_type spatial;
render_mode diffuse_burley;
varying vec3 surface_position;
float h(vec2 p) { return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453); }
float n(vec2 p) {
	vec2 i=floor(p); vec2 f=fract(p); f=f*f*(3.0-2.0*f);
	return mix(mix(h(i),h(i+vec2(1,0)),f.x),mix(h(i+vec2(0,1)),h(i+vec2(1,1)),f.x),f.y);
}
void vertex() { surface_position=VERTEX; }
void fragment() {
	vec2 p=surface_position.xz;
	float grain=n(p*18.0);
	float earth=n(p*0.45)*0.6+n(p*3.0)*0.4;
	float gravel=smoothstep(0.68,0.80,grain);
	vec3 dirt=mix(vec3(0.13,0.15,0.10),vec3(0.27,0.25,0.17),earth);
	ALBEDO=mix(dirt,vec3(0.30,0.30,0.24),gravel*0.30)*(0.9+grain*0.2);
	ROUGHNESS=0.94;
}
