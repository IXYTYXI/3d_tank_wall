shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;
varying vec3 surface_position;
float h(vec2 p) { return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453); }
float n(vec2 p) {
 vec2 i=floor(p), f=fract(p); f=f*f*(3.0-2.0*f);
 return mix(mix(h(i),h(i+vec2(1,0)),f.x),mix(h(i+vec2(0,1)),h(i+vec2(1,1)),f.x),f.y);
}
float relief(vec2 p) { return n(p*16.0)*0.018+n(p*4.0)*0.05; }
void vertex() { surface_position=VERTEX; }
void fragment() {
 vec2 p=surface_position.xz;
 float grit=n(p*8.0), earth=n(p*0.45)*0.6+n(p*3.0)*0.4;
 float center=4.0*sin(p.y*0.04);
 float road=1.0-smoothstep(3.0,7.0,abs(p.x-center)+n(p*0.8)*1.3);
 float ruts=(1.0-smoothstep(0.30,0.64,abs(abs(p.x-center)-1.48)))*road;
 float tread=smoothstep(0.3,0.65,sin(p.y*19.0+sin(p.x*9.0)*0.7)*0.5+0.5)*ruts;
 float wet=smoothstep(0.56,0.73,n(p*0.6))*road;
 vec3 grass=mix(vec3(0.095,0.115,0.060),vec3(0.22,0.23,0.13),earth);
 vec3 dirt=mix(vec3(0.135,0.115,0.080),vec3(0.31,0.275,0.205),earth);
 vec3 color=mix(grass,dirt,road);
 color*=1.0-ruts*0.20-tread*0.16;
 color=mix(color,vec3(0.37,0.36,0.30),smoothstep(0.77,0.90,grit)*0.22);
 ALBEDO=color*(0.94+grit*0.12)*(1.0-wet*0.22);
 ROUGHNESS=mix(0.96,0.32,wet);
 SPECULAR=0.35;
 float e=0.035;
 vec3 gradient=vec3(relief(p+vec2(e,0))-relief(p-vec2(e,0)),0,relief(p+vec2(0,e))-relief(p-vec2(0,e)))/(2.0*e);
 NORMAL=normalize(NORMAL-mat3(VIEW_MATRIX)*gradient*0.55);
}
