shader_type canvas_item;
uniform float pixels_per_metre = 8.0;
uniform float preview_time = -1.0;
void vertex() {
 float t=preview_time < 0.0 ? TIME : preview_time;
 float crown=1.0-smoothstep(0.55,0.9,UV.y);
 VERTEX.x+=sin(t*0.85+VERTEX.y*0.012)*pixels_per_metre*0.09*crown;
}
