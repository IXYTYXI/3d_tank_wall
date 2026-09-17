shader_type spatial;
render_mode unshaded;
varying vec3 world;
varying vec3 mountain_normal;
void vertex() { mountain_normal=NORMAL; world=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz; }
void fragment() {
 float strata=sin(world.x*0.037+sin(world.z*0.042)*2.0+world.y*0.13)*0.5+0.5;
 vec3 rock=mix(vec3(0.12,0.18,0.18),vec3(0.22,0.27,0.26),strata);
 float distance_fade=smoothstep(170.0,440.0,length(world.xz));
 rock*=0.65+0.35*max(dot(normalize(mountain_normal),normalize(vec3(-0.6,0.5,0.7))),0.0);
 ALBEDO=mix(rock,vec3(0.35,0.43,0.45),distance_fade*0.75);
}
