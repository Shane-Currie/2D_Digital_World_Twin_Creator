'use strict';
// Deterministic companion to building_connections.gd. Never bridges a gap.
const {rectangle, inside, overlaps} = require('./validate-stairs');
const fs=require('fs'), path=require('path');
const geometryPoints=f=>f.precise_points?.length?f.precise_points:f.points;
function withSourcePrecision(townDirectory,features) {
  const result=structuredClone(features), requested=new Set(), nodes=new Map();
  for(const feature of result) if(feature.precise_points!==undefined&&!Array.isArray(feature.precise_points)) {feature.shared_geometry_unverified=true; feature.precise_points=[];}
  for(const feature of result) if(feature.kind==='building'&&!feature.precise_points?.length) for(const id of feature.node_ids||[]) requested.add(String(id));
  if(!requested.size) return result;
  const metadata=JSON.parse(fs.readFileSync(path.join(townDirectory,'town.json'),'utf8'));
  const attr=(tag,name)=>tag.match(new RegExp(`\\b${name}\\s*=\\s*(['\"])(.*?)\\1`))?.[2];
  for(const source of metadata.source?.files||[]) {
    const relative=String(source).replace(/\\/g,'/');
    if(!relative.startsWith('source_osm/')||relative.includes('..')||!relative.endsWith('.osm')) continue;
    const filename=path.join(townDirectory,relative); if(!fs.existsSync(filename)) continue;
    const xml=fs.readFileSync(filename,'utf8');
    for(const match of xml.matchAll(/<node\b[^>]*>/g)) {
      const tag=match[0], id=attr(tag,'id'); if(!requested.has(id)) continue;
      const x=Number(attr(tag,'lon')), y=Number(attr(tag,'lat'));
      if(Number.isFinite(x)&&Number.isFinite(y)) nodes.set(id,[x,y]);
    }
  }
  for(const feature of result) {
    if(feature.kind!=='building'||feature.precise_points?.length||!feature.node_ids?.length) continue;
    const points=feature.node_ids.map(id=>nodes.get(String(id))).filter(Boolean);
    if(points.length===feature.points.length) feature.precise_points=points;
    else feature.shared_geometry_unverified=true;
  }
  return result;
}
const EPS = 0.001;
const sub=(a,b)=>[a[0]-b[0],a[1]-b[1]];
const add=(a,b)=>[a[0]+b[0],a[1]+b[1]];
const mul=(a,n)=>[a[0]*n,a[1]*n];
const dot=(a,b)=>a[0]*b[0]+a[1]*b[1];
const cross=(a,b)=>a[0]*b[1]-a[1]*b[0];
const length=a=>Math.hypot(...a);
const distance=(a,b)=>length(sub(a,b));
const closest=(p,a,b)=>add(a,mul(sub(b,a),Math.max(0,Math.min(1,dot(sub(p,a),sub(b,a))/dot(sub(b,a),sub(b,a))))));
const project=(p,r)=>[(p[0]-r[0])*111320*Math.cos(r[1]*Math.PI/180),-(p[1]-r[1])*110540];
const ring=values=>values.length>1&&values[0][0]===values.at(-1)[0]&&values[0][1]===values.at(-1)[1]?values.slice(0,-1):values;
const edges=r=>r.map((p,i)=>[p,r[(i+1)%r.length]]);
const position=e=>[e.x_metres,e.y_metres];
const wall=e=>[e.wall_x_metres,e.wall_y_metres];
function sharedSegments(a,b) {
  if(!a||!b||a.id===b.id||a.shared_geometry_unverified||b.shared_geometry_unverified) return [];
  const r=geometryPoints(a)[0], ar=ring(geometryPoints(a)).map(p=>project(p,r)), br=ring(geometryPoints(b)).map(p=>project(p,r)), result=[];
  for(const [start,end] of edges(ar)) {
    const size=distance(start,end); if(size<1.8) continue;
    const direction=mul(sub(end,start),1/size);
    for(const [p,q] of edges(br)) {
      if(Math.abs(cross(direction,sub(p,start)))>EPS||Math.abs(cross(direction,sub(q,start)))>EPS) continue;
      const lo=Math.max(0,Math.min(dot(direction,sub(p,start)),dot(direction,sub(q,start))));
      const hi=Math.min(size,Math.max(dot(direction,sub(p,start)),dot(direction,sub(q,start))));
      if(hi-lo<1.8) continue;
      const middle=add(start,mul(direction,(lo+hi)/2)), side=[-direction[1]*.05,direction[0]*.05];
      if(inside(add(middle,side),ar)===inside(add(middle,side),br)) continue;
      result.push([add(start,mul(direction,lo)),add(start,mul(direction,hi))]);
    }
  }
  return result;
}
function expectedWall(feature,floor,anchor) {
  // Match the saved float-vector interior generator, not a newly moved floor.
  const geo=ring(geometryPoints(feature)), legacy=ring(feature.points).map(p=>p.map(Math.fround));
  const min=[0,1].map(i=>Math.min(...legacy.map(p=>p[i]))), max=[0,1].map(i=>Math.max(...legacy.map(p=>p[i])));
  const centre=min.map((n,i)=>Math.fround(n+Math.fround(max[i]-n)*.5));
  const projected=legacy.map(p=>project(p,centre).map(Math.fround));
  const lower=[0,1].map(i=>Math.min(...projected.map(p=>p[i])));
  const reference=geometryPoints(feature)[0], requested=project(anchor,reference);
  for(let i=0;i<geo.length;i++) {
    const a=project(geo[i],reference), b=project(geo[(i+1)%geo.length],reference), hit=closest(requested,a,b);
    if(distance(hit,requested)>.04) continue;
    const t=dot(sub(hit,a),sub(b,a))/dot(sub(b,a),sub(b,a));
    const p=add(projected[i],mul(sub(projected[(i+1)%geo.length],projected[i]),t));
    return mul(sub(p,lower),floor.footprint_scale||1);
  }
  return null;
}
function blocksItem(item,p,clearance) {
  const angle=-(item.rotation_degrees||0)*Math.PI/180, delta=sub(p,position(item));
  const local=[delta[0]*Math.cos(angle)-delta[1]*Math.sin(angle),delta[0]*Math.sin(angle)+delta[1]*Math.cos(angle)];
  // Built-in walk-in cubicles have multiple solids; regular objects use a box.
	  const parts=[]; // Reserve the full artwork envelope, including hollow cubicles.
  if(Array.isArray(parts)&&parts.length) return parts.some(part=>Math.abs(local[0]-(part.x||0))<part.width/2+clearance&&Math.abs(local[1]-(part.y||0))<part.depth/2+clearance);
  return Math.abs(local[0])<item.width_metres/2+clearance&&Math.abs(local[1])<item.depth_metres/2+clearance;
}
function validateBuildingConnections(data,features=[],npcs=[]) {
  try {
    const pairs=data.building_connections??[];
    if(!Array.isArray(pairs)||pairs.length>200) return false;
    const ids=new Set();
    for(const pair of pairs) {
      if(!pair||typeof pair.id!=='string'||!pair.id||ids.has(pair.id)||typeof (pair.locked??false)!=='boolean'||![pair.wall_longitude,pair.wall_latitude].every(Number.isFinite)||Math.abs(pair.wall_longitude)>180||Math.abs(pair.wall_latitude)>90) return false;
      ids.add(pair.id);
      for(const e of [pair.from,pair.to]) if(!e||typeof e.building_id!=='string'||typeof e.floor_id!=='string'||![...position(e),...wall(e),e.normal_x,e.normal_y].every(Number.isFinite)) return false;
    }
    for(const pair of pairs) {
      let level;
      for(const e of [pair.from,pair.to]) {
        const record=data.buildings[e.building_id], floor=record?.floors?.find(f=>f.id===e.floor_id), p=position(e), n=[e.normal_x,e.normal_y];
        if(!floor||Math.abs(length(n)-1)>.001||distance(p,add(wall(e),n))>.02||(level!==undefined&&level!==floor.level)) return false;
        level=floor.level;
        const outer=ring(floor.boundary_metres);
        if(!inside(p,outer)||edges(outer).some(([a,b])=>distance(p,closest(p,a,b))<.6)||Math.min(...edges(outer).map(([a,b])=>distance(wall(e),closest(wall(e),a,b))))>.02) return false;
        for(const hole of floor.holes_metres||[]) if(inside(p,hole)||edges(ring(hole)).some(([a,b])=>distance(p,closest(p,a,b))<.6)) return false;
        if((floor.walls||[]).some(w=>distance(p,closest(p,[w.start_x_metres,w.start_y_metres],[w.end_x_metres,w.end_y_metres]))<.6+w.thickness_metres/2)) return false;
        if((floor.furniture||[]).some(item=>blocksItem(item,p,.6))) return false;
        if((floor.entry_links||[]).some(link=>distance(p,[link.spawn_x_metres,link.spawn_y_metres])<1.4)) return false;
        if((record.stairs||[]).flatMap(s=>[s.from,s.to]).some(s=>s.floor_id===e.floor_id&&overlaps(rectangle(p,[1.2,1.2]),rectangle(position(s),[2.7,3.7],(s.rotation_degrees||0)*Math.PI/180)))) return false;
        if(pairs.filter(s=>s!==pair).flatMap(s=>[s.from,s.to]).some(s=>s.building_id===e.building_id&&s.floor_id===e.floor_id&&distance(p,position(s))<1.4)) return false;
        if(npcs.some(s=>s.location?.space==='interior'&&s.location.building_id===e.building_id&&s.location.floor_id===e.floor_id&&distance(p,position(s.location))<1.2)) return false;
        if(features.length) {
          const feature=features.find(f=>f.kind==='building'&&f.id===e.building_id), expected=feature&&expectedWall(feature,floor,[pair.wall_longitude,pair.wall_latitude]);
          if(!expected||distance(expected,wall(e))>.04) return false;
          let best=Infinity, expectedArrival;
          for(const [a,b] of edges(outer)) {
            const hit=closest(expected,a,b), d=distance(hit,expected);
            if(d>best||d>.04*(floor.footprint_scale||1)) continue;
            const delta=sub(b,a), size=length(delta); if(!size) continue;
            let inward=[-delta[1]/size,delta[0]/size];
            if(!inside(add(hit,mul(inward,.1)),outer)) inward=mul(inward,-1);
            best=d; expectedArrival=add(hit,inward);
          }
          if(!expectedArrival||distance(expectedArrival,p)>.04) return false;
        }
      }
      if(pair.from.building_id===pair.to.building_id||dot([pair.from.normal_x,pair.from.normal_y],[pair.to.normal_x,pair.to.normal_y])>-.99) return false;
      if(features.length) {
        const a=features.find(f=>f.kind==='building'&&f.id===pair.from.building_id), b=features.find(f=>f.kind==='building'&&f.id===pair.to.building_id);
        const anchor=a&&project([pair.wall_longitude,pair.wall_latitude],geometryPoints(a)[0]);
        if(!anchor||!sharedSegments(a,b).some(([p,q])=>distance(anchor,closest(anchor,p,q))<EPS&&Math.min(distance(anchor,p),distance(anchor,q))>=.8)) return false;
      }
    }
    return true;
  } catch {return false;}
}
module.exports={validateBuildingConnections,sharedSegments,withSourcePrecision};
