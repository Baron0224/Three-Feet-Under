// Project-authored meter-scale bronze (ding, boshan, lamps, ritual vessels).
// World-space patina mottling + scratches + dry specular; gradient-bump same
// technique as world_stone.gdshader.
shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;
uniform vec4 bronze_color : source_color = vec4(0.16, 0.12, 0.075, 1.0);
uniform vec4 patina_color : source_color = vec4(0.13, 0.24, 0.19, 1.0);
uniform float wear = 0.65;
uniform float scale_m = 1.0;
varying vec3 world_pos;
varying vec3 world_normal;
float hash21(vec2 p) { return fract(sin(dot(p, vec2(127.1,311.7))) * 43758.5453); }
float noise2(vec2 p) {
 vec2 i=floor(p), f=fract(p); f=f*f*(3.0-2.0*f);
 return mix(mix(hash21(i),hash21(i+vec2(1,0)),f.x),mix(hash21(i+vec2(0,1)),hash21(i+vec2(1,1)),f.x),f.y);
}
float world_noise(vec3 p, float freq, vec3 n) {
 vec3 w=pow(abs(n),vec3(4.0)); w/=max(w.x+w.y+w.z,0.0001);
 return dot(w,vec3(noise2(p.yz*freq),noise2(p.xz*freq),noise2(p.xy*freq)));
}
void vertex() {
 world_pos=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
 world_normal=normalize(MODEL_NORMAL_MATRIX*NORMAL);
}
void fragment() {
 vec3 wn=normalize(world_normal);
 vec2 uv=world_pos.xz/scale_m;
 float grain=world_noise(world_pos/scale_m,38.0,wn);
 float broad=world_noise(world_pos/scale_m,2.6,wn);
 float pat=world_noise(world_pos/scale_m,1.3,wn);
 // patina blobs (green oxide) + polish wear where people touched
 float patina=smoothstep(0.46,0.62,pat)*wear;
 float shine=smoothstep(0.62,0.74,broad)*wear*0.6;
 vec3 color=mix(bronze_color.rgb,patina_color.rgb,patina*0.75);
 color*=0.86+grain*0.28+(broad-0.5)*0.2;
 // scratches: fine parallel streaks, sparse
 float scratch_line=abs(fract(uv.x*13.0+world_noise(world_pos/scale_m,2.0,wn)*4.0)-0.5);
 float scratch=(1.0-smoothstep(0.001,0.005,scratch_line))*step(0.90,world_noise(world_pos/scale_m,7.0,wn))*wear;
 color*=1.0-scratch*0.5;
 float height=(grain-0.5)*0.003+(broad-0.5)*0.006-scratch*0.006;
 vec3 dx=dFdx(world_pos), dy=dFdy(world_pos);
 vec3 rx=cross(dy,wn), ry=cross(wn,dx);
 float det=dot(dx,rx);
 vec3 gradient=sign(det)*(dFdx(height)*rx+dFdy(height)*ry);
 vec3 bumped=normalize(max(abs(det),0.0000001)*wn-gradient);
 NORMAL=normalize((VIEW_MATRIX*vec4(bumped,0.0)).xyz);
 ALBEDO=color;
 ROUGHNESS=clamp(0.60+grain*0.30+broad*0.12,0.0,1.0);
 METALLIC=mix(0.55,0.15,patina*0.8);
 SPECULAR=0.35;
 AO=mix(0.5,1.0,broad);
 AO_LIGHT_AFFECT=0.4;
}