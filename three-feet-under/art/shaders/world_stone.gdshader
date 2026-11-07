// Project-authored meter-scale stone. No external textures or shader dependencies.
shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;
uniform vec4 stone_color : source_color = vec4(0.37, 0.34, 0.29, 1.0);
uniform vec4 joint_color : source_color = vec4(0.095, 0.087, 0.075, 1.0);
uniform vec2 block_size = vec2(1.1, 0.46);
uniform float joint_width = 0.018;
uniform float relief = 0.016;
uniform float rock_mode = 0.0;
uniform float wear = 0.55;
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
 float grain=noise2(uv*33.0);
 // 高频颗粒在远处会欠采样，dFdx 求梯度时变成规律斜纹（表面像灯芯绒）——按屏幕导数淡出，只让大尺度起伏参与 bump
 float grain_aa=clamp(1.0-max(fwidth(uv.x),fwidth(uv.y))*33.0,0.0,1.0);
 float grain_bump=mix(0.5,grain,grain_aa);
 float broad=noise2(uv*1.7);
 vec2 q=uv/block_size;
 float row=floor(q.y);
 q.x+=mod(row,2.0)*0.5;
 vec2 cell=floor(q), f=fract(q);
 float id=hash21(cell);
 vec2 edge=min(f,1.0-f)*block_size;
 float edge_dist=min(edge.x,edge.y);
 float chipped=(noise2(uv*12.0)-0.5)*0.012*wear;
 float aa=max(fwidth(edge_dist),0.001);
 float seam=smoothstep(joint_width*0.5-aa,joint_width*0.5+0.016+aa,edge_dist+chipped);
 // 掠射/远处一格石缝只占不到一个像素时，逐像素取值会拍出规律斜纹——按屏幕尺度淡出块缝
 float cell_px=max(fwidth(q.x),fwidth(q.y));
 float block_fade=smoothstep(0.28,1.1,cell_px);
 seam=mix(seam,1.0,block_fade);
 float bevel=smoothstep(0.0,0.05,edge_dist);
 // Sparse branching hairline cracks, offset independently in each stone.
 float crack_line=abs(f.y-(0.2+0.45*f.x+0.045*sin(f.x*23.0+id*8.0)));
 float crack=(1.0-smoothstep(0.002,0.008,crack_line))*step(0.76,id)*wear;
 float mottled=0.84+id*0.25+(broad-0.5)*0.18+(grain-0.5)*0.10;
 vec3 color=mix(joint_color.rgb,stone_color.rgb*mottled,seam);
 color*=1.0-crack*0.48;
 float height=seam*relief*bevel+(grain_bump-0.5)*0.002-crack*0.004;
 if (rock_mode>0.5) {
  float strata=0.5+0.5*sin(uv.y*11.0+noise2(uv*0.35)*7.0);
  float fissure=pow(abs(sin(uv.x*1.1+noise2(uv*0.3)*4.0)),26.0);
  color=stone_color.rgb*(0.70+broad*0.30+strata*0.10+grain*0.08)*(1.0-fissure*0.13);
  height=broad*0.018+strata*0.004+grain_bump*0.0015;
 }
 // Surface-gradient bump works without UV tangents and keeps world scale on long boxes.
 // 切线基从屏幕导数直接归一化：薄板/掠射像素上 dFdx×dy 的面积 det 会趋近 0，
 // 原来用 sign(det) 归一化会让法线逐像素翻号，薄片表面因此出现规律斜条纹。
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
 ROUGHNESS=clamp(0.87+grain*0.1,0.0,1.0);
 SPECULAR=0.18;
 AO=rock_mode>0.5 ? 0.9 : mix(0.50,1.0,seam);
 AO_LIGHT_AFFECT=0.35;
}
