shader_type canvas_item;
render_mode unshaded;
uniform float pixels_per_metre = 8.0;
uniform bool overview = false;
varying vec2 ground_position;
float random_value(vec2 p) { return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453); }
float noise(vec2 p) {
 vec2 cell=floor(p), f=fract(p); f=f*f*(3.0-2.0*f);
 return mix(mix(random_value(cell),random_value(cell+vec2(1,0)),f.x),mix(random_value(cell+vec2(0,1)),random_value(cell+vec2(1,1)),f.x),f.y);
}
void vertex() { ground_position=VERTEX/pixels_per_metre; }
void fragment() {
 vec2 p=ground_position;
 vec4 base=COLOR;
 float patches=noise(p*0.16)*0.65+noise(p*0.43)*0.35;
 float fine=noise(p*7.0);
 float detail=overview ? 0.0 : 1.0-smoothstep(0.16,0.65,length(fwidth(p)));
 vec2 blades=p*5.5;
 vec2 cell=floor(blades), f=fract(blades);
 float seed=random_value(cell);
 float blade=(1.0-smoothstep(0.03,0.13,abs(f.x-(0.2+seed*0.6)+(f.y-0.5)*0.22)))*smoothstep(0.0,0.2,f.y)*(1.0-smoothstep(0.7,1.0,f.y));
 vec3 grass=base.rgb*(0.84+patches*0.26);
 grass+=vec3(0.020,0.035,-0.006)*(patches-0.5);
 grass+=(fine-0.5)*0.07*detail;
 grass+=vec3(0.035,0.055,0.012)*blade*detail;
 COLOR=vec4(mix(base.rgb,grass,step(0.5,UV.x)),base.a);
}
