shader_type spatial;
render_mode cull_disabled;
uniform bool use_vertex_color = true;
uniform vec4 turf_color : source_color = vec4(0.25,0.42,0.18,1.0);
varying vec3 world_pos;
float hash(vec2 p) { return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453); }
void vertex() { world_pos=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz; }
void fragment() {
 vec3 base=use_vertex_color ? COLOR.rgb : turf_color.rgb;
 float grain=hash(floor(world_pos.xz*95.0));
 float fleck=hash(floor(world_pos.xz*7.0));
 float fade=1.0-smoothstep(30.0,130.0,distance(CAMERA_POSITION_WORLD,world_pos));
 ALBEDO=base*(0.96+0.045*fleck+(grain-0.5)*0.065*fade);
 ROUGHNESS=0.96;
 NORMAL_MAP=vec3(0.5+(grain-0.5)*0.045*fade,0.5+(fleck-0.5)*0.03*fade,1.0);
 NORMAL_MAP_DEPTH=0.3;
}
