// Project-authored meter-scale Eastern Han strip brick (东汉条砖, long face ~4:1).
// World-space projection so brick size stays constant at 1.5x environment scale.
// Dispatch 01 pilot: one corridor wall. Colors clamped to the style-anchor palette
// (夯土黄 #8A6D4F .. 砖灰 #6E6259), per-brick random tone, dirty joints, some bricks
// spalled to expose earthen core.
shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;
uniform vec4 brick_a : source_color = vec4(0.541, 0.427, 0.310, 1.0); // 夯土黄 #8A6D4F
uniform vec4 brick_b : source_color = vec4(0.431, 0.384, 0.349, 1.0); // 砖灰 #6E6259
uniform vec4 mortar_color : source_color = vec4(0.18, 0.16, 0.14, 1.0);
uniform vec4 core_color : source_color = vec4(0.60, 0.50, 0.35, 1.0); // 露出的土芯
uniform vec2 brick_size = vec2(0.44, 0.11);
uniform float joint_width = 0.012;
uniform float relief = 0.010;
uniform float wear = 0.6;
uniform float spall_chance = 0.18;
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
 float grain=noise2(uv*38.0);
 float broad=noise2(uv*1.6);
 vec2 q=uv/brick_size;
 float row=floor(q.y);
 q.x+=mod(row,2.0)*0.5; // running bond: 错缝，隔行错半砖
 vec2 cell=floor(q), f=fract(q);
 float id=hash21(cell);
 vec2 edge=min(f,1.0-f)*brick_size;
 float edge_dist=min(edge.x,edge.y);
 float chipped=(noise2(uv*15.0)-0.5)*0.010*wear;
 float aa=max(fwidth(edge_dist),0.001);
 float seam=smoothstep(joint_width*0.5-aa,joint_width*0.5+0.010+aa,edge_dist+chipped);
 float bevel=smoothstep(0.0,0.04,edge_dist);
 // 单砖深浅随机：夯土黄 ↔ 砖灰
 float tone=hash21(cell+vec2(9.7,3.1));
 vec3 brick=mix(brick_a.rgb,brick_b.rgb,tone);
 // 部分砖剥落露土芯：每砖随机 ~spall_chance，块内一块噪声斑
 float spall_on=step(1.0-spall_chance,hash21(cell+vec2(41.3,17.7)));
 vec2 sc=vec2(0.3+0.4*hash21(cell+vec2(5.1,7.9)),0.4+0.4*hash21(cell+vec2(11.9,3.3)));
 float sr=0.22+0.22*hash21(cell+vec2(77.1,13.9));
 float sd=distance(f,sc)/sr;
 float spall_e=noise2(f*9.0+cell*1.3);
 float spall=smoothstep(1.0,0.75,sd-0.15*(spall_e-0.5))*spall_on;
 float mottled=0.90+id*0.20+(broad-0.5)*0.16+(grain-0.5)*0.10;
 vec3 surf=mix(brick,core_color.rgb*(0.85+0.3*broad),spall);
 // 砖缝带积土：缝心更脏更深，缝内随机积尘
 float groove=1.0-smoothstep(0.0,joint_width*0.5,edge_dist);
 vec3 mortar=mortar_color.rgb*(0.8+0.4*noise2(uv*7.0+cell*3.7));
 vec3 color=mix(mortar,surf*mottled,seam);
 color*=1.0-groove*0.12; // 积土在缝里压暗
 // 剥落处下凹；远处按屏幕导数保持稳定
 float height=seam*relief*bevel+(grain-0.5)*0.002-spall*0.010;
 vec3 dx=dFdx(world_pos), dy=dFdy(world_pos);
 vec3 t1=dx-wn*dot(wn,dx);
 t1=length(t1)>1e-7?normalize(t1):normalize(cross(wn,vec3(0.0,0.0,1.0))+vec3(1e-5,0.0,0.0));
 vec3 t2=normalize(cross(wn,t1));
 vec2 dpix=vec2(max(length(dx),1e-6),max(length(dy),1e-6));
 vec2 slope=vec2(dFdx(height),dFdy(height))/dpix;
 vec3 gradient=clamp(t1*slope.x+t2*slope.y,vec3(-1.0),vec3(1.0));
 vec3 bumped=normalize(wn-gradient*0.6);
 NORMAL=normalize((VIEW_MATRIX*vec4(bumped,0.0)).xyz);
 ALBEDO=color;
 ROUGHNESS=clamp(0.92+grain*0.08,0.0,1.0);
 SPECULAR=0.1;
 AO=mix(0.45,1.0,seam);
 AO_LIGHT_AFFECT=0.35;
}