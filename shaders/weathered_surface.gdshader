shader_type spatial;
render_mode diffuse_burley;
uniform vec4 base_color : source_color = vec4(0.42,0.43,0.38,1.0);
uniform float metal = 0.0;
uniform bool hazard = false;
varying vec3 local_pos;
varying vec3 local_normal;
varying vec3 world_pos;
float hash(vec3 p) { return fract(sin(dot(p,vec3(127.1,311.7,74.7)))*43758.5453); }
float noise(vec3 p) {
 vec3 i=floor(p),f=fract(p); f=f*f*(3.0-2.0*f);
 return mix(mix(mix(hash(i),hash(i+vec3(1,0,0)),f.x),mix(hash(i+vec3(0,1,0)),hash(i+vec3(1,1,0)),f.x),f.y),mix(mix(hash(i+vec3(0,0,1)),hash(i+vec3(1,0,1)),f.x),mix(hash(i+vec3(0,1,1)),hash(i+vec3(1,1,1)),f.x),f.y),f.z);
}
void vertex(){local_pos=VERTEX;local_normal=NORMAL;world_pos=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;}
void fragment(){
 float grain=noise(world_pos*75.0);
 float stain=noise(world_pos*1.7);
 float pits=smoothstep(0.68,0.82,noise(world_pos*42.0));
 vec3 color=base_color.rgb*(0.77+stain*0.35+grain*0.12);
 if(hazard && abs(local_normal.z)>0.7 && local_pos.y>0.45 && local_pos.y<1.05){
  float stripe=step(0.5,fract((local_pos.x+local_pos.y*0.85)*1.25));
  vec3 paint=mix(vec3(0.09,0.10,0.085),vec3(0.7,0.49,0.15),stripe);
  color=mix(color,paint,1.0-smoothstep(0.55,0.72,noise(local_pos*17.0)));
 }
 ALBEDO=color*(1.0-pits*0.13);
 ROUGHNESS=0.82+grain*0.15;
 METALLIC=metal;
}
