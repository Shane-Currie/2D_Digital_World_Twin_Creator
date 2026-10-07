'use strict';
const PARTS=['torso','head','left_upper_arm','left_forearm','right_upper_arm','right_forearm','left_thigh','left_shin','right_thigh','right_shin'];
const VIEWS=['front','left','right','back'];
const object=value=>value!==null && typeof value==='object' && !Array.isArray(value);
const number=(value,min,max)=>typeof value==='number' && Number.isFinite(value) && value>=min && value<=max;
const pair=(value,min,max)=>Array.isArray(value) && value.length===2 && value.every(item=>number(item,min,max));
const safePath=value=>typeof value==='string' && value.startsWith('assets/npcs/') && !value.includes('..') && !value.includes('\\') && /\.(png|webp)$/i.test(value);
function complete(rig,view){return PARTS.every(key=>typeof rig?.views?.[view]?.parts?.[key]?.image==='string' && rig.views[view].parts[key].image.length>0);}
function validateRig(rig){
  const fail=message=>({ok:false,message,paths:[]});
  if(!object(rig) || rig.version!==1 || typeof rig.enabled!=='boolean' || !object(rig.views))return fail('Unsupported body-parts skeleton.');
  if(!number(rig.walk_cycles_per_second,.5,3) || !number(rig.stride_degrees,0,40))return fail('Walking speed must be 0.5–3 cycles/sec and stride 0–40 degrees.');
  const paths=[];
  for(const [view,value] of Object.entries(rig.views)){
    if(!VIEWS.includes(view) || !object(value) || !object(value.parts))return fail('Choose Front, Left, Right or Back for body-part artwork.');
    if(!PARTS.every(key=>Object.hasOwn(value.parts,key)))return fail('Each saved view needs all ten joint records; unused images may be blank.');
    for(const [key,part] of Object.entries(value.parts)){
      if(!PARTS.includes(key) || !object(part))return fail('Unknown body part.');
      if(typeof part.image!=='string' || (part.image && !safePath(part.image)))return fail('Body parts must use copied PNG/WebP images under assets/npcs.');
      if(!pair(part.position,-200,200) || !pair(part.size,1,120) || !pair(part.pivot,0,1))return fail('Body-part position, size or image pivot is outside the supported range.');
      if(Object.hasOwn(part,'region') && (!Array.isArray(part.region) || part.region.length!==4 || !number(part.region[0],0,4096) || !number(part.region[1],0,4096) || !number(part.region[2],.1,4096) || !number(part.region[3],.1,4096)))return fail('Invalid body-part atlas region.');
      if(!number(part.rotation_degrees,-180,180) || !Number.isInteger(part.z_index) || !number(part.z_index,0,20) || typeof part.flip_h!=='boolean')return fail('Invalid body-part rotation, layer or mirror setting.');
      if(part.image)paths.push(part.image);
    }
  }
  if(rig.enabled && !complete(rig,'front'))return fail('Upload all ten Front body parts before saving. Other views are optional; incomplete views use Front.');
  return {ok:true,message:'Body-parts skeleton is valid.',paths};
}
module.exports={validateRig,PARTS,VIEWS};
