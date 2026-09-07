shader_type spatial;
render_mode cull_disabled;
uniform bool water = false;
uniform vec4 ellipse = vec4(0.0,0.0,10.0,10.0);
varying vec3 position_world;
void vertex(){ position_world=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz; }
float hash(vec2 p){ return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453); }
void fragment(){
 vec2 p=position_world.xz;
 float edge=length((p-ellipse.xy)/ellipse.zw);
 if(water){
  float ripple=sin(p.x*2.7+p.y*1.3+TIME*1.6)*sin(p.y*3.8-TIME*1.2);
  float wave=sin(p.x*0.43+p.y*0.8+TIME*0.7);
  ALBEDO=mix(vec3(0.035,0.18,0.20),vec3(0.16,0.40,0.37),smoothstep(0.55,1.0,edge));
  ALBEDO+=vec3(0.05,0.07,0.06)*pow(max(0.0,ripple),6.0);
  ALBEDO=mix(ALBEDO,vec3(0.49,0.61,0.47),smoothstep(0.96,1.0,edge)*0.55);
  ROUGHNESS=0.24; METALLIC=0.25;
  NORMAL_MAP=vec3(0.5+ripple*0.13,0.5+wave*0.12,1.0);
 }else{
  float grain=hash(floor(p*80.0));
  float rake_phase=p.x*17.0+sin(p.y*0.35)*3.0;
  float rake=sin(rake_phase)*(1.0-smoothstep(0.5,2.0,fwidth(rake_phase)));
  ALBEDO=vec3(0.75,0.66,0.47)*(0.94+grain*0.08+rake*0.025);
  ALBEDO*=1.0-smoothstep(0.85,1.0,edge)*0.18;
  ROUGHNESS=1.0;
  NORMAL_MAP=vec3(0.5+rake*0.08,0.5+(grain-0.5)*0.08,1.0);
 }
}
