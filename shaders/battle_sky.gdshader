shader_type sky;
float hash21(vec2 p) { return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453); }
float noise21(vec2 p) {
 vec2 i=floor(p), f=fract(p); f=f*f*(3.0-2.0*f);
 return mix(mix(hash21(i),hash21(i+vec2(1,0)),f.x),mix(hash21(i+vec2(0,1)),hash21(i+vec2(1,1)),f.x),f.y);
}
float cloud(vec2 p) {
 return noise21(p)*0.55+noise21(p*2.1)*0.26+noise21(p*4.3)*0.13+noise21(p*8.5)*0.06;
}
void sky() {
 float altitude=max(EYEDIR.y,0.0);
 vec2 p=EYEDIR.xz/(0.24+altitude)*2.6;
 float clouds=cloud(p);
 float breakup=smoothstep(0.30,0.72,clouds);
 vec3 clear=mix(vec3(0.39,0.47,0.49),vec3(0.095,0.15,0.205),pow(altitude,0.45));
 vec3 overcast=mix(vec3(0.105,0.14,0.17),vec3(0.40,0.43,0.42),breakup);
 float light=pow(max(dot(EYEDIR,normalize(vec3(-0.6,0.3,0.7))),0.0),12.0);
 overcast+=vec3(0.23,0.20,0.13)*light*smoothstep(0.45,0.65,clouds);
 COLOR=mix(clear,overcast,smoothstep(0.02,0.3,altitude)*0.88);
}
