shader_type spatial;
uniform vec4 tee_area = vec4(0,0,8,5);

uniform float hole_length=400.0;
uniform float route_x[5];
uniform float route_width[5];
uniform vec4 green;
uniform int bunker_count=0;
uniform vec4 bunker_ellipses[8];
uniform int pond_count=0;
uniform vec4 pond_ellipses[24];
uniform int creek_count=0;
uniform vec2 creek_path[24];
varying vec3 world_pos;

float hash(vec2 p) { return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453); }
float noise(vec2 p) {
 vec2 i=floor(p),f=fract(p); f=f*f*(3.0-2.0*f);
 return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1)),f.x),f.y);
}
float ellipse_distance(vec2 p,vec4 e) { return (length((p-e.xy)/e.zw)-1.0)*min(e.z,e.w); }
void vertex() { world_pos=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz; }
void fragment() {
 vec2 p=world_pos.xz;
 float at=clamp(-p.y/hole_length,0.0,1.0)*4.0;
 int i=min(3,int(at)); float t=smoothstep(0.0,1.0,at-float(i));
 float route=mix(route_x[i],route_x[i+1],t);
 float width=mix(route_width[i],route_width[i+1],t);
 float fair_edge=abs(p.x-route)-width;
 float route_end=(1.0-smoothstep(-20.0,-15.0,p.y))*smoothstep(-hole_length-2.0,-hole_length+2.0,p.y);
 float fair=(1.0-smoothstep(-0.22,0.22,fair_edge))*route_end;
 float first=(1.0-smoothstep(6.5,7.5,fair_edge))*route_end;
 float mowing=sin((p.y+p.x*0.28)*0.29);
 vec3 rough=vec3(0.145,0.265,0.085);
 vec3 fair_color=vec3(0.28,0.425,0.135)*(1.0+0.055*tanh(mowing*4.0));
 vec3 grass=mix(rough,vec3(0.205,0.33,0.10),first);
 grass=mix(grass,fair_color,fair);
 float gd=ellipse_distance(p,green);
 grass=mix(grass,vec3(0.29,0.40,0.145),1.0-smoothstep(1.3,2.2,gd));
 float putting=1.0-smoothstep(-0.10,0.10,gd);
 vec3 green_color=vec3(0.365,0.49,0.205)*(1.0+0.025*sin(p.x*1.05));
 grass=mix(grass,green_color,putting);
 float tee=1.0-smoothstep(-0.1,0.1,ellipse_distance(p,tee_area));
 grass=mix(grass,vec3(0.34,0.46,0.18),tee);
 // Filter fine texture in screen space to prevent the old striped moire.
 float footprint=max(length(dFdx(p)),length(dFdy(p)));
 float fine_fade=1.0-smoothstep(0.025,0.18,footprint);
 float fine=(noise(p*42.0)-0.5)*fine_fade;
 grass*=1.0+(noise(p*0.65)-0.5)*0.055+fine*0.075;
 float sand_edge=10000.0;
 for(int h=0;h<8;h++) {
  if(h>=bunker_count) break;
  sand_edge=min(sand_edge,ellipse_distance(p,bunker_ellipses[h]));
 }
 float aa=max(0.025,fwidth(sand_edge)*0.65);
 float sand=1.0-smoothstep(-aa,aa,sand_edge);
 // A narrow cut turf lip and warm, gently shaded bowl; no surrounding beige disc.
 grass*=1.0-0.14*(1.0-smoothstep(0.0,0.26,sand_edge));
 float rake=sin(p.x*21.0+sin(p.y*0.38)*2.0)*(1.0-smoothstep(0.06,0.25,footprint));
 vec3 sand_color=vec3(0.76,0.66,0.445)*(1.0+(noise(p*1.7)-0.5)*0.045+fine*0.045+rake*0.008);
 sand_color*=mix(1.0,0.84,smoothstep(-0.8,0.0,sand_edge));
 vec3 surface=mix(grass,sand_color,sand);
 float wet_edge=10000.0;
 for(int h=0;h<24;h++) {
  if(h>=pond_count) break;
  wet_edge=min(wet_edge,ellipse_distance(p,pond_ellipses[h]));
 }
 for(int h=1;h<24;h++) {
  if(h>=creek_count) break;
  vec2 a=creek_path[h-1], ab=creek_path[h]-a;
  float along=clamp(dot(p-a,ab)/dot(ab,ab),0.0,1.0);
  wet_edge=min(wet_edge,length(p-a-ab*along)-4.5);
 }
 float wet_aa=max(0.025,fwidth(wet_edge)*0.65);
 float water=1.0-smoothstep(-wet_aa,wet_aa,wet_edge);
 float damp=1.0-smoothstep(0.0,0.7,wet_edge);
 surface=mix(surface,surface*vec3(0.70,0.77,0.72),damp*0.52);
 float wave=sin(dot(p,vec2(2.4,0.7))+TIME*0.65+noise(p*0.7)*2.0)*0.6+sin(dot(p,vec2(-1.6,3.7))-TIME*0.48)*0.4;
 float shallow=1.0-smoothstep(0.0,2.7,-wet_edge);
 vec3 water_color=mix(vec3(0.035,0.16,0.175),vec3(0.16,0.26,0.205),shallow*0.60);
 water_color+=vec3(0.009,0.012,0.013)*wave;
 ALBEDO=mix(surface,water_color,water);
 ROUGHNESS=mix(0.94,0.24,water);
 SPECULAR=mix(0.22,0.65,water);
 // World-space normals are already smooth; no undefined mesh tangents/normal map.
 NORMAL=normalize(NORMAL+vec3(wave*0.008,0.0,wave*0.005)*water);
}
