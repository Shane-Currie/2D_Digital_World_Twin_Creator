'use strict';

// Mirrors InteriorStairs: 1.4 x 2.4 m artwork plus a 10 cm gap per side.
const rectangle = (p, size = [1.6, 2.6], rotation = 0) => {
  const c = Math.cos(rotation), s = Math.sin(rotation);
  return [[-1,-1],[1,-1],[1,1],[-1,1]].map(([x,y]) => {
    x *= size[0]/2; y *= size[1]/2;
    return [p[0] + x*c-y*s, p[1] + x*s+y*c];
  });
};
const cross = (a,b,c) => (b[0]-a[0])*(c[1]-a[1])-(b[1]-a[1])*(c[0]-a[0]);
function onEdge(p,a,b) {
  return Math.abs(cross(a,b,p)) < 1e-8 && p[0] >= Math.min(a[0],b[0])-1e-8 && p[0] <= Math.max(a[0],b[0])+1e-8 && p[1] >= Math.min(a[1],b[1])-1e-8 && p[1] <= Math.max(a[1],b[1])+1e-8;
}
function inside(p, polygon) {
  let hit = false;
  for (let i=0,j=polygon.length-1; i<polygon.length; j=i++) {
    const a=polygon[i], b=polygon[j];
    if(onEdge(p,a,b)) return true;
    if ((a[1]>p[1]) !== (b[1]>p[1]) && p[0] < (b[0]-a[0])*(p[1]-a[1])/(b[1]-a[1])+a[0]) hit=!hit;
  }
  return hit;
}
function intersects(a,b,c,d, strict=false) {
  const x=cross(a,b,c), y=cross(a,b,d), z=cross(c,d,a), w=cross(c,d,b);
  if(x*y < -1e-10 && z*w < -1e-10) return true;
  return !strict && (onEdge(a,c,d)||onEdge(b,c,d)||onEdge(c,a,b)||onEdge(d,a,b));
}
function overlaps(a,b) {
  if (a.some(p=>inside(p,b)) || b.some(p=>inside(p,a))) return true;
  return a.some((p,i)=>b.some((q,j)=>intersects(p,a[(i+1)%a.length],q,b[(j+1)%b.length])));
}
function fits(floor,p,otherPoints,angle=0) {
  const shape=rectangle(p, [1.6,2.6], angle), outer=floor.boundary_metres;
  if (!Array.isArray(outer)||outer.length<3||shape.some(q=>!inside(q,outer))) return false;
  if(shape.some((a,i)=>outer.some((b,j)=>intersects(a,shape[(i+1)%4],b,outer[(j+1)%outer.length],true)))) return false;
  if((floor.holes_metres||[]).some(h=>overlaps(shape,h))) return false;
  for(const wall of (floor.walls||[])) {
    const a=[wall.start_x_metres,wall.start_y_metres], b=[wall.end_x_metres,wall.end_y_metres];
    const length=Math.hypot(b[0]-a[0],b[1]-a[1]);
    const margin=wall.thickness_metres/2+0.05;
    const side=[-(b[1]-a[1])/length*margin,(b[0]-a[0])/length*margin];
    const polygon=[[a[0]+side[0],a[1]+side[1]],[b[0]+side[0],b[1]+side[1]],[b[0]-side[0],b[1]-side[1]],[a[0]-side[0],a[1]-side[1]]];
    if(overlaps(shape,polygon)) return false;
  }
  if((floor.furniture||[]).some(item=>overlaps(shape,rectangle([item.x_metres,item.y_metres],[item.width_metres,item.depth_metres],(item.rotation_degrees||0)*Math.PI/180)))) return false;
  if((floor.entry_links||[]).some(link=>overlaps(shape,rectangle([link.spawn_x_metres,link.spawn_y_metres],[1.6,1.6])))) return false;
  return !otherPoints.some(e=>overlaps(shape,rectangle([e.x_metres,e.y_metres],[1.6,2.6],(e.rotation_degrees||0)*Math.PI/180)));
}
function validateInteriorStairs(record) {
	if(!record || !Array.isArray(record.floors)) return false;
  const pairs=record.stairs ?? [], ids=new Set();
  if(!Array.isArray(pairs)||pairs.length>40) return false;
  for(const pair of pairs) {
    if(!pair||typeof pair.id!=='string'||!pair.id||ids.has(pair.id)||!pair.from||!pair.to||pair.from.floor_id===pair.to.floor_id) return false;
    ids.add(pair.id);
    for(const endpoint of [pair.from,pair.to]) {
      if(typeof endpoint.floor_id!=='string'||![endpoint.x_metres,endpoint.y_metres].every(n=>typeof n==='number'&&Number.isFinite(n))) return false;
      const rotation=endpoint.rotation_degrees ?? 0;
      if(typeof rotation!=='number'||!Number.isFinite(rotation)||rotation<0||rotation>=360) return false;
      const floor=record.floors.find(f=>f.id===endpoint.floor_id);
      if(!floor) return false;
      const others=pairs.filter(other=>other!==pair).flatMap(other=>[other?.from,other?.to]).filter(e=>e?.floor_id===endpoint.floor_id);
      if(!fits(floor,[endpoint.x_metres,endpoint.y_metres],others,rotation*Math.PI/180)) return false;
    }
  }
  return true;
}
module.exports = {validateInteriorStairs, rectangle, inside, overlaps};
