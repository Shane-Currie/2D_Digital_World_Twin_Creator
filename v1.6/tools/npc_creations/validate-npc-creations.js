'use strict';

const fs = require('fs');
const path = require('path');
const {validateRig}=require('./validate-npc-rig');
const GENDERS = ['man', 'woman'];
const AGES = ['young', 'adult', 'older'];
const TONES = ['light', 'medium', 'dark'];
const POSES = ['idle', 'walk', 'sit'];
const VIEWS = ['front', 'left', 'right', 'back'];
const BUNDLED_MORPHEUS = path.resolve(__dirname, '../../assets/actors/custom/morpheus_v16.png');
const object = value => value !== null && typeof value === 'object' && !Array.isArray(value);
const safeId = value => typeof value === 'string' && /^[a-z0-9_-]{1,80}$/.test(value);
const safePath = value => typeof value === 'string' && value.startsWith('assets/npcs/') && !value.includes('..') && !value.includes('\\') && /\.(png|webp|jpe?g)$/i.test(value);

// Header dimensions enforce the same per-image import budget without decoding
// arbitrary uploaded pixels. Godot performs its own full image decode on import.
function imageDimensions(bytes, extension) {
  if (extension === '.png' && bytes.length >= 24 && bytes.subarray(0, 8).equals(Buffer.from([137,80,78,71,13,10,26,10])) && bytes.toString('ascii',12,16) === 'IHDR') return [bytes.readUInt32BE(16), bytes.readUInt32BE(20)];
  if (extension === '.webp' && bytes.length >= 30 && bytes.toString('ascii',0,4) === 'RIFF' && bytes.toString('ascii',8,12) === 'WEBP') {
    const kind = bytes.toString('ascii',12,16);
    if (kind === 'VP8X') return [bytes.readUIntLE(24,3)+1,bytes.readUIntLE(27,3)+1];
    if (kind === 'VP8 ' && bytes[23] === 0x9d && bytes[24] === 1 && bytes[25] === 0x2a) return [bytes.readUInt16LE(26)&0x3fff,bytes.readUInt16LE(28)&0x3fff];
    if (kind === 'VP8L' && bytes[20] === 0x2f) {
      const bits = bytes.readUInt32LE(21);
      return [(bits & 0x3fff)+1,((bits >>> 14)&0x3fff)+1];
    }
  }
  if (['.jpg','.jpeg'].includes(extension) && bytes.length >= 4 && bytes[0] === 0xff && bytes[1] === 0xd8) {
    let offset = 2;
    while (offset+4 <= bytes.length) {
      if (bytes[offset++] !== 0xff) return null;
      while (offset < bytes.length && bytes[offset] === 0xff) offset++;
      const marker = bytes[offset++];
      if (marker === 0xd9 || marker === 0xda) return null;
      if (marker === 0x01 || (marker >= 0xd0 && marker <= 0xd7)) continue;
      if (offset+2 > bytes.length) return null;
      const length = bytes.readUInt16BE(offset);
      if (length < 2 || offset+length > bytes.length) return null;
      if ([0xc0,0xc1,0xc2,0xc3,0xc5,0xc6,0xc7,0xc9,0xca,0xcb,0xcd,0xce,0xcf].includes(marker) && length >= 7) return [bytes.readUInt16BE(offset+5),bytes.readUInt16BE(offset+3)];
      offset += length;
    }
  }
  return null;
}

function validateImage(townDirectory, relativePath, part = false, region = []) {
  const target = path.resolve(townDirectory, relativePath);
  try {
    const stat = fs.statSync(target);
    if (!stat.isFile() || stat.size > (part?4:20)*1024*1024) return part?'Each body part must be a file smaller than 4 MB.':'Each NPC image must be a file smaller than 20 MB.';
    const dimensions = imageDimensions(fs.readFileSync(target),path.extname(relativePath).toLowerCase());
    if (!dimensions || dimensions.some(size => size < 1 || size > (part && region.length!==4?1024:4096))) return part?'Choose valid body parts no larger than 1024 pixels per side, or a bounded atlas.':'Choose valid NPC images no larger than 4096 pixels per side.';
    if(region.length===4 && (region[0]<0 || region[1]<0 || region[2]<=0 || region[3]<=0 || region[0]+region[2]>dimensions[0]+.01 || region[1]+region[3]>dimensions[1]+.01))return 'Body-part region exceeds its atlas.';
  } catch { return 'Missing or unreadable NPC image: ' + relativePath; }
  return '';
}

/** Data-only counterpart of NpcCreationStore. Empty directory skips file checks. */
function validateNpcCreations(catalogue, townDirectory = '', npcRecords = []) {
  const errors = [];
  const result = () => ({ok:errors.length === 0, errors, message:errors[0] || 'NPC artwork is valid.'});
  if (!object(catalogue) || catalogue.schema_version !== 1 || catalogue.kind !== 'npc_creations' || !Array.isArray(catalogue.creations)) return {ok:false,errors:['Unsupported NPC artwork catalogue.'],message:'Unsupported NPC artwork catalogue.'};
  if (catalogue.creations.length > 100) return {ok:false,errors:['Use at most 100 custom NPC creations per town.'],message:'Use at most 100 custom NPC creations per town.'};
  const creations = new Map();
  const checkedPaths = new Map();
  const bundled = fs.existsSync(BUNDLED_MORPHEUS);
  for (const item of catalogue.creations) {
    if (!object(item)) { errors.push('Invalid NPC creation record.'); continue; }
    if (!safeId(item.id) || item.id.startsWith('npc_') || creations.has(item.id)) errors.push('NPC creation IDs must be unique safe names.');
    creations.set(item.id,item);
    if (typeof item.name !== 'string' || !item.name.trim() || [...item.name].length > 80) errors.push('Give each creation a name (up to 80 characters).');
    if (!GENDERS.includes(item.gender) || !AGES.includes(item.age_group) || !TONES.includes(item.skin_tone_group)) errors.push('Choose man/woman, age and skin pigmentation for each human creation.');
    const anchor = item.seat_anchor_y ?? .58;
    if (typeof anchor !== 'number' || !Number.isFinite(anchor) || anchor < .35 || anchor > .75) errors.push('Sitting hip anchor must be between 35% and 75%.');
    const poses = item.poses ?? {};
    if (!object(poses)) { errors.push('Invalid pose list.'); continue; }
    let rigEnabled=false;
    if(Object.hasOwn(item,'rig')){
      const checked=validateRig(item.rig);
      if(!checked.ok)errors.push(checked.message);
      else {
        rigEnabled=item.rig.enabled;
        if(townDirectory)for(const view of Object.values(item.rig.views))for(const part of Object.values(view.parts)){
          const image=part.image;if(!image)continue;
          const key='part:'+image+JSON.stringify(part.region||[]);
          if(!checkedPaths.has(key))checkedPaths.set(key,validateImage(townDirectory,image,true,part.region||[]));
          if(checkedPaths.get(key))errors.push(checkedPaths.get(key));
        }
      }
    }
    if (!rigEnabled && (!object(poses.idle) || !Array.isArray(poses.idle.front) || !poses.idle.front.length) && !(item.id === 'morpheus' && bundled)) errors.push('Upload at least one front standing image, or complete a Front body-parts skeleton.');
    for (const [pose, views] of Object.entries(poses)) {
      if (!POSES.includes(pose) || !object(views)) { errors.push('Unsupported NPC pose.'); continue; }
      for (const [view, frames] of Object.entries(views)) {
        if (!VIEWS.includes(view) || !Array.isArray(frames) || frames.length > 8) { errors.push('Use up to eight frames per direction/pose.'); continue; }
        for (const frame of frames) {
          if (!safePath(frame)) { errors.push('NPC images must be copied into assets/npcs.'); continue; }
          if (townDirectory) {
            if (!checkedPaths.has(frame)) checkedPaths.set(frame,validateImage(townDirectory,frame));
            if (checkedPaths.get(frame)) errors.push(checkedPaths.get(frame));
          }
        }
      }
    }
  }
  if (bundled && !creations.has('morpheus')) creations.set('morpheus',{id:'morpheus',name:'Morpheus',gender:'man',age_group:'adult',skin_tone_group:'dark'});
  const npcs = Array.isArray(npcRecords) ? npcRecords : npcRecords?.npcs;
  if (!Array.isArray(npcs)) { errors.push('Invalid NPC placement list.'); return result(); }
  for (const npc of npcs) {
    if (!object(npc)) { errors.push('Invalid NPC placement record.'); continue; }
    const appearance = npc.appearance;
    if (!object(appearance)) { errors.push('NPC needs a saved appearance.'); continue; }
    // Legacy static flags are accepted for migration, not offered as a new mode.
    if (appearance.animation_type !== undefined && !['static','animated'].includes(appearance.animation_type)) errors.push('Invalid NPC animation setting.');
    if (!['random_static_asset','built_in','custom_creation'].includes(appearance.mode)) { errors.push('NPC needs a supported saved appearance.'); continue; }
    if (npc.actor_kind === 'npr' || npc.npc_role === 'npr') {
      if (appearance.mode === 'custom_creation' || appearance.npc_asset !== 'npr') errors.push('NPR must use robot artwork.');
      continue;
    }
    if (!GENDERS.includes(appearance.gender) || !AGES.includes(appearance.age_group) || !TONES.includes(appearance.skin_tone_group)) errors.push('NPC human appearance needs gender, age and skin pigmentation.');
    if (appearance.mode === 'custom_creation') {
      const creation = creations.get(appearance.template_id);
      if (!safeId(appearance.template_id) || appearance.npc_asset !== 'creation_'+appearance.template_id) errors.push('Invalid custom NPC creation reference.');
      if (!creation) { errors.push('Missing custom artwork for '+(npc.display_name || npc.id || 'NPC')); continue; }
      if (['gender','age_group','skin_tone_group'].some(field => appearance[field] !== creation[field])) errors.push('Custom artwork attributes changed. Reapply the creation to '+(npc.display_name || npc.id || 'NPC'));
    } else if (appearance.npc_asset !== `npc_${appearance.skin_tone_group}_${appearance.gender}_${appearance.age_group}`) errors.push('NPC artwork does not match its saved human attributes.');
  }
  return result();
}

module.exports = {validateNpcCreations, imageDimensions};
