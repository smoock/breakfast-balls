shader_type spatial;
render_mode cull_disabled;
uniform bool water = false;
uniform vec4 ellipse = vec4(0.0,0.0,10.0,10.0);
uniform int pond_count = 0;
uniform vec4 pond_ellipses[24];
varying vec3 position_world;
varying vec3 normal_world;
void vertex(){
 position_world=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
 normal_world=normalize((MODEL_MATRIX*vec4(NORMAL,0.0)).xyz);
}
float hash(vec2 p){ return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453); }
float noise(vec2 p){
 vec2 i=floor(p),f=fract(p); f=f*f*(3.0-2.0*f);
 return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1)),f.x),f.y);
}
void fragment(){
 vec2 p=position_world.xz;
 float edge=length((p-ellipse.xy)/ellipse.zw);
 if(water){
  bool wet=false;
  float union_edge=10.0;
  for(int h=0;h<24;h++) {
   if(h>=pond_count) break;
   float pond_edge=length((p-pond_ellipses[h].xy)/pond_ellipses[h].zw);
   if(pond_edge<1.0) { wet=true; union_edge=min(union_edge,pond_edge); }
  }
  if(pond_count>0 && !wet) discard;
  if(pond_count>0) edge=union_edge;
  float wave_a=sin(dot(p,vec2(1.8,1.15))+TIME*1.35);
  float wave_b=sin(dot(p,vec2(-1.2,2.65))-TIME*0.92);
  float ripple=wave_a*0.55+wave_b*0.45;
  float shallow=smoothstep(0.50,0.98,edge);
  vec3 view_dir=normalize(CAMERA_POSITION_WORLD-position_world);
  float fresnel=pow(1.0-clamp(dot(normalize(normal_world),view_dir),0.0,1.0),3.0);
  vec3 deep=vec3(0.025,0.145,0.18);
  vec3 bank=vec3(0.12,0.34,0.29);
  ALBEDO=mix(deep,bank,shallow);
  ALBEDO=mix(ALBEDO,vec3(0.42,0.61,0.59),fresnel*0.62);
  float shore=smoothstep(0.91,0.955,edge)*(1.0-smoothstep(0.955,1.0,edge));
  ALBEDO+=vec3(0.34,0.40,0.28)*shore*(0.42+0.25*wave_a);
  ROUGHNESS=mix(0.28,0.40,shallow); METALLIC=0.04;
  NORMAL_MAP=vec3(0.5+wave_a*0.025,0.5+wave_b*0.022,1.0);
  NORMAL_MAP_DEPTH=0.24;
 }else{
  float fine=hash(floor(p*92.0));
  float coarse=noise(p*3.8);
  float rake_phase=p.x*14.0+sin(p.y*0.31)*2.6;
  float rake=sin(rake_phase);
  float lip=smoothstep(0.72,1.0,edge);
  vec3 sand=mix(vec3(0.69,0.56,0.34),vec3(0.88,0.77,0.53),coarse);
  ALBEDO=sand*(0.94+(fine-0.5)*0.11+rake*0.026);
  ALBEDO*=1.0-lip*0.20;
  ROUGHNESS=1.0;
  NORMAL_MAP=normalize(vec3(0.5+rake*0.075,0.5+(fine-0.5)*0.105,1.0));
  NORMAL_MAP_DEPTH=0.82;
 }
}
