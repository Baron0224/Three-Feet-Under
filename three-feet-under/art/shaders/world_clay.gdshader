// Project-authored meter-scale clay (pottery/mingqi). No external textures.
// World-space mottling + faint drying cracks + soft bumps; same gradient-bump
// technique as world_stone.gdshader so long boxes stay uniform.
shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;
uniform vec4 clay_color : source_color = vec4(0.60, 0.40, 0.27, 1.0);
uniform vec4 dark_color : source_color = vec4(0.46, 0.30, 0.20, 1.0);
uniform float wear = 0.6;
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
 float grain=world_noise(world_pos/scale_m,26.0,wn);
 float broad=world_noise(world_pos/scale_m,2.1,wn);
 float blob=world_noise(world_pos/scale_m,0.55,wn);
 // pale firing ring + darker mottling
 float mottled=clamp(0.80+broad*0.35+(grain-0.5)*0.22+(blob-0.5)*0.30,0.0,1.0);
 float darken=smoothstep(0.42,0.62,blob)*wear*0.35;
 vec3 color=mix(dark_color.rgb,clay_color.rgb*mottled,1.0-darken);
 // faint drying cracks on the largest surfaces
 float crack_line=abs(fract(uv.x*1.7+uv.y*0.9)-0.5);
 float crack=(1.0-smoothstep(0.004,0.014,crack_line))*step(0.86,world_noise(world_pos/scale_m,5.0,wn))*wear*0.25;
 color*=1.0-crack;
 float height=(grain-0.5)*0.0006-broad*0.0008-crack*0.0015;
 vec3 dx=dFdx(world_pos), dy=dFdy(world_pos);
 vec3 rx=cross(dy,wn), ry=cross(wn,dx);
 float det=dot(dx,rx);
 vec3 gradient=sign(det)*(dFdx(height)*rx+dFdy(height)*ry);
 vec3 bumped=normalize(max(abs(det),0.0000001)*wn-gradient);
 NORMAL=normalize((VIEW_MATRIX*vec4(bumped,0.0)).xyz);
 ALBEDO=color;
 ROUGHNESS=clamp(0.80+grain*0.14+broad*0.06,0.0,1.0);
 SPECULAR=0.06;
 AO=mix(0.55,1.0,mottled);
 AO_LIGHT_AFFECT=0.4;
}