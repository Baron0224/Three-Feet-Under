// Project-authored meter-scale brick (Han-Dynasty-style vault voussoirs).
// World-space projection so brick size stays constant at 1.5x environment scale.
shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;
uniform vec4 brick_color : source_color = vec4(0.42, 0.38, 0.33, 1.0);
uniform vec4 mortar_color : source_color = vec4(0.20, 0.18, 0.16, 1.0);
uniform vec2 brick_size = vec2(0.55, 0.26);
uniform float joint_width = 0.012;
uniform float relief = 0.008;
uniform float wear = 0.45;
varying vec3 world_pos;
varying vec3 world_normal;
float hash21(vec2 p) { return fract(sin(dot(p, vec2(127.1,311.7))) * 43758.5453); }
float noise2(vec2 p) {
 vec2 i=floor(p), f=fract(p); f=f*f*(3.0-2.0*f);
 return mix(mix(hash21(i),hash21(i+vec2(1,0)),f.x),mix(hash21(i+vec2(0,1)),hash21(i+vec2(1,1)),f.x),f.y);
}
void vertex() {
 world_pos=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
 world_normal=normalize(MODEL_NORMAL_MATRIX*NORMAL);
}
void fragment() {
 vec3 wn=normalize(world_normal);
 vec3 aw=abs(wn);
 vec2 uv=world_pos.xz;
 if (aw.y < max(aw.x,aw.z)) {
  uv=aw.x>aw.z ? vec2(world_pos.z,world_pos.y) : vec2(world_pos.x,world_pos.y);
 }
 float grain=noise2(uv*40.0);
 float broad=noise2(uv*1.5);
 vec2 q=uv/brick_size;
 float row=floor(q.y);
 q.x+=mod(row,2.0)*0.5; // running bond: bricks in every other row offset half a brick
 vec2 cell=floor(q), f=fract(q);
 float id=hash21(cell);
 vec2 edge=min(f,1.0-f)*brick_size;
 float edge_dist=min(edge.x,edge.y);
 float chipped=(noise2(uv*14.0)-0.5)*0.010*wear;
 float aa=max(fwidth(edge_dist),0.001);
 float seam=smoothstep(joint_width*0.5-aa,joint_width*0.5+0.010+aa,edge_dist+chipped);
 float bevel=smoothstep(0.0,0.04,edge_dist);
 float mottled=0.88+id*0.22+(broad-0.5)*0.14+(grain-0.5)*0.08;
 vec3 color=mix(mortar_color.rgb,brick_color.rgb*mottled,seam);
 float height=seam*relief*bevel+(grain-0.5)*0.002;
 vec3 dx=dFdx(world_pos), dy=dFdy(world_pos);
 vec3 rx=cross(dy,wn), ry=cross(wn,dx);
 float det=dot(dx,rx);
 vec3 gradient=sign(det)*(dFdx(height)*rx+dFdy(height)*ry);
 vec3 bumped=normalize(max(abs(det),0.0000001)*wn-gradient);
 NORMAL=normalize((VIEW_MATRIX*vec4(bumped,0.0)).xyz);
 ALBEDO=color;
 ROUGHNESS=clamp(0.9+grain*0.08,0.0,1.0);
 SPECULAR=0.12;
 AO=mix(0.55,1.0,seam);
 AO_LIGHT_AFFECT=0.35;
}