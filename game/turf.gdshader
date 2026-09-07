shader_type spatial;
render_mode cull_disabled;
uniform bool use_vertex_color = true;
uniform vec4 turf_color : source_color = vec4(0.25,0.42,0.18,1.0);
uniform float hole_length = 400.0;
uniform float hole_bend = 0.0;
uniform bool par_five = false;
uniform int cut_kind = 4;
uniform float route_x[5];
uniform float route_width[5];
varying vec3 world_pos;
float hash(vec2 p) { return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453); }
void vertex() { world_pos=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz; }
void fragment() {
 vec3 base=use_vertex_color ? COLOR.rgb : turf_color.rgb;
 int cut=cut_kind;
 if (use_vertex_color) {
  float at=clamp(-world_pos.z/hole_length,0.0,1.0)*4.0;
  int i=min(3,int(at)); float t=smoothstep(0.0,1.0,at-float(i));
  float center=mix(route_x[i],route_x[i+1],t);
  float width=mix(route_width[i],route_width[i+1],t);
  float edge=abs(world_pos.x-center)-width;
  cut=(world_pos.z < -15.0 && world_pos.z > -hole_length) ? (edge<0.0 ? 1 : (edge<7.0 ? 2 : 3)) : 3;
  base=cut==1 ? vec3(0.30,0.48,0.17) : (cut==2 ? vec3(0.27,0.40,0.15) : vec3(0.16,0.29,0.13));
 }
 float mow=sin((world_pos.z+world_pos.x*0.35)*(cut==1 ? 0.31 : 1.8));
 if(cut==1) base*=1.0+0.09*sign(mow);
 if(cut==0) base*=0.94+0.035*sin(world_pos.x*2.0)*sin(world_pos.z*2.0);
 if(cut==2) base*=0.97+0.035*mow;
 float grain=hash(floor(world_pos.xz*95.0));
 float fleck=hash(floor(world_pos.xz*7.0));
 float fade=1.0-smoothstep(30.0,130.0,distance(CAMERA_POSITION_WORLD,world_pos));
 float texture_strength=cut==3 ? 0.24 : (cut==2 ? 0.12 : (cut==4 ? 0.025 : 0.055));
 ALBEDO=base*(0.97+(fleck-0.5)*texture_strength+(grain-0.5)*texture_strength*fade);
 ROUGHNESS=0.96;
 NORMAL_MAP=vec3(0.5+(grain-0.5)*0.045*fade,0.5+(fleck-0.5)*0.03*fade,1.0);
 NORMAL_MAP_DEPTH=cut==3 ? 1.0 : (cut==2 ? 0.6 : 0.18);
}
