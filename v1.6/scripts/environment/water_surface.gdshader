shader_type canvas_item;
render_mode unshaded;
uniform float pixels_per_metre = 8.0;
uniform bool overview = false;
uniform float preview_time = -1.0;
varying vec2 water_position;
float hash_water(vec2 p) { return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453); }
float water_noise(vec2 p) {
 vec2 i=floor(p),f=fract(p); f=f*f*(3.0-2.0*f);
 return mix(mix(hash_water(i),hash_water(i+vec2(1,0)),f.x),mix(hash_water(i+vec2(0,1)),hash_water(i+vec2(1,1)),f.x),f.y);
}
void vertex() { water_position=VERTEX/pixels_per_metre; }
void fragment() {
 vec2 p=water_position;
 float t=preview_time < 0.0 ? TIME : preview_time;
 vec4 base=COLOR;
 vec2 drift=vec2(t*0.06,-t*0.035);
 float swell=water_noise(p*0.23+drift);
 float warp=water_noise(p*0.70-drift)*4.0+water_noise(p*0.18+drift)*5.0;
 float broad=swell*2.0-1.0;
 float ripple=sin(p.x*1.8+p.y*0.85+t*0.7+warp);
 float secondary=water_noise(p*1.65+vec2(t*0.08,0.0));
 float detail=overview ? 0.15 : 1.0-smoothstep(0.25,0.8,length(fwidth(p)));
 float glint=smoothstep(0.88,0.99,ripple)*smoothstep(0.58,0.84,secondary)*detail;
 vec3 colour=base.rgb*(0.88+broad*0.09);
 colour+=vec3(0.018,0.038,0.035)*ripple*detail;
 colour=mix(colour,vec3(0.61,0.84,0.80),glint*0.25);
 COLOR=vec4(colour,base.a);
}
