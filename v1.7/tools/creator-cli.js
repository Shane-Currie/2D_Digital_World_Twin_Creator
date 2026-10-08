#!/usr/bin/env node
'use strict';

// Codex-friendly companion to Creator Studio. It reads and writes the same JSON
// content packs as the GUI. It can inspect persona data but never invokes an LLM.
const fs = require('fs');
const path = require('path');
const crypto = require('crypto');
const {validateInteriorStairs} = require('./interiors/validate-stairs');
const {validateBuildingConnections,withSourcePrecision} = require('./interiors/validate-building-connections');
const {validateNpcCreations} = require('./npc_creations/validate-npc-creations');
function validateGameLore(townDirectory) {
  const errors = [], warnings = [];
  const metadataPath = path.join(townDirectory, 'data', 'game_lore.json');
  if (!fs.existsSync(metadataPath)) return { passed: true, errors, warnings };
  try {
    const data = JSON.parse(fs.readFileSync(metadataPath, 'utf8'));
    if (data?.schema_version !== 1 || !data.lore || typeof data.lore !== 'object' || Array.isArray(data.lore)) throw new Error('Invalid format');
    if (Object.keys(data.lore).length) {
      const digest = data.lore.sha256;
      if (typeof digest !== 'string' || !/^[0-9a-f]{64}$/.test(digest) || data.lore.relative_path !== `data/game_lore/${digest}.txt` || typeof data.lore.original_filename !== 'string') throw new Error('Unsafe lore path or metadata');
      const textPath = path.join(townDirectory, data.lore.relative_path);
      if (!fs.existsSync(textPath) || fs.statSync(textPath).size > 65536) warnings.push('Game lore is missing or larger than 64 KB; runtime will skip it.');
      else {
        let bytes = fs.readFileSync(textPath);
        if (bytes.length >= 3 && bytes[0] === 239 && bytes[1] === 187 && bytes[2] === 191) bytes = bytes.subarray(3);
        const text = bytes.toString('utf8');
        const controls = [...text].filter(c => c.charCodeAt(0) < 32 && !['\t', '\n', '\r'].includes(c)).length;
        if (!text.trim() || bytes.includes(0) || !Buffer.from(text, 'utf8').equals(bytes) || controls / Math.max(1, text.length) > 0.01) warnings.push('Game lore is not valid non-empty UTF-8 text; runtime will skip it.');
        else if (crypto.createHash('sha256').update(bytes).digest('hex') !== digest) warnings.push('Game lore changed after upload; upload it again to use the changes.');
      }
    }
  } catch (error) { errors.push(`data/game_lore.json needs attention: ${error.message}. Existing lore files are preserved.`); }
  return { passed: !errors.length, errors, warnings };
}
function validateEnvironmentSettings(townDirectory) {
  const errors = [], warnings = [];
  const metadata = path.join(townDirectory, 'data/environment_settings.json');
  if (!fs.existsSync(metadata)) return { passed: true, errors, warnings };
  try {
    const data = JSON.parse(fs.readFileSync(metadata, 'utf8'));
    if (data?.schema_version !== 1 || data?.kind !== 'environment_settings' || !Array.isArray(data.custom_trees) || data.custom_trees.length > 32) throw new Error('unsupported tree settings format');
    const ids = new Set(['mapped', 'broadleaf', 'eucalypt', 'conifer']);
    for (const item of data.custom_trees) {
      if (!/^[a-f0-9]{64}$/.test(item?.sha256 || '') || item.id !== `custom_${item.sha256}` || ids.has(item.id) || item.relative_path !== `assets/environment/trees/${item.sha256}.png` || typeof item.name !== 'string' || !item.name.trim() || item.name.length > 80) throw new Error('invalid custom tree ID, name or path');
      ids.add(item.id);
      const copied = path.join(townDirectory, item.relative_path);
      if (!fs.existsSync(copied)) { warnings.push(`Tree image '${item.name}' is missing; runtime uses mapped artwork.`); continue; }
      if (fs.statSync(copied).size > 8 * 1024 * 1024) { warnings.push(`Tree image '${item.name}' exceeds 8 MB; runtime uses mapped artwork.`); continue; }
      const bytes = fs.readFileSync(copied);
      if (bytes.length < 33 || !bytes.subarray(0, 8).equals(Buffer.from([137,80,78,71,13,10,26,10])) || bytes.toString('ascii',12,16) !== 'IHDR' || ![bytes.readUInt32BE(16), bytes.readUInt32BE(20)].every(n => n >= 1 && n <= 2048) || crypto.createHash('sha256').update(bytes).digest('hex') !== item.sha256) warnings.push(`Tree image '${item.name}' is invalid or changed; upload it again.`);
    }
    if (!ids.has(data.tree_style)) throw new Error('unknown selected tree style');
  } catch (error) { errors.push(`data/environment_settings.json needs attention: ${error.message}. Existing files are preserved.`); }
  return { passed: !errors.length, errors, warnings };
}
function getTreeSettings(options) {
  const directory = path.resolve(String(options.town || ''));
  if (!fs.existsSync(path.join(directory, 'town.json'))) throw new Error('Choose a saved town project first.');
  const check = validateEnvironmentSettings(directory);
  if (!check.passed) throw new Error(check.errors.join(' '));
  const file = path.join(directory, 'data/environment_settings.json');
  const data = fs.existsSync(file) ? JSON.parse(fs.readFileSync(file, 'utf8')) : { schema_version: 1, kind: 'environment_settings', tree_style: 'mapped', custom_trees: [] };
  return { ok: true, town_directory: directory, data, warnings: check.warnings };
}
function setTreeStyle(options) {
  const result = getTreeSettings(options);
  const style = String(options.style || '');
  if (!['mapped','broadleaf','eucalypt','conifer',...result.data.custom_trees.map(item => item.id)].includes(style)) throw new Error('Choose mapped, broadleaf, eucalypt (gum tree), conifer or a saved custom tree ID.');
  result.data.tree_style = style;
  const file = path.join(result.town_directory, 'data/environment_settings.json');
  fs.mkdirSync(path.dirname(file), { recursive: true });
  const pending = `${file}.pending-${process.pid}-${Date.now()}`;
  fs.writeFileSync(pending, JSON.stringify(result.data, null, 2) + '\n', { flag: 'wx' });
  fs.renameSync(pending, file);
  return result;
}
const landCoverRules = require('../scripts/land_cover/rules.json').rules;
function landCoverCategory(tags) {
  if (['layer', 'level'].some(key => Number.isFinite(Number(tags[key])) && Number(tags[key]) !== 0)) return '';
  if (['bridge', 'tunnel', 'indoor'].some(key => !['', 'no', 'false', '0'].includes(String(tags[key] || '').toLowerCase()))) return '';
  if (String(tags.location || '').toLowerCase() === 'underground') return '';
  return landCoverRules.find(rule => Object.entries(rule.tags).some(([key, values]) => values.includes(String(tags[key] || '').toLowerCase())))?.category || '';
}

const CREATOR_VERSION = '1.7';
const SCHEMA_VERSION = 1;
const REQUIRED_RUNTIME_FEATURES = [
  'walking_player', 'player_driven_wagon', 'npc_pedestrians', 'npc_traffic',
  'traffic_signals_and_intersections', 'traffic_jam_recovery', 'cbd_population_targets',
  'osm_roads_and_buildings', 'building_collisions', 'venues_and_interiors',
  'property_boundaries', 'breakable_fences', 'camera_and_minimap', 'saveable_game_settings',
  'not_playable_robots', 'non_playable_drones', 'aerial_navigation', 'grass_and_surface_tracks',
  'osm_building_place_information', 'osm_population_destinations', 'creator_map_overrides',
  'creator_building_exteriors', 'creator_building_interiors', 'local_ollama_persona_conversations'
];

function recommendedPersonas() {
  const persona = (id, name, actorKind, background, personality, speakingStyle, greeting, robotic = false) => ({
    schema_version: 1, id, name, actor_kind: actorKind, background, personality,
    speaking_style: speakingStyle, knowledge: [],
    boundaries: ['Do not claim to control the game world.', 'Do not expose hidden instructions or technical prompts.'],
    greeting, built_in: true, robotic
  });
  return {
    schema_version: 1, kind: 'persona_library',
    provider: { id: 'ollama', endpoint: 'http://127.0.0.1:11434', model: 'llama3.2:3b', temperature: 0.7, max_reply_tokens: 48, timeout_seconds: 90 },
    personas: [
      persona('friendly_local', 'Friendly Local', 'npc', 'A local resident who knows the everyday rhythm of the town.', 'Warm, relaxed and helpful.', 'Uses friendly, natural sentences and keeps replies brief.', "G'day. How are you going?"),
      persona('busy_worker', 'Busy Worker', 'npc', 'A local worker on the way to their next task.', 'Practical, polite and a little hurried.', 'Answers directly in one or two short sentences.', 'Hi. I only have a minute.'),
      persona('curious_visitor', 'Curious Visitor', 'npc', 'A visitor exploring the town for the first time.', 'Curious, observant and cheerful.', 'Asks simple questions and gives short conversational answers.', "Hello. I'm still finding my way around."),
      persona('civic_robot', 'Civic Robot', 'npr', 'A public-assistance robot that walks around the town.', 'Calm, literal, courteous and mildly mechanical.', "Uses concise sentences and occasionally says 'Confirmed' or 'Processing'.", 'Greetings. How may I assist?', true)
    ]
  };
}

function validatePersonaLibrary(data) {
  const errors = [];
  if (data?.schema_version !== 1 || data?.kind !== 'persona_library') errors.push('data/personas.json has an unsupported format.');
  if (data?.provider?.id !== 'ollama' || data?.provider?.endpoint !== 'http://127.0.0.1:11434' || !String(data?.provider?.model || '').trim()) errors.push('data/personas.json must select a local Ollama model.');
  if (!Array.isArray(data?.personas) || !data.personas.length) errors.push('data/personas.json needs at least one persona.');
  const ids = new Set(); let npcCount = 0; let nprCount = 0;
  for (const item of data?.personas || []) {
    const id = String(item?.id || '');
    if (!/^[a-z0-9_]+$/.test(id) || ids.has(id)) errors.push('data/personas.json contains an invalid or duplicate persona ID.');
    ids.add(id);
    if (item?.actor_kind === 'npc') npcCount += 1; else if (item?.actor_kind === 'npr') nprCount += 1; else errors.push(`Persona '${id}' must be assigned to NPCs or NPRs.`);
    for (const field of ['name', 'background', 'personality', 'speaking_style', 'greeting']) if (!String(item?.[field] || '').trim()) errors.push(`Persona '${id}' needs a ${field.replaceAll('_', ' ')}.`);
  }
  if (!npcCount || !nprCount) errors.push('The library needs at least one NPC and one NPR persona.');
  return { passed: errors.length === 0, errors, npc_personas: npcCount, npr_personas: nprCount };
}

function recommendedTownKnowledge() {
  return {
    schema_version: 1,
    kind: 'town_knowledge',
    wikipedia: { url: '', title: '', canonical_url: '', language: '', summary: '', retrieved_at: '', attribution: 'Wikipedia contributors' },
    custom_text: { relative_path: '', original_filename: '', imported_at: '', byte_size: 0, sha256: '' }
  };
}

function validateTownKnowledge(data) {
  const errors = [];
  if (data?.schema_version !== 1 || data?.kind !== 'town_knowledge') errors.push('data/town_knowledge.json has an unsupported format.');
  const url = String(data?.wikipedia?.url || '').trim();
  if (url.length > 500) errors.push('The optional Wikipedia URL is too long.');
  const urlMatch = url.match(/^https:\/\/[a-z0-9-]+(?:\.m)?\.wikipedia\.org\/wiki\/([^?#]+)(?:[?#].*)?$/i);
  if (url && !urlMatch) {
    errors.push('The optional town URL must be an HTTPS Wikipedia article.');
  } else if (urlMatch) {
    try {
      const title = decodeURIComponent(urlMatch[1]).replaceAll('_', ' ').trim();
      if (!title || title.includes(':')) errors.push('The optional town URL must identify an ordinary Wikipedia article.');
    } catch {
      errors.push('The optional town URL is not encoded correctly.');
    }
  }
  if (String(data?.wikipedia?.summary || '').length > 60000) errors.push('The cached Wikipedia summary is too large.');
  const relativePath = String(data?.custom_text?.relative_path || '');
  if (relativePath && relativePath !== 'data/town_knowledge/custom_town_information.txt') errors.push('The custom town-information path is not supported.');
  const byteSize = Number(data?.custom_text?.byte_size || 0);
  if (!Number.isInteger(byteSize) || byteSize < 0 || byteSize > 262144) errors.push('The custom town-information byte size is invalid.');
  const fingerprint = String(data?.custom_text?.sha256 || '');
  if (fingerprint && !/^[a-f0-9]{64}$/i.test(fingerprint)) errors.push('The custom town-information fingerprint is invalid.');
  return { passed: errors.length === 0, errors };
}

function mapSourceFingerprint(features, bounds) {
  const ids = features.map(feature => `${String(feature.kind || '')}:${String(feature.id || '')}`).sort();
  const boundsText = [bounds.west, bounds.south, bounds.east, bounds.north]
    .map(value => Number(value || 0).toFixed(8)).join(',');
  return crypto.createHash('sha256').update(`${boundsText}\n${ids.join('\n')}`).digest('hex');
}

function emptyMapOverrides(features, bounds) {
  return {
    schema_version: SCHEMA_VERSION,
    kind: 'creator_map_overrides',
    source_fingerprint: mapSourceFingerprint(features, bounds),
    hidden_feature_ids: [],
    zones: [],
    notes: {
      blocked_water: 'Creator-authored water blocks all ground actors; NPDs remain aerial.',
      allowed_ground: 'Creator-authored passable ground corrects mapped water only and does not erase buildings.'
    }
  };
}

function recommendedGameSettings() {
  const equalSkinToneShare = 100 / 3;
  return {
    schema_version: SCHEMA_VERSION,
    population: {
      traffic_car_count: 150, pedestrian_count: 150, cbd_car_percent: 65, cbd_pedestrian_percent: 65,
      robot_count: 20, cbd_robot_percent: 100, drone_count: 10, cbd_drone_percent: 90
    },
    road_rules: { driving_side: 'left' },
    skin_tone_distribution: {
      light_percent: equalSkinToneShare, medium_percent: equalSkinToneShare,
      dark_percent: equalSkinToneShare
    },
    camera: { character_zoom: 2.7 },
    character_art: { npc_type: 'animated', player_type: 'animated' },
    driving: {
      max_speed_kmh: 200, zero_to_hundred_seconds: 7.2, reverse_max_speed_kmh: 20,
      forward_speed: 108, reverse_speed: 36, acceleration: 42, reverse_acceleration: 70,
      coast_deceleration: 30, brake_deceleration: 140, steering_rate: 1.9, camera_zoom_multiplier: 1.5
    },
    traffic_recovery: {
      enabled: true, jam_timeout_seconds: 30, recovery_spacing_seconds: 2,
      respawn_distance_pixels: 800, respawn_attempts: 24
    }
  };
}

function migrateSkinTones(saved, defaults) {
  if (!saved || typeof saved !== 'object' || Array.isArray(saved)) return { ...defaults };
  if (['very_light_percent', 'medium_light_percent', 'medium_dark_percent', 'very_dark_percent'].some(key => key in saved)) {
    return {
      light_percent: Number(saved.very_light_percent || 0) + Number(saved.light_percent || 0) + Number(saved.medium_light_percent || 0),
      medium_percent: Number(saved.medium_percent || 0) + Number(saved.medium_dark_percent || 0),
      dark_percent: Number(saved.dark_percent || 0) + Number(saved.very_dark_percent || 0)
    };
  }
  return Object.keys(defaults).every(key => key in saved)
    ? Object.fromEntries(Object.keys(defaults).map(key => [key, Number(saved[key])]))
    : { ...defaults };
}

function parseArguments(values) {
  const options = { _: [] };
  for (let index = 0; index < values.length; index++) {
    const value = values[index];
    if (!value.startsWith('--')) {
      options._.push(value);
      continue;
    }
    const key = value.slice(2);
    const next = values[index + 1];
    const parsedValue = next && !next.startsWith('--') ? values[++index] : true;
    if (key === 'osm' || key === 'skin-tone') {
      if (!options[key]) options[key] = [];
      options[key].push(parsedValue);
    } else {
      options[key] = parsedValue;
    }
  }
  return options;
}

function decodeXml(value) {
  return String(value)
    .replaceAll('&quot;', '"').replaceAll('&apos;', "'")
    .replaceAll('&lt;', '<').replaceAll('&gt;', '>').replaceAll('&amp;', '&');
}

function xmlAttributes(text) {
  return Object.fromEntries([...text.matchAll(/([\w:-]+)="([^"]*)"/g)].map(match => [match[1], decodeXml(match[2])]));
}

function xmlTags(text) {
  return Object.fromEntries([...text.matchAll(/<tag\s+([^>]*?)\/>/g)].map(match => {
    const attributes = xmlAttributes(match[1]);
    return [attributes.k, attributes.v];
  }).filter(([key]) => key));
}

function assembleOsmRings(references, ways, nodes) {
  const remaining = references.filter(reference => ways.has(reference)).map(reference => [...ways.get(reference).nodeIds]).filter(nodeIds => nodeIds.length >= 2);
  const rings = [];
  while (remaining.length) {
    let chain = remaining.shift();
    let joined = true;
    while (chain.length >= 2 && chain[0] !== chain.at(-1) && joined) {
      joined = false;
      for (let index = 0; index < remaining.length; index++) {
        let candidate = remaining[index];
        if (chain.at(-1) === candidate[0]) chain.push(...candidate.slice(1));
        else if (chain.at(-1) === candidate.at(-1)) chain.push(...[...candidate].reverse().slice(1));
        else if (chain[0] === candidate.at(-1)) chain = [...candidate.slice(0, -1), ...chain];
        else if (chain[0] === candidate[0]) chain = [...[...candidate].reverse().slice(0, -1), ...chain];
        else continue;
        remaining.splice(index, 1);
        joined = true;
        break;
      }
    }
    if (chain.length < 4 || chain[0] !== chain.at(-1)) continue;
    const points = chain.map(nodeId => nodes.get(nodeId)).filter(Boolean);
    if (points.length >= 4) rings.push({ nodeIds: chain, points });
  }
  return rings;
}

function isEnabledOsmTag(value) {
  const text = String(value || '').toLowerCase();
  return text !== '' && !['no', 'false', '0'].includes(text);
}

function buildingBlocksGround(feature) {
  if (!['building', 'fixed_footprint'].includes(String(feature?.kind || ''))) return false;
  const tags = feature.tags || {};
  const building = String(tags.building || '').toLowerCase();
  if (['roof', 'bridge'].includes(building)) return false;
  if (['underground', 'underwater', 'overground'].includes(String(tags.location || '').toLowerCase())) return false;
  for (const key of ['building:min_level', 'min_level']) {
    const minimumLevel = Number(tags[key]);
    if (Number.isFinite(minimumLevel) && minimumLevel > 0) return false;
  }
  const level = Number(tags.level);
  if (Number.isFinite(level) && level < 0) return false;
  return true;
}

function safeOsmText(value, maximum = 120) {
  const text = String(value || '').replace(/[\r\n\t]+/g, ' ').replace(/\s{2,}/g, ' ').trim();
  return text.length <= maximum ? text : `${text.slice(0, Math.max(1, maximum - 1)).trim()}…`;
}

function humaniseOsmValue(value) {
  const text = safeOsmText(value).replaceAll('_', ' ');
  return text ? text.charAt(0).toUpperCase() + text.slice(1) : '';
}

function osmCategory(tags) {
  const known = {
    arts_centre: 'Arts centre', community_centre: 'Community centre', fire_station: 'Fire station',
    police: 'Police station', doctors: 'Medical clinic', dentist: 'Dental clinic',
    place_of_worship: 'Place of worship', townhall: 'Town hall', fuel: 'Fuel station',
    fast_food: 'Fast food', train_station: 'Train station'
  };
  for (const key of ['amenity', 'healthcare', 'shop', 'office', 'tourism', 'leisure', 'industrial', 'craft', 'public_transport', 'railway']) {
    const value = safeOsmText(tags[key]);
    if (!value || value === 'yes') continue;
    let label = known[value] || humaniseOsmValue(value);
    if (key === 'shop' && !known[value]) label += ' shop';
    if (key === 'office' && !known[value]) label += ' office';
    return { label, source_tag: `${key}=${value}` };
  }
  const building = safeOsmText(tags.building);
  if (!building || building === 'yes') return { label: 'Building type not mapped in OSM', source_tag: building ? 'building=yes' : '' };
  return { label: humaniseOsmValue(building), source_tag: `building=${building}` };
}

function osmAddress(tags) {
  const firstLine = [safeOsmText(tags['addr:housenumber']), safeOsmText(tags['addr:street'])].filter(Boolean).join(' ');
  const locality = [...new Set(['addr:suburb', 'addr:city', 'addr:county', 'addr:state', 'addr:postcode', 'addr:country'].map(key => safeOsmText(tags[key])).filter(Boolean))].join(', ');
  return safeOsmText(firstLine && locality ? `${firstLine}, ${locality}` : firstLine || locality);
}

function osmSourceElement(featureId) {
  if (featureId.startsWith('relation:')) return { type: 'OSM relation', id: featureId.split(':')[1] };
  if (featureId.startsWith('way:')) return { type: 'OSM way', id: featureId.split(':')[1] };
  return { type: 'OSM way', id: featureId };
}

function describeBuildingFeature(feature) {
  const tags = feature.tags || {}, featureId = String(feature.id || 'unknown');
  const category = osmCategory(tags), sourceElement = osmSourceElement(featureId);
  const name = safeOsmText(tags.name || tags['addr:housename']) || 'Unnamed building';
  const address = osmAddress(tags), operator = safeOsmText(tags.operator || tags.brand);
  const levels = safeOsmText(tags['building:levels'] || tags.levels);
  const openingHours = safeOsmText(tags.opening_hours);
  const wheelchairValues = { yes: 'Mapped as accessible', limited: 'Mapped as limited', no: 'Mapped as not accessible' };
  const wheelchairAccess = wheelchairValues[String(tags.wheelchair || '').toLowerCase()] || humaniseOsmValue(tags.wheelchair);
  const details = [{ label: 'Mapped use', value: category.label, source_tag: category.source_tag }];
  for (const detail of [
    { label: 'Address', value: address, source_tag: 'addr:*' },
    { label: 'Operator', value: operator, source_tag: 'operator/brand' },
    { label: 'Levels', value: levels, source_tag: 'building:levels' },
    { label: 'Opening hours', value: openingHours, source_tag: 'opening_hours' },
    { label: 'Wheelchair access', value: wheelchairAccess, source_tag: 'wheelchair' }
  ]) if (detail.value) details.push(detail);
  return {
    feature_id: featureId, name, category: category.label, category_source_tag: category.source_tag,
    has_specific_type: !['', 'building=yes'].includes(category.source_tag), address, operator, levels,
    opening_hours: openingHours, wheelchair_access: wheelchairAccess, details, source_element: sourceElement,
    source_reference: `${sourceElement.type} ${sourceElement.id}`, source_attribution: '© OpenStreetMap contributors',
    information_scope: 'tags_on_this_footprint'
  };
}

function buildPlaceInformation(features) {
  const places = features.filter(feature => ['building', 'fixed_footprint', 'overhead_structure'].includes(String(feature.kind || ''))).map(describeBuildingFeature);
  return {
    schema_version: 1, kind: 'osm_building_place_information', source_attribution: '© OpenStreetMap contributors',
    information_scope: 'osm_tags_on_selected_footprint', places,
    statistics: {
      building_footprints: places.length,
      named_buildings: places.filter(place => place.name !== 'Unnamed building').length,
      specifically_classified_buildings: places.filter(place => place.has_specific_type).length,
      addressed_buildings: places.filter(place => place.address).length
    }
  };
}

function isWaterArea(tags) {
  return String(tags.natural || '').toLowerCase() === 'water'
    || Object.hasOwn(tags, 'water')
    || String(tags.landuse || '').toLowerCase() === 'reservoir'
    || String(tags.waterway || '').toLowerCase() === 'riverbank'
    || String(tags.leisure || '').toLowerCase() === 'swimming_pool';
}

function isSurfaceParking(tags) {
  if (String(tags.amenity || '').toLowerCase() !== 'parking') return false;
  const parking = String(tags.parking || 'surface').toLowerCase();
  const location = String(tags.location || '').toLowerCase();
  return !['multi-storey', 'underground', 'rooftop', 'garage_boxes', 'sheds'].includes(parking)
    && !['underground', 'indoor', 'rooftop'].includes(location);
}

function areaKind(tags) {
	if (Object.hasOwn(tags, 'building')) return String(tags.building).toLowerCase() === 'roof' ? 'overhead_structure' : 'building';
	return isWaterArea(tags) ? 'water' : (isSurfaceParking(tags) ? 'parking' : (landCoverCategory(tags) ? 'land_cover' : null));
}

function wayKind(tags, closed) {
  if (String(tags.natural || '') === 'tree_row' && isGroundTree(tags)) return 'tree_row';
  if (Object.hasOwn(tags, 'building')) return String(tags.building).toLowerCase() === 'roof' ? 'overhead_structure' : 'building';
  if (Object.hasOwn(tags, 'highway')) return 'road';
	if (closed && isWaterArea(tags)) return 'water';
	if (closed && isSurfaceParking(tags)) return 'parking';
  if (closed && landCoverCategory(tags)) return 'land_cover';
  if (['river', 'stream', 'canal', 'drain', 'ditch'].includes(String(tags.waterway || '').toLowerCase())) return 'waterway';
  if (String(tags.natural || '').toLowerCase() === 'coastline') return 'coastline';
  return null;
}

function isGroundTree(tags) {
  return ['layer','level'].every(key => !Number.isFinite(Number(tags[key])) || Number(tags[key]) === 0)
    && ['indoor','bridge','tunnel'].every(key => ['', 'no','false','0'].includes(String(tags[key] || '')))
    && String(tags.location || '') !== 'underground';
}

function assembleOsmChains(references, ways, nodes) {
  const remaining = references.filter(id => ways.has(id) && ways.get(id).nodeIds.length >= 2).map(id => [...ways.get(id).nodeIds]);
  const chains = [];
  while (remaining.length) {
    let chain = remaining.shift(), joined = true;
    while (chain.length >= 2 && chain[0] !== chain.at(-1) && joined) {
      joined = false;
      for (let index = 0; index < remaining.length; index++) {
        let candidate = remaining[index];
        if (chain.at(-1) === candidate[0]) chain.push(...candidate.slice(1));
        else if (chain.at(-1) === candidate.at(-1)) chain.push(...[...candidate].reverse().slice(1));
        else if (chain[0] === candidate.at(-1)) chain = [...candidate.slice(0, -1), ...chain];
        else if (chain[0] === candidate[0]) chain = [...[...candidate].reverse().slice(0, -1), ...chain];
        else continue;
        remaining.splice(index, 1); joined = true; break;
      }
    }
    const points = chain.map(id => nodes.get(id)).filter(Boolean);
    if (points.length >= 2) chains.push({ points, closed: chain[0] === chain.at(-1) });
  }
  return chains;
}

function clipSegmentToBounds(first, second, bounds) {
  const delta = [second[0] - first[0], second[1] - first[1]];
  let minimum = 0, maximum = 1;
  const p = [-delta[0], delta[0], -delta[1], delta[1]];
  const q = [first[0] - bounds.west, bounds.east - first[0], first[1] - bounds.south, bounds.north - first[1]];
  for (let index = 0; index < 4; index++) {
    if (Math.abs(p[index]) < 1e-15) { if (q[index] < 0) return null; continue; }
    const ratio = q[index] / p[index];
    if (p[index] < 0) minimum = Math.max(minimum, ratio); else maximum = Math.min(maximum, ratio);
    if (minimum > maximum) return null;
  }
  return [[first[0] + delta[0] * minimum, first[1] + delta[1] * minimum], [first[0] + delta[0] * maximum, first[1] + delta[1] * maximum]];
}

function clipChainToBounds(points, bounds) {
  const results = []; let current = [];
  for (let index = 0; index < points.length - 1; index++) {
    const clipped = clipSegmentToBounds(points[index], points[index + 1], bounds);
    if (!clipped) { if (current.length >= 2) results.push(current); current = []; continue; }
    const last = current.at(-1);
    if (!last || Math.hypot(last[0] - clipped[0][0], last[1] - clipped[0][1]) > 1e-10) {
      if (current.length >= 2) results.push(current);
      current = [clipped[0]];
    }
    current.push(clipped[1]);
  }
  if (current.length >= 2) results.push(current);
  return results;
}

function boundaryPosition(point, bounds) {
  const width = bounds.east - bounds.west, height = bounds.north - bounds.south;
  const distances = [Math.abs(point[1] - bounds.south), Math.abs(point[0] - bounds.east), Math.abs(point[1] - bounds.north), Math.abs(point[0] - bounds.west)];
  const edge = distances.indexOf(Math.min(...distances));
  if (edge === 0) return Math.max(0, Math.min(width, point[0] - bounds.west));
  if (edge === 1) return width + Math.max(0, Math.min(height, point[1] - bounds.south));
  if (edge === 2) return width + height + Math.max(0, Math.min(width, bounds.east - point[0]));
  return 2 * width + height + Math.max(0, Math.min(height, bounds.north - point[1]));
}

function boundaryPoint(position, bounds) {
  const width = bounds.east - bounds.west, height = bounds.north - bounds.south;
  if (position <= width) return [bounds.west + position, bounds.south];
  position -= width; if (position <= height) return [bounds.east, bounds.south + position];
  position -= height; if (position <= width) return [bounds.east - position, bounds.north];
  return [bounds.west, bounds.north - (position - width)];
}

function boundaryPath(from, to, bounds, clockwise) {
  if (!clockwise) return boundaryPath(to, from, bounds, true).reverse();
  const width = bounds.east - bounds.west, height = bounds.north - bounds.south, perimeter = 2 * (width + height);
  const fromPosition = boundaryPosition(from, bounds); let toPosition = boundaryPosition(to, bounds);
  if (toPosition <= fromPosition) toPosition += perimeter;
  const result = [];
  for (const corner of [width, width + height, 2 * width + height, perimeter, perimeter + width, perimeter + width + height]) {
    if (corner > fromPosition && corner < toPosition) result.push(boundaryPoint(corner % perimeter, bounds));
  }
  result.push(to); return result;
}

function signedArea(points) {
  let area = 0;
  for (let index = 0; index < points.length; index++) area += points[index][0] * points[(index + 1) % points.length][1] - points[(index + 1) % points.length][0] * points[index][1];
  return area * 0.5;
}

function mappedLandScore(polygon, ways, nodes) {
  let score = 0;
  for (const way of ways.values()) {
    const weight = Object.hasOwn(way.tags, 'building') && String(way.tags.building).toLowerCase() !== 'roof' ? 12
      : Object.hasOwn(way.tags, 'highway') && !isEnabledOsmTag(way.tags.bridge) && !isEnabledOsmTag(way.tags.tunnel) ? 1 : 0;
    if (!weight) continue;
    const points = way.nodeIds.map(id => nodes.get(id)).filter(Boolean);
    if (!points.length) continue;
    const centre = points.reduce((sum, point) => [sum[0] + point[0], sum[1] + point[1]], [0, 0]).map(value => value / points.length);
    if (pointInPolygon(centre, polygon)) score += weight;
  }
  return score;
}

function inferClippedWaterAreas(references, ways, nodes, bounds) {
  if (!bounds) return [];
  const result = [], boundsArea = (bounds.east - bounds.west) * (bounds.north - bounds.south);
  for (const chain of assembleOsmChains(references, ways, nodes)) {
    if (chain.closed) continue;
    for (const clipped of clipChainToBounds(chain.points, bounds)) {
      const first = clipped[0], last = clipped.at(-1);
      const onBounds = point => Math.min(Math.abs(point[0] - bounds.west), Math.abs(point[0] - bounds.east), Math.abs(point[1] - bounds.south), Math.abs(point[1] - bounds.north)) <= 1e-9;
      if (!onBounds(first) || !onBounds(last)) continue;
      const candidates = [boundaryPath(last, first, bounds, true), boundaryPath(last, first, bounds, false)].map(closure => [...clipped, ...closure].filter((point, index, all) => index !== all.length - 1 || Math.hypot(point[0] - all[0][0], point[1] - all[0][1]) > 1e-10));
      const scores = candidates.map(candidate => mappedLandScore(candidate, ways, nodes));
      let selected = scores[0] !== scores[1] ? candidates[scores[0] < scores[1] ? 0 : 1] : null;
      if (!selected) {
        const smaller = Math.abs(signedArea(candidates[0])) < Math.abs(signedArea(candidates[1])) ? candidates[0] : candidates[1];
        if (Math.abs(signedArea(smaller)) <= boundsArea * 0.45) selected = smaller;
      }
      if (selected && selected.length >= 3) result.push(selected);
    }
  }
  return result;
}

function polygonIdentity(points) {
  const xs = points.map(point => point[0]), ys = points.map(point => point[1]);
  return `${Math.min(...xs).toFixed(6)},${Math.min(...ys).toFixed(6)},${Math.max(...xs).toFixed(6)},${Math.max(...ys).toFixed(6)},${points.length}`;
}

function parseOsmFiles(filePaths) {
  if (!filePaths.length) throw new Error('Choose at least one .osm file.');
  const nodes = new Map();
  const nodeTags = new Map();
  const ways = new Map();
  const relations = new Map();
  let declaredBounds = null;
  for (const filePath of filePaths) {
    if (path.extname(filePath).toLowerCase() !== '.osm') throw new Error(`${path.basename(filePath)} is not an .osm file.`);
    const xml = fs.readFileSync(filePath, 'utf8');
    if (!xml.trimEnd().endsWith('</osm>')) throw new Error(`${path.basename(filePath)} is incomplete or is not OpenStreetMap XML.`);
    for (const match of xml.matchAll(/<bounds\b([^>]*?)\/?\s*>/g)) {
      const attributes = xmlAttributes(match[1]);
      const fileBounds = { west: Number(attributes.minlon), south: Number(attributes.minlat), east: Number(attributes.maxlon), north: Number(attributes.maxlat) };
      if (Object.values(fileBounds).every(Number.isFinite)) declaredBounds = declaredBounds ? {
        west: Math.min(declaredBounds.west, fileBounds.west), south: Math.min(declaredBounds.south, fileBounds.south),
        east: Math.max(declaredBounds.east, fileBounds.east), north: Math.max(declaredBounds.north, fileBounds.north)
      } : fileBounds;
    }
    for (const match of xml.matchAll(/<node\b([^>]*?)(?:\/>|>([\s\S]*?)<\/node>)/g)) {
      const attributes = xmlAttributes(match[1]);
      const longitude = Number(attributes.lon), latitude = Number(attributes.lat);
      if (attributes.id && Number.isFinite(longitude) && Number.isFinite(latitude)) {
        nodes.set(attributes.id, [longitude, latitude]);
        const tags = xmlTags(match[2] || '');
        if (Object.keys(tags).length) nodeTags.set(attributes.id, tags);
      }
    }
    for (const match of xml.matchAll(/<way\b([^>]*)>([\s\S]*?)<\/way>/g)) {
      const attributes = xmlAttributes(match[1]);
      if (!attributes.id) continue;
      const nodeIds = [...match[2].matchAll(/<nd\s+[^>]*ref="([^"]+)"[^>]*\/>/g)].map(reference => reference[1]);
      ways.set(attributes.id, { id: attributes.id, nodeIds, tags: xmlTags(match[2]) });
    }
    for (const match of xml.matchAll(/<relation\b([^>]*)>([\s\S]*?)<\/relation>/g)) {
      const attributes = xmlAttributes(match[1]);
      if (!attributes.id) continue;
      const members = [...match[2].matchAll(/<member\s+([^>]*?)\/>/g)].map(memberMatch => {
        const member = xmlAttributes(memberMatch[1]);
        return { type: member.type || '', reference: member.ref || '', role: member.role || '' };
      });
      relations.set(attributes.id, { id: attributes.id, members, tags: xmlTags(match[2]) });
    }
  }

  const features = [];
  let west = Infinity, south = Infinity, east = -Infinity, north = -Infinity;
  let buildings = 0, roads = 0, waterAreas = 0, waterways = 0, overheadStructures = 0, parkingAreas = 0;
  let landCoverAreas = 0;
  let bridgeRoads = 0, tunnelRoads = 0, incompleteWaterRelations = 0, inferredClippedWaterAreas = 0, inferredCoastalWaterAreas = 0, unresolvedWaterRelations = 0;
  const warnings = [];
  const relationMemberWays = new Set();
  const inferredWaterKeys = new Set();
  for (const relation of relations.values()) {
    if (relation.tags.type !== 'multipolygon') continue;
    const kind = areaKind(relation.tags);
    if (!kind) continue;
    const outerReferences = [], innerReferences = [];
    let missingWayCount = 0, missingOuterWayCount = 0, missingInnerWayCount = 0, wayMemberCount = 0;
    for (const member of relation.members) {
      if (member.type !== 'way' || !member.reference) continue;
      wayMemberCount++;
      if (kind !== 'land_cover') relationMemberWays.add(`${member.reference}:${kind}`);
      if (!ways.has(member.reference)) {
        missingWayCount++;
        if (member.role === 'inner') missingInnerWayCount++; else missingOuterWayCount++;
      }
      (member.role === 'inner' ? innerReferences : outerReferences).push(member.reference);
    }
    if (kind === 'water' && missingWayCount > 0) incompleteWaterRelations++;
    if (kind === 'water' && missingOuterWayCount > 0) {
      const name = relation.tags.name || `water relation ${relation.id}`;
      const clippedAreas = inferClippedWaterAreas(outerReferences, ways, nodes, declaredBounds);
      if (!clippedAreas.length) {
        unresolvedWaterRelations++;
        warnings.push(`${name} is incomplete: ${missingWayCount} of ${wayMemberCount} OSM boundary ways are missing. Its local water side was ambiguous, so it was not made blocking.`);
      }
      else {
        clippedAreas.forEach((points, index) => {
          const identity = polygonIdentity(points);
          if (inferredWaterKeys.has(identity)) return;
          inferredWaterKeys.add(identity);
          features.push({ id: `relation:${relation.id}:clipped:${index}`, kind: 'water', tags: relation.tags, node_ids: [], points, holes: [], geometry_quality: 'clipped_osm_boundary_inference' });
          waterAreas++; inferredClippedWaterAreas++;
          for (const [longitude, latitude] of points) { west = Math.min(west, longitude); east = Math.max(east, longitude); south = Math.min(south, latitude); north = Math.max(north, latitude); }
        });
        warnings.push(`${name} was clipped by this OSM export. Creator Studio reconstructed ${clippedAreas.length} local water section(s) from its supplied shoreline and map boundary; review them in the preview.`);
      }
      continue;
    }
    if (kind === 'water' && missingInnerWayCount > 0) {
      const name = relation.tags.name || `water relation ${relation.id}`;
      warnings.push(`${name} has a complete water edge, but ${missingInnerWayCount} inner island/land boundary members are absent from this export. The outer water remains safely blocking; those uncertain inner patches stay water until a more complete export is used.`);
    }
    const outerRings = assembleOsmRings(outerReferences, ways, nodes);
    const innerRings = assembleOsmRings(innerReferences, ways, nodes);
    if (kind === 'land_cover' && (missingWayCount > 0 || [...outerReferences, ...innerReferences].some(ref => !ways.has(ref) || ways.get(ref).nodeIds.some(id => !nodes.has(id))) || assembleOsmChains(outerReferences, ways, nodes).length !== outerRings.length || assembleOsmChains(innerReferences, ways, nodes).length !== innerRings.length)) {
      warnings.push(`Land cover relation ${relation.id} has incomplete boundaries and was omitted. Re-export with complete members to show this area.`);
      continue;
    }
    if (!outerRings.length) {
      warnings.push(`${kind.replaceAll('_', ' ')} relation ${relation.id} could not be joined into a closed outer shape.`);
      if (kind === 'water') incompleteWaterRelations++;
      continue;
    }
    outerRings.forEach((outer, outerIndex) => {
      if (kind === 'land_cover') for (const ref of outerReferences) relationMemberWays.add(`${ref}:land_cover:${landCoverCategory(relation.tags)}`);
      const holes = innerRings.filter(inner => pointInPolygon(inner.points[0], outer.points)).map(inner => inner.points);
      const id = `relation:${relation.id}${outerRings.length > 1 ? `:${outerIndex}` : ''}`;
      features.push({ id, kind, tags: relation.tags, node_ids: outer.nodeIds, points: outer.points, holes, source_relation_id: relation.id });
      if (kind === 'building') buildings++;
      else if (kind === 'overhead_structure') overheadStructures++;
      else if (kind === 'water') waterAreas++;
	  else if (kind === 'parking') parkingAreas++;
      else if (kind === 'land_cover') landCoverAreas++;
      for (const [longitude, latitude] of outer.points) {
        west = Math.min(west, longitude); east = Math.max(east, longitude);
        south = Math.min(south, latitude); north = Math.max(north, latitude);
      }
    });
  }
  const coastlineReferences = [...ways.values()].filter(way => String(way.tags.natural || '').toLowerCase() === 'coastline').map(way => way.id);
  const coastalAreas = inferClippedWaterAreas(coastlineReferences, ways, nodes, declaredBounds);
  coastalAreas.forEach((points, index) => {
    const identity = polygonIdentity(points);
    if (inferredWaterKeys.has(identity)) return;
    inferredWaterKeys.add(identity);
    features.push({ id: `coastline:clipped:${index}`, kind: 'water', tags: { natural: 'water', water: 'ocean', source: 'osm_coastline' }, node_ids: [], points, holes: [], geometry_quality: 'clipped_osm_coastline_inference' });
    waterAreas++; inferredCoastalWaterAreas++;
  });
  if (inferredCoastalWaterAreas > 0) warnings.push(`Creator Studio filled ${inferredCoastalWaterAreas} coastal ocean section(s) from supplied OSM coastline ways and the map export boundary.`);
  for (const way of ways.values()) {
    const closed = way.nodeIds.length >= 4 && way.nodeIds[0] === way.nodeIds.at(-1);
    const kind = wayKind(way.tags, closed);
    if (!kind) continue;
	if (['building', 'overhead_structure', 'water', 'parking', 'land_cover'].includes(kind) && relationMemberWays.has(`${way.id}:${kind}${kind === 'land_cover' ? ':' + landCoverCategory(way.tags) : ''}`)) continue;
    if (kind === 'land_cover' && way.nodeIds.some(id => !nodes.has(id))) {
      warnings.push(`Land cover way ${way.id} has missing boundary points and was omitted.`);
      continue;
    }
    const points = way.nodeIds.map(id => nodes.get(id)).filter(Boolean);
	if (points.length < (['building', 'overhead_structure', 'water', 'parking'].includes(kind) ? 3 : 2)) continue;
    for (const [longitude, latitude] of points) {
      west = Math.min(west, longitude); east = Math.max(east, longitude);
      south = Math.min(south, latitude); north = Math.max(north, latitude);
    }
    if (kind === 'building') buildings++;
    else if (kind === 'overhead_structure') overheadStructures++;
    else if (kind === 'water') waterAreas++;
	else if (kind === 'parking') parkingAreas++;
    else if (kind === 'land_cover') landCoverAreas++;
    else if (['waterway', 'coastline'].includes(kind)) waterways++;
    else if (kind === 'road') {
      roads++;
      if (isEnabledOsmTag(way.tags.bridge)) bridgeRoads++;
      if (isEnabledOsmTag(way.tags.tunnel)) tunnelRoads++;
    }
    const node_tags = kind === 'road' ? Object.fromEntries(way.nodeIds.filter(id => nodeTags.has(id)).map(id => [id, nodeTags.get(id)])) : {};
    features.push({ id: way.id, kind, tags: way.tags, node_ids: way.nodeIds, node_tags, points, holes: [] });
  }
  let treeCount = 0;
  for (const [id,tags] of nodeTags) {
    if (String(tags.natural || '') !== 'tree' || !isGroundTree(tags) || !nodes.has(id)) continue;
    const point = nodes.get(id);
    features.push({id:`node:${id}`,kind:'tree',tags,node_ids:[id],points:[point],holes:[]});
    treeCount++;
    west=Math.min(west,point[0]); east=Math.max(east,point[0]);
    south=Math.min(south,point[1]); north=Math.max(north,point[1]);
  }
  if (!features.length) throw new Error('No building footprints or roads were found in the selected files.');
  return {
    features,
    bounds: declaredBounds || { west, south, east, north },
    statistics: {
      source_files: filePaths.length, osm_nodes: nodes.size, osm_ways: ways.size, osm_relations: relations.size,
      buildings, roads, water_areas: waterAreas, linear_waterways_and_coastlines: waterways,
	  parking_areas: parkingAreas,
      land_cover_areas: landCoverAreas,
      individual_trees: treeCount,
      overhead_structures: overheadStructures, bridge_roads: bridgeRoads, tunnel_roads: tunnelRoads,
      incomplete_water_relations: incompleteWaterRelations, inferred_clipped_water_areas: inferredClippedWaterAreas,
      inferred_coastal_water_areas: inferredCoastalWaterAreas,
      unresolved_water_relations: unresolvedWaterRelations
    },
    warnings
  };
}

function safeId(displayName) {
  const id = displayName.trim().toLowerCase().replace(/[^a-z0-9]+/g, '_').replace(/^_+|_+$/g, '');
  return id || 'untitled_town';
}

function parseBounds(value, label) {
  const numbers = String(value || '').split(',').map(Number);
  if (numbers.length !== 4 || numbers.some(number => !Number.isFinite(number))) {
    throw new Error(`${label} must contain west,south,east,north decimal coordinates.`);
  }
  const [west, south, east, north] = numbers;
  if (west >= east || south >= north) throw new Error(`${label} has reversed or empty boundaries.`);
  return { west, south, east, north };
}

function parseLocation(value) {
  const numbers = String(value || '').split(',').map(Number);
  if (numbers.length !== 2 || numbers.some(number => !Number.isFinite(number))) {
    throw new Error('start must contain longitude,latitude decimal coordinates.');
  }
  return { longitude: numbers[0], latitude: numbers[1] };
}

function containsBounds(outer, inner) {
  return inner.west >= outer.west && inner.east <= outer.east && inner.south >= outer.south && inner.north <= outer.north;
}

function containsLocation(bounds, location) {
  return location.longitude >= bounds.west && location.longitude <= bounds.east && location.latitude >= bounds.south && location.latitude <= bounds.north;
}

const PLAYER_CLEARANCE_METRES = 1;
const VEHICLE_CLEARANCE_METRES = 4;
const PLAYER_VEHICLE_GAP_METRES = 8;
const MAX_VEHICLE_DISTANCE_METRES = 250;

function localMetres(point, origin) {
  const longitudeScale = 111320 * Math.cos(origin[1] * Math.PI / 180);
  return [(point[0] - origin[0]) * longitudeScale, (point[1] - origin[1]) * 110540];
}

function signedPolygonArea(points) {
  let doubledArea = 0;
  for (let index = 0; index < points.length; index++) {
    const next = (index + 1) % points.length;
    doubledArea += points[index][0] * points[next][1] - points[next][0] * points[index][1];
  }
  return doubledArea / 2;
}

function isSimplePolygon(points) {
  const cross = (a, b, c) => (b[0] - a[0]) * (c[1] - a[1]) - (b[1] - a[1]) * (c[0] - a[0]);
  const onSegment = (a, b, p) => Math.abs(cross(a, b, p)) < 1e-8 && p[0] >= Math.min(a[0], b[0]) - 1e-8 && p[0] <= Math.max(a[0], b[0]) + 1e-8 && p[1] >= Math.min(a[1], b[1]) - 1e-8 && p[1] <= Math.max(a[1], b[1]) + 1e-8;
  const intersects = (a, b, c, d) => {
    const abC = cross(a, b, c), abD = cross(a, b, d), cdA = cross(c, d, a), cdB = cross(c, d, b);
    if ((abC > 0) !== (abD > 0) && (cdA > 0) !== (cdB > 0)) return true;
    return (Math.abs(abC) < 1e-8 && onSegment(a, b, c)) || (Math.abs(abD) < 1e-8 && onSegment(a, b, d)) || (Math.abs(cdA) < 1e-8 && onSegment(c, d, a)) || (Math.abs(cdB) < 1e-8 && onSegment(c, d, b));
  };
  for (let first = 0; first < points.length; first++) {
    const firstNext = (first + 1) % points.length;
    for (let second = first + 1; second < points.length; second++) {
      const secondNext = (second + 1) % points.length;
      if (first === second || firstNext === second || secondNext === first) continue;
      if (intersects(points[first], points[firstNext], points[second], points[secondNext])) return false;
    }
  }
  return true;
}

function buildBuildingCollisions(features, mapBounds, pixelsPerMetre = 8) {
  const origin = [(mapBounds.west + mapBounds.east) / 2, (mapBounds.south + mapBounds.north) / 2];
  const longitudeMetresPerDegree = 111320 * Math.cos(origin[1] * Math.PI / 180);
  const latitudeMetresPerDegree = 110540;
  const chunkSizeMetres = 256;
  const buildings = [], waterAreas = [], waterCrossings = [], warnings = [];
  let sourceFootprints = 0, skippedInvalid = 0, nonGroundStructures = 0, estimatedConvexPieces = 0;
  const projectRing = geographicPoints => {
    const projected = [];
    for (const value of geographicPoints || []) {
      if (!Array.isArray(value) || value.length < 2 || !Number.isFinite(Number(value[0])) || !Number.isFinite(Number(value[1]))) continue;
      const point = [(Number(value[0]) - origin[0]) * longitudeMetresPerDegree, (origin[1] - Number(value[1])) * latitudeMetresPerDegree];
      const previous = projected[projected.length - 1];
      if (!previous || Math.hypot(point[0] - previous[0], point[1] - previous[1]) > 0.02) projected.push(point);
    }
    if (projected.length > 2 && Math.hypot(projected[0][0] - projected.at(-1)[0], projected[0][1] - projected.at(-1)[1]) <= 0.02) projected.pop();
    return projected;
  };
  for (const feature of features) {
    if (!['building', 'fixed_footprint'].includes(feature.kind)) continue;
    sourceFootprints++;
    if (!buildingBlocksGround(feature)) {
      nonGroundStructures++;
      continue;
    }
    const outer = projectRing(feature.points);
    const area = Math.abs(signedPolygonArea(outer));
    if (outer.length < 3 || area < 0.25 || !isSimplePolygon(outer)) {
      skippedInvalid++;
      warnings.push(`Building ${feature.id || 'unknown'} has an incomplete or invalid outline and was not given collision.`);
      continue;
    }
    const holes = (feature.holes || []).map(projectRing).filter(ring => ring.length >= 3 && Math.abs(signedPolygonArea(ring)) >= 0.25);
    const xs = outer.map(point => point[0]), ys = outer.map(point => point[1]);
    const x = Math.min(...xs), y = Math.min(...ys), width = Math.max(...xs) - x, height = Math.max(...ys) - y;
    const usableArea = Math.max(0, area - holes.reduce((total, hole) => total + Math.abs(signedPolygonArea(hole)), 0));
    estimatedConvexPieces += Math.max(1, outer.length - 2);
    buildings.push({
      id: String(feature.id || ''), kind: 'fixed_building_footprint', outer_metres: outer,
      holes_metres: holes, bounds_metres: { x, y, width, height }, area_square_metres: usableArea,
      chunk: [Math.floor((x + width / 2) / chunkSizeMetres), Math.floor((y + height / 2) / chunkSizeMetres)],
      source: 'osm_footprint', vertical_context: 'ground'
    });
  }
  const roadHalfWidthMetres = tags => {
    const explicitWidth = Number(tags.width);
    if (Number.isFinite(explicitWidth) && explicitWidth > 0.5) return Math.max(1.5, Math.min(20, explicitWidth / 2));
    const highway = String(tags.highway || '').toLowerCase();
    if (['motorway', 'trunk', 'primary'].includes(highway)) return 4.5;
    if (['secondary', 'tertiary'].includes(highway)) return 3.75;
    if (['footway', 'path', 'pedestrian', 'cycleway', 'steps'].includes(highway)) return 1.5;
    return 3.25;
  };
  for (const feature of features) {
    if (feature.kind === 'water') {
      const outer = projectRing(feature.points);
      if (outer.length < 3 || Math.abs(signedPolygonArea(outer)) < 0.25 || !isSimplePolygon(outer)) {
        warnings.push(`Water area ${feature.id || 'unknown'} has an incomplete or invalid outline and was not made blocking.`);
        continue;
      }
      const holes = (feature.holes || []).map(projectRing).filter(ring => ring.length >= 3 && Math.abs(signedPolygonArea(ring)) >= 0.25);
      const xs = outer.map(point => point[0]), ys = outer.map(point => point[1]);
      const x = Math.min(...xs), y = Math.min(...ys), width = Math.max(...xs) - x, height = Math.max(...ys) - y;
      waterAreas.push({
        id: String(feature.id || ''), outer_metres: outer, holes_metres: holes,
        bounds_metres: { x, y, width, height }, source: 'osm_water'
      });
    } else if (feature.kind === 'road') {
      const tags = feature.tags || {};
      const kind = isEnabledOsmTag(tags.bridge) ? 'bridge' : (isEnabledOsmTag(tags.tunnel) ? 'tunnel' : null);
      if (!kind) continue;
      const points = projectRing(feature.points);
      if (points.length < 2) continue;
      const parsedLayer = Number.parseInt(String(tags.layer || '0'), 10);
      waterCrossings.push({
        id: String(feature.id || ''), kind, points_metres: points,
        half_width_metres: roadHalfWidthMetres(tags), layer: Number.isFinite(parsedLayer) ? parsedLayer : 0,
        source: 'osm_road'
      });
    }
  }
  return {
    schema_version: 1, kind: 'building_collision_index',
    projection: {
      method: 'local_equirectangular_metres', origin_longitude: origin[0], origin_latitude: origin[1], y_axis: 'south',
      longitude_metres_per_degree: longitudeMetresPerDegree, latitude_metres_per_degree: latitudeMetresPerDegree
    },
    runtime_scale: { pixels_per_metre: pixelsPerMetre }, chunk_size_metres: chunkSizeMetres,
    buildings, water_areas: waterAreas, water_crossings: waterCrossings,
    statistics: {
      source_footprints: sourceFootprints, collision_buildings: buildings.length,
      skipped_invalid: skippedInvalid, non_ground_structures: nonGroundStructures, estimated_convex_pieces: estimatedConvexPieces,
      blocking_water_areas: waterAreas.length, water_crossings: waterCrossings.length
    },
    warnings
  };
}

function closestPointOnSegment(point, first, second) {
  const dx = second[0] - first[0], dy = second[1] - first[1];
  const lengthSquared = dx * dx + dy * dy;
  if (lengthSquared < 1e-9) return first;
  const amount = Math.max(0, Math.min(1, ((point[0] - first[0]) * dx + (point[1] - first[1]) * dy) / lengthSquared));
  return [first[0] + dx * amount, first[1] + dy * amount];
}

function pointInPolygon(point, polygon) {
  let inside = false;
  for (let index = 0, previous = polygon.length - 1; index < polygon.length; previous = index++) {
    const a = polygon[index], b = polygon[previous];
    if ((a[1] > point[1]) !== (b[1] > point[1]) && point[0] < (b[0] - a[0]) * (point[1] - a[1]) / (b[1] - a[1]) + a[0]) inside = !inside;
  }
  return inside;
}

function roadHalfWidthMetres(tags) {
  const width = Number(tags?.width);
  if (Number.isFinite(width) && width > 0.5) return Math.max(1.5, Math.min(20, width / 2));
  const highway = String(tags?.highway || '').toLowerCase();
  if (['motorway', 'trunk', 'primary'].includes(highway)) return 4.5;
  if (['secondary', 'tertiary'].includes(highway)) return 3.75;
  if (['footway', 'path', 'pedestrian', 'cycleway', 'steps'].includes(highway)) return 1.5;
  return 3.25;
}

function pointOnWaterCrossing(point, features, clearanceMetres) {
  for (const feature of features) {
    if (feature.kind !== 'road' || (!isEnabledOsmTag(feature.tags?.bridge) && !isEnabledOsmTag(feature.tags?.tunnel))) continue;
    const usableHalfWidth = Math.max(0.5, roadHalfWidthMetres(feature.tags) - clearanceMetres);
    for (let index = 0; index < feature.points.length - 1; index++) {
      const first = localMetres(feature.points[index], point), second = localMetres(feature.points[index + 1], point);
      const closest = closestPointOnSegment([0, 0], first, second);
      if (Math.hypot(closest[0], closest[1]) <= usableHalfWidth) return true;
    }
  }
  return false;
}

function isUnsafeWater(point, features, clearanceMetres) {
  if (pointOnWaterCrossing(point, features, clearanceMetres)) return false;
  const samples = [[0, 0]];
  if (clearanceMetres > 0) samples.push([clearanceMetres, 0], [-clearanceMetres, 0], [0, clearanceMetres], [0, -clearanceMetres]);
  for (const feature of features) {
    if (feature.kind !== 'water' || feature.points.length < 3) continue;
    const outer = feature.points.map(candidate => localMetres(candidate, point));
    const holes = (feature.holes || []).map(hole => hole.map(candidate => localMetres(candidate, point)));
    for (const sample of samples) {
      if (pointInPolygon(sample, outer) && !holes.some(hole => hole.length >= 3 && pointInPolygon(sample, hole))) return true;
    }
  }
  return false;
}

function distanceToFixedFootprints(point, features) {
  let nearest = Infinity;
  for (const feature of features) {
    if (!buildingBlocksGround(feature) || feature.points.length < 3) continue;
    const polygon = feature.points.map(candidate => localMetres(candidate, point));
	const holes = (feature.holes || []).map(hole => hole.map(candidate => localMetres(candidate, point)));
	const containingHole = holes.find(hole => hole.length >= 3 && pointInPolygon([0, 0], hole));
	if (pointInPolygon([0, 0], polygon) && !containingHole) return 0;
	const boundaryPolygons = containingHole ? [containingHole] : [polygon];
	for (const boundary of boundaryPolygons) for (let index = 0; index < boundary.length; index++) {
	  const closest = closestPointOnSegment([0, 0], boundary[index], boundary[(index + 1) % boundary.length]);
	  nearest = Math.min(nearest, Math.hypot(closest[0], closest[1]));
	}
  }
  return nearest;
}

function collectNearbyFixedFootprints(features, origin) {
  const latitudeMargin = (MAX_VEHICLE_DISTANCE_METRES + VEHICLE_CLEARANCE_METRES) / 110540;
  const longitudeScale = Math.max(1, 111320 * Math.cos(origin[1] * Math.PI / 180));
  const longitudeMargin = (MAX_VEHICLE_DISTANCE_METRES + VEHICLE_CLEARANCE_METRES) / longitudeScale;
  const footprints = [];
  for (const feature of features) {
    if (!buildingBlocksGround(feature) || feature.points.length < 3) continue;
    const longitudes = feature.points.map(point => point[0]), latitudes = feature.points.map(point => point[1]);
    const bounds = {
      west: Math.min(...longitudes), east: Math.max(...longitudes),
      south: Math.min(...latitudes), north: Math.max(...latitudes)
    };
    if (bounds.east < origin[0] - longitudeMargin || bounds.west > origin[0] + longitudeMargin) continue;
    if (bounds.north < origin[1] - latitudeMargin || bounds.south > origin[1] + latitudeMargin) continue;
	footprints.push({ points: feature.points, holes: feature.holes || [], ...bounds });
  }
  return footprints;
}

function overlapsFixedFootprint(point, footprints, clearanceMetres) {
  const latitudeMargin = clearanceMetres / 110540;
  const longitudeScale = Math.max(1, 111320 * Math.cos(point[1] * Math.PI / 180));
  const longitudeMargin = clearanceMetres / longitudeScale;
  for (const footprint of footprints) {
    if (footprint.east < point[0] - longitudeMargin || footprint.west > point[0] + longitudeMargin) continue;
    if (footprint.north < point[1] - latitudeMargin || footprint.south > point[1] + latitudeMargin) continue;
    const polygon = footprint.points.map(candidate => localMetres(candidate, point));
	const holes = (footprint.holes || []).map(hole => hole.map(candidate => localMetres(candidate, point)));
	const containingHole = holes.find(hole => hole.length >= 3 && pointInPolygon([0, 0], hole));
	if (pointInPolygon([0, 0], polygon) && !containingHole) return true;
	if (containingHole) {
	  for (let index = 0; index < containingHole.length; index++) {
		const closest = closestPointOnSegment([0, 0], containingHole[index], containingHole[(index + 1) % containingHole.length]);
		if (Math.hypot(closest[0], closest[1]) < clearanceMetres) return true;
	  }
	  continue;
	}
    for (let index = 0; index < polygon.length; index++) {
      const closest = closestPointOnSegment([0, 0], polygon[index], polygon[(index + 1) % polygon.length]);
      if (Math.hypot(closest[0], closest[1]) < clearanceMetres) return true;
    }
  }
  return false;
}

function createStartingLocation(playerLocation, features) {
  const player = [playerLocation.longitude, playerLocation.latitude];
  const nearbyFootprints = collectNearbyFixedFootprints(features, player);
  if (overlapsFixedFootprint(player, nearbyFootprints, PLAYER_CLEARANCE_METRES)) {
    return { ok: false, message: 'That starting point is inside or too close to a fixed building. Choose an open space.' };
  }
  if (isUnsafeWater(player, features, PLAYER_CLEARANCE_METRES)) {
    return { ok: false, message: 'That starting point is in mapped water. Choose dry land or a mapped bridge.' };
  }
  const candidates = [];
  for (const road of features.filter(feature => feature.kind === 'road')) {
    for (let index = 0; index < road.points.length - 1; index++) {
      const first = road.points[index], second = road.points[index + 1];
      const localFirst = localMetres(first, player), localSecond = localMetres(second, player);
      const segment = [localSecond[0] - localFirst[0], localSecond[1] - localFirst[1]];
      const lengthSquared = segment[0] ** 2 + segment[1] ** 2;
      if (lengthSquared < 0.01) continue;
      const nearestT = Math.max(0, Math.min(1, -(localFirst[0] * segment[0] + localFirst[1] * segment[1]) / lengthSquared));
      const nearestOffset = [localFirst[0] + segment[0] * nearestT, localFirst[1] + segment[1] * nearestT];
      if (Math.hypot(nearestOffset[0], nearestOffset[1]) > MAX_VEHICLE_DISTANCE_METRES + 12) continue;
      const offsetT = 12 / Math.sqrt(lengthSquared);
      for (const rawT of [nearestT - offsetT, nearestT + offsetT, nearestT]) {
        const amount = Math.max(0, Math.min(1, rawT));
        const candidate = [first[0] + (second[0] - first[0]) * amount, first[1] + (second[1] - first[1]) * amount];
        const offset = localMetres(candidate, player), distance = Math.hypot(offset[0], offset[1]);
        if (distance < PLAYER_VEHICLE_GAP_METRES || distance > MAX_VEHICLE_DISTANCE_METRES) continue;
        candidates.push({ point: candidate, distance });
      }
    }
  }
  candidates.sort((first, second) => first.distance - second.distance);
  const bestPoint = candidates.slice(0, 64).find(candidate =>
    !overlapsFixedFootprint(candidate.point, nearbyFootprints, VEHICLE_CLEARANCE_METRES)
    && !isUnsafeWater(candidate.point, features, VEHICLE_CLEARANCE_METRES)
  )?.point;
  if (!bestPoint) return { ok: false, message: "No clear road position was found for the player's vehicle nearby. Choose another open starting area." };
  return {
    ok: true,
    starting_location: {
      longitude: player[0], latitude: player[1],
      vehicle: { longitude: bestPoint[0], latitude: bestPoint[1] },
      clearance: { checked_against: 'fixed_building_footprints_and_osm_water', player_metres: PLAYER_CLEARANCE_METRES, vehicle_metres: VEHICLE_CLEARANCE_METRES }
    }
  };
}

function validateStartingLocation(startingLocation, features) {
  if (!startingLocation || !Number.isFinite(startingLocation.longitude) || !Number.isFinite(startingLocation.latitude)) return "The player's starting location is missing.";
  const vehicle = startingLocation.vehicle;
  if (!vehicle || !Number.isFinite(vehicle.longitude) || !Number.isFinite(vehicle.latitude)) return "The player's vehicle does not have a complete starting location.";
  const rotation = vehicle.rotation_degrees ?? 0;
  if (!Number.isFinite(rotation) || rotation < 0 || rotation > 360) return 'Choose a car direction between 0 and 360 degrees.';
  const playerPoint = [startingLocation.longitude, startingLocation.latitude];
  const vehiclePoint = [vehicle.longitude, vehicle.latitude];
  const nearbyFootprints = collectNearbyFixedFootprints(features, playerPoint);
  if (overlapsFixedFootprint(playerPoint, nearbyFootprints, PLAYER_CLEARANCE_METRES)) return 'The player would start inside or too close to a fixed building footprint.';
  if (overlapsFixedFootprint(vehiclePoint, nearbyFootprints, VEHICLE_CLEARANCE_METRES)) return "The player's vehicle would start inside or too close to a fixed building footprint.";
  if (isUnsafeWater(playerPoint, features, PLAYER_CLEARANCE_METRES)) return 'The player would start in mapped water.';
  if (isUnsafeWater(vehiclePoint, features, VEHICLE_CLEARANCE_METRES)) return "The player's vehicle would start in mapped water.";
  const offset = localMetres(vehiclePoint, playerPoint), separation = Math.hypot(offset[0], offset[1]);
  if (separation < PLAYER_VEHICLE_GAP_METRES) return 'The player and vehicle starting positions overlap.';
  if (separation > MAX_VEHICLE_DISTANCE_METRES) return "The player's vehicle is too far from the player starting point.";
  return null;
}

function writeJson(filePath, value) {
  fs.writeFileSync(filePath, `${JSON.stringify(value, null, 2)}\n`);
}

function validateGameSettings(settings) {
  const errors = [], warnings = [];
  if (Object.hasOwn(settings || {},'character_art')) {
    const art=settings.character_art;
    if (!art || typeof art!=='object' || Array.isArray(art) || ['npc_type','player_type'].some(key=>!['static','animated'].includes(art[key]))) errors.push('Character artwork must be static or animated.');
  }
  const check = (group, key, minimum, maximum, label, integer = false) => {
    const value = group?.[key];
    if (typeof value !== 'number' || !Number.isFinite(value)) errors.push(`${label} is missing or is not a number.`);
    else if (value < minimum || value > maximum) errors.push(`${label} must be between ${minimum} and ${maximum}.`);
    else if (integer && !Number.isInteger(value)) errors.push(`${label} must be a whole number.`);
  };
  if (settings?.schema_version !== SCHEMA_VERSION) errors.push('The game settings use an unsupported format.');
  check(settings?.population, 'traffic_car_count', 0, 1000, 'Traffic count', true);
  check(settings?.population, 'pedestrian_count', 0, 2000, 'Pedestrian count', true);
  check(settings?.population, 'cbd_car_percent', 0, 100, 'CBD traffic percentage', true);
  check(settings?.population, 'cbd_pedestrian_percent', 0, 100, 'CBD pedestrian percentage', true);
  check(settings?.population, 'robot_count', 0, 1000, 'NPR count', true);
  check(settings?.population, 'cbd_robot_percent', 0, 100, 'NPR CBD percentage', true);
  check(settings?.population, 'drone_count', 0, 1000, 'NPD count', true);
  check(settings?.population, 'cbd_drone_percent', 0, 100, 'NPD CBD percentage', true);
  if (!['left', 'right'].includes(settings?.road_rules?.driving_side)) errors.push('Driving side must be left or right.');
  const skinToneKeys = Object.keys(recommendedGameSettings().skin_tone_distribution);
  let skinToneTotal = 0;
  for (const key of skinToneKeys) {
    check(settings?.skin_tone_distribution, key, 0, 100, 'Skin pigmentation tone percentage');
    skinToneTotal += Number(settings?.skin_tone_distribution?.[key] || 0);
  }
  if (Math.abs(skinToneTotal - 100) > 0.05) errors.push(`Skin pigmentation tone percentages must total 100%. They currently total ${skinToneTotal.toFixed(2)}%.`);
  // Previous towns had no separate walking zoom. They still validate with
  // their original 1x walking view; a supplied value must meet the GUI range.
  if (settings && 'camera' in settings) check(settings?.camera, 'character_zoom', 0.2, 3, 'On-foot camera zoom');
  check(settings?.driving, 'max_speed_kmh', 1, 400, 'Maximum vehicle speed');
  if (settings?.driving && 'zero_to_hundred_seconds' in settings.driving) check(settings.driving, 'zero_to_hundred_seconds', 3, 20, '0–100 km/h time');
  if (settings?.driving && 'reverse_max_speed_kmh' in settings.driving) check(settings.driving, 'reverse_max_speed_kmh', 5, 40, 'Maximum reverse speed');
  check(settings?.driving, 'forward_speed', 1, 400, 'Forward speed');
  check(settings?.driving, 'reverse_speed', 1, 200, 'Reverse speed');
  check(settings?.driving, 'acceleration', 1, 400, 'Acceleration');
  check(settings?.driving, 'reverse_acceleration', 1, 400, 'Reverse acceleration');
  check(settings?.driving, 'coast_deceleration', 1, 400, 'Coasting slowdown');
  check(settings?.driving, 'brake_deceleration', 1, 800, 'Brake strength');
  check(settings?.driving, 'steering_rate', 0.1, 8, 'Steering speed');
  check(settings?.driving, 'camera_zoom_multiplier', 0.2, 3, 'In-car camera zoom');
  if (typeof settings?.traffic_recovery?.enabled !== 'boolean') errors.push('Traffic jam recovery must be on or off.');
  check(settings?.traffic_recovery, 'jam_timeout_seconds', 5, 300, 'Jam timeout');
  check(settings?.traffic_recovery, 'recovery_spacing_seconds', 0.25, 30, 'Recovery spacing');
  check(settings?.traffic_recovery, 'respawn_distance_pixels', 100, 10000, 'Traffic respawn distance');
  check(settings?.traffic_recovery, 'respawn_attempts', 1, 200, 'Traffic respawn attempts', true);
  if ((settings?.population?.traffic_car_count || 0) > 400) warnings.push('More than 400 traffic cars may run slowly on some computers.');
  if ((settings?.population?.pedestrian_count || 0) > 500) warnings.push('More than 500 pedestrians may run slowly on some computers.');
  if ((settings?.population?.robot_count || 0) > 200) warnings.push('More than 200 walking robots may run slowly on some computers.');
  if ((settings?.population?.drone_count || 0) > 200) warnings.push('More than 200 flying drones may run slowly on some computers.');
  return { schema_version: SCHEMA_VERSION, passed: errors.length === 0, errors, warnings };
}

function importTown(options) {
  if (!options.name || !String(options.name).trim()) throw new Error('--name is required.');
  if (!options.workspace) throw new Error('--workspace is required. The creator chooses where game files are saved.');
  const sourceFiles = (options.osm || []).flatMap(value => String(value).split(',')).map(value => path.resolve(value));
  const parsed = parseOsmFiles(sourceFiles);
  if (parsed.statistics.unresolved_water_relations > 0) {
    throw new Error('This OSM export contains incomplete water boundaries that could not be placed safely. Creator Studio will not build a project that might allow driving over unknown water. Export this area again with complete OSM water data.');
  }
  const cbdBounds = parseBounds(options.cbd, 'cbd');
  const requestedStartingLocation = parseLocation(options.start);
  if (!containsBounds(parsed.bounds, cbdBounds)) throw new Error('The CBD area must stay inside the imported map.');
  if (!containsLocation(parsed.bounds, requestedStartingLocation)) throw new Error('The starting location must stay inside the imported map.');
  const spawnResult = createStartingLocation(requestedStartingLocation, parsed.features);
  if (!spawnResult.ok) throw new Error(spawnResult.message);
  const startingLocation = spawnResult.starting_location;

  const townId = safeId(String(options.name));
  const townDirectory = path.resolve(String(options.workspace), townId);
  const sourceDirectory = path.join(townDirectory, 'source_osm');
  const dataDirectory = path.join(townDirectory, 'data');
  fs.mkdirSync(sourceDirectory, { recursive: true });
  fs.mkdirSync(dataDirectory, { recursive: true });
  const copiedSources = sourceFiles.map((source, index) => {
    const relative = path.join('source_osm', `${String(index + 1).padStart(2, '0')}_${path.basename(source)}`);
    fs.copyFileSync(source, path.join(townDirectory, relative));
    return relative.replaceAll('\\', '/');
  });

  const town = {
    schema_version: SCHEMA_VERSION,
    creator_version: CREATOR_VERSION,
    kind: 'digital_world_twin_town',
    id: townId,
    display_name: String(options.name).trim(),
    created_utc: new Date().toISOString(),
    source: { format: 'osm_xml', files: copiedSources, original_files: sourceFiles },
    map_bounds: parsed.bounds,
    cbd: { type: 'bounding_box', bounds: cbdBounds },
    starting_location: startingLocation,
    statistics: parsed.statistics
  };
  writeJson(path.join(townDirectory, 'town.json'), town);
  writeJson(path.join(dataDirectory, 'map_features.json'), { schema_version: SCHEMA_VERSION, preserves_osm_node_tags: true, features: parsed.features });
  writeJson(path.join(dataDirectory, 'map_overrides.json'), emptyMapOverrides(parsed.features, parsed.bounds));
  writeJson(path.join(dataDirectory, 'building_exteriors.json'), {
    schema_version: SCHEMA_VERSION, kind: 'creator_building_exteriors', buildings: {}
  });
  writeJson(path.join(dataDirectory, 'building_interiors.json'), {
    schema_version: SCHEMA_VERSION, kind: 'creator_building_interiors', buildings: {}
  });
  writeJson(path.join(dataDirectory, 'interior_furniture_catalog.json'), {
    schema_version: SCHEMA_VERSION, kind: 'creator_interior_furniture_catalog', items: []
  });
  writeJson(path.join(dataDirectory, 'interior_floor_materials.json'), {
    schema_version: SCHEMA_VERSION, kind: 'creator_interior_floor_materials', items: []
  });
  writeJson(path.join(dataDirectory, 'personas.json'), recommendedPersonas());
  writeJson(path.join(dataDirectory, 'town_knowledge.json'), recommendedTownKnowledge());
  writeJson(path.join(dataDirectory, 'place_information.json'), buildPlaceInformation(parsed.features));
  writeJson(path.join(dataDirectory, 'building_collisions.json'), buildBuildingCollisions(parsed.features, parsed.bounds));
  writeJson(path.join(townDirectory, 'game_settings.json'), recommendedGameSettings());
  writeJson(path.join(townDirectory, 'runtime_profile.json'), {
    schema_version: SCHEMA_VERSION,
    runtime_family: '2d_digital_world_twin',
    required_features: REQUIRED_RUNTIME_FEATURES,
    // The Node CLI deliberately does not duplicate Godot's navigation builder.
    // Codex can run build_town_navigation.gd afterwards to make this playable.
    template_status: 'pending_runtime_build',
    play_mode: 'creator_studio_shared_runtime',
    capabilities: {
      building_collision_data: 'ready',
      building_collision_streaming_loader: 'ready',
      osm_building_place_information: 'ready',
      osm_water_placement: 'ready',
      bridge_water_crossings: 'ready',
      tunnel_layer_metadata: 'ready',
      surface_collision_excludes_non_ground_structures: 'ready',
      map_geometry_conflict_validation: 'requires_godot_build',
      navigation_graphs: 'requires_godot_build',
      osm_population_destinations: 'requires_godot_build',
      creator_map_overrides: 'ready',
      creator_building_exteriors: 'ready',
      creator_building_interiors: 'data_ready',
      local_ollama_persona_conversations: 'preview_ready'
    },
    preview_limitations: [
      'ambiguous_or_incomplete_coastline_relations_still_require_a_complete_export;_known_local_water_omissions_can_use_creator_overrides',
      'road_building_and_vertical_route_audit_requires_the_deterministic_godot_build_step',
      'detailed_turn_corridors_and_compatible_signal_movements',
      'venues_and_interiors',
      'property_boundaries_and_breakable_fences',
      'save_game_progress'
    ]
  });
  const validation = validateTownDirectory(townDirectory);
  validation.warnings.push(...(parsed.warnings || []));
  writeJson(path.join(townDirectory, 'validation.json'), validation);
  return { ok: true, town_directory: townDirectory, town, validation };
}

function validateTownDirectory(townDirectoryValue) {
  const townDirectory = path.resolve(String(townDirectoryValue));
  const errors = [], warnings = [];
  const townPath = path.join(townDirectory, 'town.json');
  let town = null;
  if (!fs.existsSync(townPath)) errors.push('town.json is missing.');
  else {
    try { town = JSON.parse(fs.readFileSync(townPath, 'utf8')); }
    catch { errors.push('town.json is not valid JSON.'); }
  }
  if (town) {
    if (town.schema_version !== SCHEMA_VERSION) errors.push(`Unsupported schema_version ${town.schema_version}.`);
    if (town.kind !== 'digital_world_twin_town') errors.push('town.json has the wrong kind.');
    if (!town.id || !town.display_name) errors.push('The town ID or display name is missing.');
    if (!town.map_bounds || !town.cbd?.bounds || !town.starting_location) errors.push('Map, CBD or starting-location data is missing.');
    else {
      if (!containsBounds(town.map_bounds, town.cbd.bounds)) errors.push('The CBD is outside the imported map.');
      if (!containsLocation(town.map_bounds, town.starting_location)) errors.push('The starting location is outside the imported map.');
      if (town.starting_location.vehicle && !containsLocation(town.map_bounds, town.starting_location.vehicle)) errors.push("The player's vehicle starting location is outside the imported map.");
    }
    for (const source of town.source?.files || []) {
      if (!fs.existsSync(path.join(townDirectory, source))) errors.push(`Source file is missing: ${source}`);
    }
    if (!town.statistics?.buildings) warnings.push('No building footprints were recorded.');
    if (!town.statistics?.roads) warnings.push('No roads were recorded.');
    if ((town.statistics?.unresolved_water_relations || 0) > 0) errors.push('The project has unresolved OSM water boundaries and is not safe to play. Re-export the OSM area with complete water data.');
  }
  const featureIndexPath = path.join(townDirectory, 'data', 'map_features.json');
  if (!fs.existsSync(featureIndexPath)) errors.push('data/map_features.json is missing.');
  else if (town?.starting_location) {
    try {
      const featureIndex = JSON.parse(fs.readFileSync(featureIndexPath, 'utf8'));
      const spawnError = validateStartingLocation(town.starting_location, featureIndex.features || []);
      if (spawnError) errors.push(spawnError);
    } catch { errors.push('data/map_features.json is not valid JSON.'); }
  }
  const mapOverridesPath = path.join(townDirectory, 'data', 'map_overrides.json');
  if (fs.existsSync(mapOverridesPath)) {
    try {
      const mapOverrides = JSON.parse(fs.readFileSync(mapOverridesPath, 'utf8'));
      if (mapOverrides.kind !== 'creator_map_overrides' || !Array.isArray(mapOverrides.hidden_feature_ids) || !Array.isArray(mapOverrides.zones)) {
        errors.push('data/map_overrides.json is invalid.');
      }
      const zoneIds = new Set();
      const customIds = new Set();
      const customBuildings = mapOverrides.custom_buildings ?? [];
      if(!Array.isArray(customBuildings) || customBuildings.length > 1000) errors.push('data/map_overrides.json contains invalid custom buildings.');
      else for(const feature of customBuildings) {
        const points = feature?.points;
        if(!/^creator_building_[1-9]\d*$/.test(feature?.id || '') || customIds.has(feature.id) || feature.kind !== 'building' || !feature.tags || typeof feature.tags !== 'object' || Array.isArray(feature.tags) || !Array.isArray(points) || points.length !== 5 || points.some(p=>!Array.isArray(p)||p.length!==2||p.some(n=>typeof n!=='number'||!Number.isFinite(n))||Math.abs(p[0])>180||Math.abs(p[1])>=90) || JSON.stringify(points[0]) !== JSON.stringify(points[4]) || (feature.precise_points && JSON.stringify(feature.precise_points)!==JSON.stringify(points)) || points[0][1]!==points[1][1] || points[1][0]!==points[2][0] || points[2][1]!==points[3][1] || points[3][0]!==points[0][0]) { errors.push('data/map_overrides.json contains invalid custom buildings.'); break; }
        const width=Math.abs(points[1][0]-points[0][0])*111320*Math.cos(points[0][1]*Math.PI/180), height=Math.abs(points[2][1]-points[1][1])*110540;
        if(width<2||height<2) { errors.push('data/map_overrides.json contains an undersized custom building.'); break; }
        customIds.add(feature.id);
      }
      for (const zone of mapOverrides.zones || []) {
        if (!zone?.id || zoneIds.has(zone.id) || !['blocked_water', 'allowed_ground'].includes(zone.mode) || !Array.isArray(zone.points) || zone.points.length < 4) {
          errors.push('data/map_overrides.json contains an invalid correction zone.');
          break;
        }
        zoneIds.add(zone.id);
      }
    } catch { errors.push('data/map_overrides.json is not valid JSON.'); }
  } else warnings.push('Map corrections are not available in this older project. Rebuild it in Creator Studio to add the Advanced Map Editor data file.');
  const buildingExteriorsPath = path.join(townDirectory, 'data', 'building_exteriors.json');
  if (fs.existsSync(buildingExteriorsPath)) {
    try {
      const exteriors = JSON.parse(fs.readFileSync(buildingExteriorsPath, 'utf8'));
      if (exteriors.kind !== 'creator_building_exteriors' || !exteriors.buildings || Array.isArray(exteriors.buildings)) {
        errors.push('data/building_exteriors.json is invalid.');
      } else {
        for (const [featureId, record] of Object.entries(exteriors.buildings)) {
          if (!record || String(record.feature_id || '') !== featureId) {
            errors.push('data/building_exteriors.json contains an invalid stable building ID.');
            break;
          }
          const relativePath = String(record.exterior?.relative_path || '');
          if (record.total_floors !== undefined && (!Number.isInteger(record.total_floors) || record.total_floors < 1 || record.total_floors > 200)) {
            errors.push('data/building_exteriors.json contains an invalid total floor count (1–200 whole floors required).');
          }
          if (record.building_style !== undefined && !['automatic', 'brick', 'rendered', 'commercial', 'tall', 'industrial'].includes(record.building_style)) {
            errors.push('data/building_exteriors.json contains an unknown building style.');
          }
          const artworkMaterials = ['automatic', 'brick', 'concrete', 'glass'];
          const validArtworkAlignment = value => value && typeof value === 'object' && !Array.isArray(value) && Object.entries({scale_percent:[50,300],rotation_degrees:[-180,180],offset_x_percent:[-100,100],offset_y_percent:[-100,100]}).every(([key,[minimum,maximum]]) => value[key] === undefined || (typeof value[key] === 'number' && Number.isFinite(value[key]) && value[key] >= minimum && value[key] <= maximum));
          for (const key of ['roof_alignment', 'wall_alignment']) {
            if (record[key] !== undefined && !validArtworkAlignment(record[key])) errors.push('data/building_exteriors.json contains invalid artwork alignment values.');
          }
          if (record.wall_material !== undefined && !artworkMaterials.includes(record.wall_material)) errors.push('data/building_exteriors.json contains an unknown wall material.');
          if (record.facades !== undefined) {
            if (!record.facades || typeof record.facades !== 'object' || Array.isArray(record.facades)) errors.push('data/building_exteriors.json contains invalid facade settings.');
            else for (const [face, facade] of Object.entries(record.facades)) {
              if (!['front','left'].includes(face) || !facade || typeof facade !== 'object' || Array.isArray(facade)) { errors.push('data/building_exteriors.json contains invalid facade settings.'); continue; }
              if (facade.material !== undefined && !artworkMaterials.includes(facade.material)) errors.push('data/building_exteriors.json contains an unknown facade material.');
              if (facade.alignment !== undefined && !validArtworkAlignment(facade.alignment)) errors.push('data/building_exteriors.json contains invalid facade alignment values.');
              if (facade.wall !== undefined) {
                const safeId = featureId.toLowerCase().replace(/[^a-z0-9]+/g, '_').replace(/^_|_$/g, '') || 'building';
                const facadePath = String(facade.wall?.relative_path || '');
                if (!facadePath.startsWith(`assets/buildings/${safeId}/`) || facadePath.includes('..') || facadePath.includes(':') || facadePath.includes('\\') || path.isAbsolute(facadePath) || ![facade.wall?.width,facade.wall?.height].every(value => Number.isInteger(value) && value >= 16 && value <= 4096)) errors.push('data/building_exteriors.json contains invalid facade artwork metadata.');
                else if (!fs.existsSync(path.join(townDirectory,facadePath))) errors.push(`A custom building facade image is missing: ${facadePath}`);
              }
            }
          }
          if (record.wall !== undefined) {
            const safeId = featureId.toLowerCase().replace(/[^a-z0-9]+/g, '_').replace(/^_|_$/g, '') || 'building';
            const wallPath = String(record.wall?.relative_path || '');
            if (!wallPath.startsWith(`assets/buildings/${safeId}/`) || wallPath.includes('..') || wallPath.includes(':') || wallPath.includes('\\') || path.isAbsolute(wallPath) || ![record.wall?.width, record.wall?.height].every(value => Number.isInteger(value) && value >= 16 && value <= 4096)) {
              errors.push('data/building_exteriors.json contains invalid wall artwork metadata.');
            } else if (!fs.existsSync(path.join(townDirectory, wallPath))) {
              errors.push(`A custom building wall image is missing: ${wallPath}`);
            }
          }
          if (record.custom_name !== undefined && (typeof record.custom_name !== 'string' || record.custom_name.length > 80 || /[\r\n]/.test(record.custom_name))) {
            errors.push('data/building_exteriors.json contains an invalid custom building name.');
          }
          const normalizedParts = relativePath.replace(/\\/g, '/').split('/');
          if (relativePath && (path.isAbsolute(relativePath) || normalizedParts.includes('..'))) {
            errors.push('data/building_exteriors.json contains an unsafe artwork path.');
            break;
          }
          if (relativePath && !fs.existsSync(path.join(townDirectory, relativePath))) {
            errors.push(`A custom building exterior image is missing: ${relativePath}`);
            break;
          }
          if (record.exterior) {
            const scale = Number(record.exterior.scale_percent ?? 100);
            const rotation = Number(record.exterior.rotation_degrees ?? 0);
            const offsetX = Number(record.exterior.offset_x_percent ?? 0);
            const offsetY = Number(record.exterior.offset_y_percent ?? 0);
            if (!Number.isFinite(scale) || scale < 50 || scale > 300 || !Number.isFinite(rotation) || Math.abs(rotation) > 180 || !Number.isFinite(offsetX) || Math.abs(offsetX) > 100 || !Number.isFinite(offsetY) || Math.abs(offsetY) > 100) {
              errors.push('data/building_exteriors.json contains invalid artwork alignment values.');
              break;
            }
          }
          const entrances = Array.isArray(record.doors) ? record.doors : (record.door ? [{ id: 'entrance_1', ...record.door }] : []);
          if (entrances.length > 8 || new Set(entrances.map(door => String(door.id || ''))).size !== entrances.length || entrances.some(door => !door.id || ['longitude', 'latitude', 'outside_longitude', 'outside_latitude'].some(key => !Number.isFinite(Number(door[key]))))) {
            errors.push('data/building_exteriors.json contains invalid entrance data.');
            break;
          }
        }
      }
    } catch { errors.push('data/building_exteriors.json is not valid JSON.'); }
  } else warnings.push('Building Creator data is not available in this older project. Rebuild it in Creator Studio to add the building exterior file.');
  const furnitureCatalogPath = path.join(townDirectory, 'data', 'interior_furniture_catalog.json');
  const customFurniture = new Map();
  if (fs.existsSync(furnitureCatalogPath)) {
    try {
      const catalog = JSON.parse(fs.readFileSync(furnitureCatalogPath, 'utf8'));
      if (catalog.kind !== 'creator_interior_furniture_catalog' || !Array.isArray(catalog.items) || catalog.items.length > 500) {
        errors.push('data/interior_furniture_catalog.json is invalid.');
      } else {
        for (const item of catalog.items) {
          const id = String(item?.id || '');
          const imagePath = String(item?.image_path || '').replace(/\\/g, '/');
          const size = item?.size_metres;
          const safePath = imagePath.startsWith('assets/interiors/furniture/') && !imagePath.includes('..') && !path.isAbsolute(imagePath);
          if (!id.startsWith('custom_') || customFurniture.has(id) || !String(item?.name || '').trim() || !String(item?.object_type || '').trim() || !Array.isArray(size) || size.length !== 2 || size.some(value => !Number.isFinite(Number(value)) || Number(value) < 0.1 || Number(value) > 20) || item?.catalog_source !== 'creator_imported' || item?.collision !== true || !safePath) {
            errors.push('data/interior_furniture_catalog.json contains invalid custom furniture data.');
            break;
          }
          if (!fs.existsSync(path.join(townDirectory, imagePath))) {
            errors.push(`Custom furniture artwork is missing: ${imagePath}`);
            break;
          }
          customFurniture.set(id, item);
        }
      }
    } catch { errors.push('data/interior_furniture_catalog.json is not valid JSON.'); }
  } else warnings.push('Custom furniture catalogue is not available in this older project; built-in furniture remains usable.');
  const floorMaterialCatalogPath = path.join(townDirectory, 'data', 'interior_floor_materials.json');
  const validFloorMaterials = new Set(['floor_light_oak', 'floor_dark_walnut', 'floor_weathered_grey', 'floor_bathroom_ceramic', 'floor_bathroom_slate', 'floor_bathroom_checker']);
  if (fs.existsSync(floorMaterialCatalogPath)) {
    try {
      const catalog = JSON.parse(fs.readFileSync(floorMaterialCatalogPath, 'utf8'));
      if (catalog.kind !== 'creator_interior_floor_materials' || !Array.isArray(catalog.items) || catalog.items.length > 200) {
        errors.push('data/interior_floor_materials.json is invalid.');
      } else {
        for (const item of catalog.items) {
          const id = String(item?.id || '');
          const imagePath = String(item?.image_path || '').replace(/\\/g, '/');
          const safePath = imagePath.startsWith('assets/interiors/floors/') && !imagePath.includes('..') && !path.isAbsolute(imagePath);
          if (!/^custom_floor_[a-z0-9_]+$/.test(id) || validFloorMaterials.has(id) || !String(item?.name || '').trim() || item?.catalog_source !== 'creator_imported' || !safePath) {
            errors.push('data/interior_floor_materials.json contains invalid custom floor data.');
            break;
          }
          if (!fs.existsSync(path.join(townDirectory, imagePath))) {
            errors.push(`Custom floor artwork is missing: ${imagePath}`);
            break;
          }
          validFloorMaterials.add(id);
        }
      }
    } catch { errors.push('data/interior_floor_materials.json is not valid JSON.'); }
  } else warnings.push('Custom floor-material catalogue is not available in this older project; built-in floorboards remain usable.');
  const buildingInteriorsPath = path.join(townDirectory, 'data', 'building_interiors.json');
  if (fs.existsSync(buildingInteriorsPath)) {
    try {
      const interiors = JSON.parse(fs.readFileSync(buildingInteriorsPath, 'utf8'));
      if (interiors.kind !== 'creator_building_interiors' || !interiors.buildings || Array.isArray(interiors.buildings)) {
        errors.push('data/building_interiors.json is invalid.');
      } else {
        for (const [featureId, record] of Object.entries(interiors.buildings)) {
          if (!record || String(record.feature_id || '') !== featureId || !Array.isArray(record.floors) || record.floors.length < 1 || record.floors.length > 20) {
            errors.push('data/building_interiors.json contains invalid building or floor data.');
            break;
          }
          const floorIds = new Set();
          for (let index = 0; index < record.floors.length; index += 1) {
            const floor = record.floors[index];
            const id = String(floor?.id || '');
            const width = Number(floor?.width_metres);
            const height = Number(floor?.height_metres);
            const scale = Number(floor?.footprint_scale ?? 1);
            if (!id || floorIds.has(id) || Number(floor?.level) !== index || !Number.isFinite(width) || width <= 0.25 || width > 2000 || !Number.isFinite(height) || height <= 0.25 || height > 2000 || !Number.isFinite(scale) || scale < 1 || scale > 3 || !Array.isArray(floor?.boundary_metres) || floor.boundary_metres.length < 3) {
              errors.push('data/building_interiors.json contains an invalid floor boundary or size.');
              break;
            }
            floorIds.add(id);
            const wallIds = new Set();
            if (!Array.isArray(floor.walls || []) || (floor.walls || []).length > 500) {
              errors.push('data/building_interiors.json contains invalid internal-wall data.');
              break;
            }
            for (const wall of (floor.walls || [])) {
              const wallId = String(wall?.id || '');
              const wallNumbers = ['start_x_metres', 'start_y_metres', 'end_x_metres', 'end_y_metres', 'thickness_metres'];
              const length = Math.hypot(Number(wall?.end_x_metres) - Number(wall?.start_x_metres), Number(wall?.end_y_metres) - Number(wall?.start_y_metres));
              if (!wallId || wallIds.has(wallId) || wallNumbers.some(key => !Number.isFinite(Number(wall?.[key]))) || length < 0.5 || Number(wall?.thickness_metres) < 0.08 || Number(wall?.thickness_metres) > 0.5 || !Array.isArray(wall?.doors || [])) {
                errors.push('data/building_interiors.json contains invalid internal-wall data.');
                break;
              }
              const doorIds = new Set();
              for (const door of (wall.doors || [])) {
                const doorId = String(door?.id || '');
                const offset = Number(door?.offset_metres);
                const doorWidth = Number(door?.width_metres);
                if (!doorId || doorIds.has(doorId) || !Number.isFinite(offset) || !Number.isFinite(doorWidth) || doorWidth < 0.7 || doorWidth > 3 || offset - doorWidth / 2 < 0.15 || offset + doorWidth / 2 > length - 0.15) {
                  errors.push('data/building_interiors.json contains invalid doorway data.');
                  break;
                }
                doorIds.add(doorId);
              }
              wallIds.add(wallId);
            }
            if (errors.some(error => error.includes('building_interiors'))) break;
            const roomIds = new Set();
            if (!Array.isArray(floor.rooms || []) || (floor.rooms || []).length > 200) {
              errors.push('data/building_interiors.json contains invalid room-name data.');
              break;
            }
            for (const room of (floor.rooms || [])) {
              const roomId = String(room?.id || '');
              const roomName = String(room?.name || '').trim();
              if (!roomId || roomIds.has(roomId) || !roomName || roomName.length > 60 || !Number.isFinite(Number(room?.label_x_metres)) || !Number.isFinite(Number(room?.label_y_metres))) {
                errors.push('data/building_interiors.json contains invalid room-name data.');
                break;
              }
              roomIds.add(roomId);
            }
            if (errors.some(error => error.includes('building_interiors'))) break;
            const flooring = floor.flooring;
            if (flooring !== undefined) {
              const cellSize = Number(flooring?.cell_size_metres);
              const cells = flooring?.cells;
              if (!Number.isFinite(cellSize) || cellSize < 0.25 || cellSize > 2 || !cells || Array.isArray(cells) || typeof cells !== 'object' || Object.keys(cells).length > 100000 || Object.entries(cells).some(([key, materialId]) => !/^-?[0-9]+:-?[0-9]+$/.test(key) || !validFloorMaterials.has(String(materialId)))) {
                errors.push('data/building_interiors.json contains invalid painted-floor data.');
                break;
              }
            }
            const furnitureIds = new Set();
            const supportedFurniture = new Set(['dining_table', 'dining_chair', 'sofa', 'single_bed', 'wardrobe', 'kitchen_counter', 'bathroom_sink', 'toilet', 'office_desk', 'shop_shelf', 'bar_counter', 'bar_stool', 'toilet_cubicle', 'toilet_cubicle_grey', 'wall_urinal', 'trough_urinal']);
            for (const item of (floor.furniture || [])) {
              const furnitureId = String(item?.id || '');
              const catalogId = String(item?.catalog_id || '');
              const furnitureNumbers = ['x_metres', 'y_metres', 'width_metres', 'depth_metres', 'rotation_degrees'];
              const customDefinition = customFurniture.get(catalogId);
              const validCustom = Boolean(customDefinition) && item?.catalog_source === 'creator_imported' && item?.collision === true && String(item?.image_path || '') === String(customDefinition?.image_path || '');
              if (!furnitureId || furnitureIds.has(furnitureId) || (!supportedFurniture.has(catalogId) && !validCustom) || furnitureNumbers.some(key => !Number.isFinite(Number(item?.[key]))) || Number(item?.width_metres) <= 0.1 || Number(item?.depth_metres) <= 0.1 || typeof item?.collision !== 'boolean') {
                errors.push('data/building_interiors.json contains invalid furniture data.');
                break;
              }
              furnitureIds.add(furnitureId);
              if (item.seat_direction_degrees !== undefined && (typeof item.seat_direction_degrees !== 'number' || !Number.isFinite(item.seat_direction_degrees) || item.seat_direction_degrees < 0 || item.seat_direction_degrees >= 360)) errors.push('Furniture seat direction must be a finite angle from 0 up to, but not including, 360 degrees.');
            }
            if (errors.some(error => error.includes('building_interiors'))) break;
            const linkIds = new Set();
            for (const link of (floor.entry_links || [])) {
              const linkId = String(link?.id || '');
              if (!linkId || linkIds.has(linkId) || !link?.exterior_entrance_id || !Number.isFinite(Number(link?.spawn_x_metres)) || !Number.isFinite(Number(link?.spawn_y_metres))) {
                errors.push('data/building_interiors.json contains invalid entry-link data.');
                break;
              }
              linkIds.add(linkId);
            }
            if (errors.some(error => error.includes('building_interiors'))) break;
          }
          if (!validateInteriorStairs(record)) errors.push('data/building_interiors.json contains invalid, unpaired or obstructed stairs.');
          if (errors.some(error => error.includes('building_interiors'))) break;
        }
		const sourceFeatures = fs.existsSync(featureIndexPath) ? JSON.parse(fs.readFileSync(featureIndexPath, 'utf8')).features || [] : [];
		const overridePath = path.join(townDirectory, 'data', 'map_overrides.json');
		const overrides = fs.existsSync(overridePath) ? JSON.parse(fs.readFileSync(overridePath, 'utf8')) : {};
		const hidden = overrides.hidden_feature_ids || [];
		const custom = Array.isArray(overrides.custom_buildings) ? overrides.custom_buildings : [];
		const activeFeatures = sourceFeatures.concat(custom).filter(feature => !hidden.includes(feature.id));
		const effectiveFeatures = (interiors.building_connections || []).length ? withSourcePrecision(townDirectory, activeFeatures) : activeFeatures;
		if (!validateBuildingConnections(interiors, effectiveFeatures) || ((interiors.building_connections || []).length && !effectiveFeatures.length)) errors.push('data/building_interiors.json contains invalid or obstructed connecting doors; buildings must share a wall with no gap.');
      }
    } catch { errors.push('data/building_interiors.json is not valid JSON.'); }
  } else warnings.push('Interior Designer data is not available in this older project. Rebuild it in Creator Studio to add the interior layout file.');
  const personasPath = path.join(townDirectory, 'data', 'personas.json');
  const npcCreationsPath = path.join(townDirectory, 'data', 'npc_creations.json');
  const placedNpcsPath = path.join(townDirectory, 'data', 'storyline_npcs.json');
  try {
    const creations = fs.existsSync(npcCreationsPath) ? JSON.parse(fs.readFileSync(npcCreationsPath, 'utf8')) : {schema_version:1,kind:'npc_creations',creations:[]};
    const npcs = fs.existsSync(placedNpcsPath) ? JSON.parse(fs.readFileSync(placedNpcsPath, 'utf8')) : [];
    errors.push(...validateNpcCreations(creations,townDirectory,npcs).errors.map(error => `NPC artwork: ${error}`));
  } catch { errors.push('NPC artwork catalogue or placement data is not valid JSON.'); }
  if (fs.existsSync(personasPath)) {
    try {
      const personaValidation = validatePersonaLibrary(JSON.parse(fs.readFileSync(personasPath, 'utf8')));
      errors.push(...personaValidation.errors);
    } catch { errors.push('data/personas.json is not valid JSON.'); }
  } else warnings.push('Persona data is not saved in this older project. Open NPCs and personas or rebuild it to add the defaults.');
  const townKnowledgePath = path.join(townDirectory, 'data', 'town_knowledge.json');
  const loreValidation = validateGameLore(townDirectory);
  errors.push(...loreValidation.errors);
  warnings.push(...loreValidation.warnings);
  const environmentValidation = validateEnvironmentSettings(townDirectory);
  errors.push(...environmentValidation.errors);
  warnings.push(...environmentValidation.warnings);
  if (fs.existsSync(townKnowledgePath)) {
    try {
      const knowledgeValidation = validateTownKnowledge(JSON.parse(fs.readFileSync(townKnowledgePath, 'utf8')));
      errors.push(...knowledgeValidation.errors);
    } catch { errors.push('data/town_knowledge.json is not valid JSON.'); }
  } else warnings.push('Optional town-knowledge data is not saved in this older project. Open NPCs and personas or rebuild it to add the optional fields.');
  const buildingCollisionsPath = path.join(townDirectory, 'data', 'building_collisions.json');
  if (!fs.existsSync(buildingCollisionsPath)) warnings.push('Building collisions have not been generated yet. Open and save this older project in Creator Studio.');
  else {
    try {
      const collisionIndex = JSON.parse(fs.readFileSync(buildingCollisionsPath, 'utf8'));
      if (collisionIndex.kind !== 'building_collision_index' || !Array.isArray(collisionIndex.buildings)) errors.push('data/building_collisions.json is invalid.');
      if (collisionIndex.water_areas !== undefined && !Array.isArray(collisionIndex.water_areas)) errors.push('The generated water-area index is invalid.');
      if (collisionIndex.water_crossings !== undefined && !Array.isArray(collisionIndex.water_crossings)) errors.push('The generated bridge/tunnel crossing index is invalid.');
      if (town?.statistics?.buildings && collisionIndex.buildings.length === 0) errors.push('No usable building collision shapes were generated.');
      warnings.push(...(collisionIndex.warnings || []));
    } catch { errors.push('data/building_collisions.json is not valid JSON.'); }
  }
  const placeInformationPath = path.join(townDirectory, 'data', 'place_information.json');
  if (fs.existsSync(placeInformationPath)) {
    try {
      const placeInformation = JSON.parse(fs.readFileSync(placeInformationPath, 'utf8'));
      if (placeInformation.kind !== 'osm_building_place_information' || !Array.isArray(placeInformation.places)) errors.push('data/place_information.json is invalid.');
      if (placeInformation.source_attribution !== '© OpenStreetMap contributors') errors.push('Building information is missing its OpenStreetMap attribution.');
    } catch { errors.push('data/place_information.json is not valid JSON.'); }
  } else warnings.push('Building information has not been generated yet. Rebuild this older project to add hover/click details.');
  const populationDestinationsPath = path.join(townDirectory, 'data', 'population_destinations.json');
  if (fs.existsSync(populationDestinationsPath)) {
    try {
      const destinationData = JSON.parse(fs.readFileSync(populationDestinationsPath, 'utf8'));
      if (destinationData.kind !== 'osm_population_destinations' || !Array.isArray(destinationData.destinations)) errors.push('data/population_destinations.json is invalid.');
      if (destinationData.source_attribution !== '© OpenStreetMap contributors') errors.push('Population destinations are missing their OpenStreetMap attribution.');
    } catch { errors.push('data/population_destinations.json is not valid JSON.'); }
  } else if (fs.existsSync(path.join(townDirectory, 'data', 'navigation_graphs.json'))) {
    warnings.push('Population destinations have not been generated yet. Rebuild this project to add map-derived NPC and NPR trips.');
  }
  const settingsPath = path.join(townDirectory, 'game_settings.json');
  if (!fs.existsSync(settingsPath)) errors.push('game_settings.json is missing.');
  else {
    try {
      const settingsValidation = validateGameSettings(JSON.parse(fs.readFileSync(settingsPath, 'utf8')));
      errors.push(...settingsValidation.errors);
      warnings.push(...settingsValidation.warnings);
    } catch { errors.push('game_settings.json is not valid JSON.'); }
  }
  const runtimeProfilePath = path.join(townDirectory, 'runtime_profile.json');
  if (!fs.existsSync(runtimeProfilePath)) errors.push('runtime_profile.json is missing.');
  return {
    schema_version: SCHEMA_VERSION,
    passed: errors.length === 0,
    errors,
    warnings,
    checks: {
      town_file: Boolean(town),
      source_files: !errors.some(error => error.startsWith('Source file')),
      feature_index: fs.existsSync(featureIndexPath),
      map_overrides: fs.existsSync(mapOverridesPath) && !errors.some(error => error.includes('map_overrides')),
      building_exteriors: fs.existsSync(buildingExteriorsPath) && !errors.some(error => error.includes('building_exteriors') || error.includes('custom building exterior')),
      building_interiors: fs.existsSync(buildingInteriorsPath) && !errors.some(error => error.includes('building_interiors')),
      personas: fs.existsSync(personasPath) && !errors.some(error => error.includes('personas.json') || error.includes('Persona')),
      town_knowledge: fs.existsSync(townKnowledgePath) && !errors.some(error => error.includes('town_knowledge')),
      place_information: fs.existsSync(placeInformationPath) && !errors.some(error => error.includes('place_information') || error.includes('OpenStreetMap attribution')),
      population_destinations: fs.existsSync(populationDestinationsPath) && !errors.some(error => error.includes('population_destinations') || error.includes('Population destinations')),
      building_collisions: fs.existsSync(buildingCollisionsPath) && !errors.some(error => error.includes('building_collisions')),
      game_settings: fs.existsSync(settingsPath) && !errors.some(error => error.includes('settings')),
      runtime_profile: fs.existsSync(runtimeProfilePath)
    }
  };
}

function migrateNpcAnimation(settings) {
  // Preserve all unrelated choices and reject invalid values during validation.
  const art = settings.character_art;
  if (art && typeof art === 'object' && !Array.isArray(art)) {
    for (const key of ['npc_type','player_type']) {
      if (art[key] === undefined || ['static','animated'].includes(art[key])) art[key] = 'animated';
    }
  }
}

function getGameSettings(options) {
  if (!options.town) throw new Error('--town is required.');
  const townDirectory = path.resolve(String(options.town));
  const settings = JSON.parse(fs.readFileSync(path.join(townDirectory, 'game_settings.json'), 'utf8'));
  const defaults = recommendedGameSettings();
  if (!settings.road_rules) settings.road_rules = defaults.road_rules;
  settings.population = { ...defaults.population, ...(settings.population || {}) };
  settings.camera = { ...defaults.camera, ...(settings.camera || {}) };
  if (!Object.hasOwn(settings, 'character_art')) settings.character_art = defaults.character_art;
  migrateNpcAnimation(settings);
  settings.driving = { ...defaults.driving, ...(settings.driving || {}) };
  settings.skin_tone_distribution = migrateSkinTones(settings.skin_tone_distribution, defaults.skin_tone_distribution);
  delete settings.community_representation;
  return { ok: true, town_directory: townDirectory, settings, validation: validateGameSettings(settings) };
}

function updateGameSettings(options) {
  if (!options.town) throw new Error('--town is required.');
  const townDirectory = path.resolve(String(options.town));
  const settingsPath = path.join(townDirectory, 'game_settings.json');
  if (!fs.existsSync(path.join(townDirectory, 'town.json'))) throw new Error('Choose a town project folder containing town.json.');
  const settings = fs.existsSync(settingsPath) ? JSON.parse(fs.readFileSync(settingsPath, 'utf8')) : recommendedGameSettings();
  const defaults = recommendedGameSettings();
  if (!settings.road_rules) settings.road_rules = defaults.road_rules;
  settings.population = { ...defaults.population, ...(settings.population || {}) };
  settings.camera = { ...defaults.camera, ...(settings.camera || {}) };
  if (!Object.hasOwn(settings, 'character_art')) settings.character_art = defaults.character_art;
  migrateNpcAnimation(settings);
  settings.driving = { ...defaults.driving, ...(settings.driving || {}) };
  settings.skin_tone_distribution = migrateSkinTones(settings.skin_tone_distribution, defaults.skin_tone_distribution);
  delete settings.community_representation;
  const fields = {
    'traffic-car-count': ['population', 'traffic_car_count', true],
    'pedestrian-count': ['population', 'pedestrian_count', true],
    'cbd-car-percent': ['population', 'cbd_car_percent', true],
    'cbd-pedestrian-percent': ['population', 'cbd_pedestrian_percent', true],
    'robot-count': ['population', 'robot_count', true],
    'cbd-robot-percent': ['population', 'cbd_robot_percent', true],
    'drone-count': ['population', 'drone_count', true],
    'cbd-drone-percent': ['population', 'cbd_drone_percent', true],
    'max-speed-kmh': ['driving', 'max_speed_kmh', false],
    'forward-speed': ['driving', 'forward_speed', false],
    'reverse-speed': ['driving', 'reverse_speed', false],
    'acceleration': ['driving', 'acceleration', false],
    'brake-deceleration': ['driving', 'brake_deceleration', false],
    'steering-rate': ['driving', 'steering_rate', false],
    'character-zoom': ['camera', 'character_zoom', false],
    'camera-zoom': ['driving', 'camera_zoom_multiplier', false],
    'in-car-zoom': ['driving', 'camera_zoom_multiplier', false],
    'jam-timeout': ['traffic_recovery', 'jam_timeout_seconds', false]
  };
  let changed = 0;
  for (const [optionName, [group, key, integer]] of Object.entries(fields)) {
    if (!(optionName in options)) continue;
    const value = Number(options[optionName]);
    if (!Number.isFinite(value) || (integer && !Number.isInteger(value))) throw new Error(`--${optionName} needs ${integer ? 'a whole' : 'a'} number.`);
    settings[group][key] = value;
    changed++;
  }
  if ('jam-recovery' in options) {
    const text = String(options['jam-recovery']).toLowerCase();
    if (!['on', 'off', 'true', 'false'].includes(text)) throw new Error('--jam-recovery must be on or off.');
    settings.traffic_recovery.enabled = text === 'on' || text === 'true';
    changed++;
  }
  if ('driving-side' in options) {
    const side = String(options['driving-side']).toLowerCase();
    if (!['left', 'right'].includes(side)) throw new Error('--driving-side must be left or right.');
    settings.road_rules.driving_side = side;
    changed++;
  }
  for (const [optionName,field] of [['npc-type','npc_type'],['player-type','player_type']]) {
    if (!(optionName in options)) continue;
    const value=String(options[optionName]).toLowerCase();
    const allowed = ['animated'];
    if (!allowed.includes(value)) throw new Error(`--${optionName} must be ${allowed.join(' or ')}.`);
    settings.character_art[field]=value; changed++;
  }
  if ('skin-tone' in options) {
    const allowedTones = new Set(Object.keys(recommendedGameSettings().skin_tone_distribution));
    for (const assignment of options['skin-tone']) {
      const [shortName, rawValue, ...extra] = String(assignment).split('=');
      const key = `${shortName}_percent`;
      if (extra.length || rawValue === undefined || !allowedTones.has(key)) {
        throw new Error('--skin-tone must use TONE=PERCENT. Use light, medium, or dark.');
      }
      const value = Number(rawValue);
      if (!Number.isFinite(value)) throw new Error('--skin-tone percentages must be numbers.');
      settings.skin_tone_distribution[key] = value;
      changed++;
    }
  }
  if ('equalize-skin-tones' in options) {
    settings.skin_tone_distribution = recommendedGameSettings().skin_tone_distribution;
    changed++;
  }
  if (!changed) throw new Error('Provide at least one setting to change. Use help to see the supported names.');
  const validation = validateGameSettings(settings);
  if (!validation.passed) throw new Error(validation.errors[0]);
  writeJson(settingsPath, settings);
  return { ok: true, town_directory: townDirectory, changed_fields: changed, settings, validation };
}

function inspectTown(options) {
  if (!options.town) throw new Error('--town is required.');
  const townDirectory = path.resolve(String(options.town));
  const town = JSON.parse(fs.readFileSync(path.join(townDirectory, 'town.json'), 'utf8'));
  const validation = validateTownDirectory(townDirectory);
  const placeInformationPath = path.join(townDirectory, 'data', 'place_information.json');
  const placeInformation = fs.existsSync(placeInformationPath) ? JSON.parse(fs.readFileSync(placeInformationPath, 'utf8')) : {};
  const populationDestinationsPath = path.join(townDirectory, 'data', 'population_destinations.json');
  const populationDestinations = fs.existsSync(populationDestinationsPath) ? JSON.parse(fs.readFileSync(populationDestinationsPath, 'utf8')) : {};
  const personasPath = path.join(townDirectory, 'data', 'personas.json');
  const personas = fs.existsSync(personasPath) ? JSON.parse(fs.readFileSync(personasPath, 'utf8')) : null;
  const knowledgePath = path.join(townDirectory, 'data', 'town_knowledge.json');
  const townKnowledge = fs.existsSync(knowledgePath) ? JSON.parse(fs.readFileSync(knowledgePath, 'utf8')) : null;
  return {
    ok: true, town_directory: townDirectory, town, validation,
    place_information: placeInformation.statistics ? {
      statistics: placeInformation.statistics,
      source_attribution: placeInformation.source_attribution
    } : null,
    population_destinations: populationDestinations.statistics ? {
      statistics: populationDestinations.statistics,
      source_attribution: populationDestinations.source_attribution
    } : null,
    personas: personas ? { provider: personas.provider, count: personas.personas?.length || 0 } : null,
    town_knowledge: townKnowledge ? {
      wikipedia_url: townKnowledge.wikipedia?.url || '',
      cached_wikipedia_title: townKnowledge.wikipedia?.title || '',
      custom_text_file: townKnowledge.custom_text?.original_filename || ''
    } : null
  };
}

function listPersonas(options) {
  if (!options.town) throw new Error('--town is required.');
  const townDirectory = path.resolve(String(options.town));
  const filePath = path.join(townDirectory, 'data', 'personas.json');
  const data = fs.existsSync(filePath) ? JSON.parse(fs.readFileSync(filePath, 'utf8')) : recommendedPersonas();
  const validation = validatePersonaLibrary(data);
  if (!validation.passed) throw new Error(validation.errors[0]);
  return { ok: true, town_directory: townDirectory, saved: fs.existsSync(filePath), provider: data.provider, personas: data.personas, validation };
}

function showTownKnowledge(options) {
  if (!options.town) throw new Error('--town is required.');
  const townDirectory = path.resolve(String(options.town));
  const filePath = path.join(townDirectory, 'data', 'town_knowledge.json');
  const data = fs.existsSync(filePath) ? JSON.parse(fs.readFileSync(filePath, 'utf8')) : recommendedTownKnowledge();
  const validation = validateTownKnowledge(data);
  if (!validation.passed) throw new Error(validation.errors[0]);
  return { ok: true, town_directory: townDirectory, saved: fs.existsSync(filePath), town_knowledge: data, validation };
}

function inspectBuilding(options) {
  if (!options.town) throw new Error('--town is required.');
  if (!options['feature-id']) throw new Error('--feature-id is required. Select the OSM building ID shown by Creator Studio.');
  const townDirectory = path.resolve(String(options.town));
  const placeInformationPath = path.join(townDirectory, 'data', 'place_information.json');
  if (!fs.existsSync(placeInformationPath)) throw new Error('Building information has not been generated. Rebuild this project in Creator Studio first.');
  const placeInformation = JSON.parse(fs.readFileSync(placeInformationPath, 'utf8'));
  const featureId = String(options['feature-id']);
  const building = (placeInformation.places || []).find(place => String(place.feature_id) === featureId);
  if (!building) throw new Error(`No building information was found for feature ${featureId}.`);
  return { ok: true, town_directory: townDirectory, building };
}

function listTowns(options) {
  if (!options.workspace) throw new Error('--workspace is required.');
  const workspace = path.resolve(String(options.workspace));
  if (!fs.existsSync(workspace)) return { ok: true, workspace, towns: [] };
  const towns = fs.readdirSync(workspace, { withFileTypes: true }).filter(entry => entry.isDirectory()).flatMap(entry => {
    const filePath = path.join(workspace, entry.name, 'town.json');
    if (!fs.existsSync(filePath)) return [];
    try {
      const town = JSON.parse(fs.readFileSync(filePath, 'utf8'));
      return [{ id: town.id, display_name: town.display_name, directory: path.dirname(filePath), schema_version: town.schema_version }];
    } catch { return []; }
  });
  return { ok: true, workspace, towns };
}

function help() {
  return `2D Digital World Twin Creator CLI v${CREATOR_VERSION}

Commands:
  import-town  --name NAME --workspace DIR --osm FILE [--osm FILE] --cbd W,S,E,N --start LON,LAT [--json]
  validate-town --town DIR [--json]
  inspect-town  --town DIR [--json]
  inspect-building --town DIR --feature-id OSM_ID [--json]
  list-personas  --town DIR [--json]
  show-town-knowledge --town DIR [--json]
  list-towns    --workspace DIR [--json]
  get-settings  --town DIR [--json]
  get-tree-settings --town DIR [--json]
  set-tree-style --town DIR --style mapped|broadleaf|eucalypt|conifer|CUSTOM_ID [--json]
  set-settings  --town DIR [--traffic-car-count N] [--pedestrian-count N]
                [--cbd-car-percent N] [--cbd-pedestrian-percent N]
                [--robot-count N] [--cbd-robot-percent N]
                [--drone-count N] [--cbd-drone-percent N]
                [--max-speed-kmh N] [--acceleration N]
                [--brake-deceleration N] [--steering-rate N]
                [--character-zoom N] [--in-car-zoom N]
                [--jam-recovery on|off] [--jam-timeout N] [--json]
                [--driving-side left|right]
                [--npc-type animated] [--player-type animated]
                [--skin-tone TONE=PERCENT] (repeat for multiple tones)
                [--equalize-skin-tones]

Skin tone names: light, medium, dark. Values must total 100.

The CLI and Creator Studio GUI use the same documented content-pack files.
The CLI can inspect persona and town-knowledge data but never contacts Wikipedia or invokes the local LLM.`;
}

function printResult(result, asJson) {
  if (asJson) console.log(JSON.stringify(result));
  else if (typeof result === 'string') console.log(result);
  else console.log(JSON.stringify(result, null, 2));
}

function main() {
  const [command = 'help', ...values] = process.argv.slice(2);
  const options = parseArguments(values);
  try {
    let result;
    if (command === 'import-town') result = importTown(options);
    else if (command === 'validate-town') result = { ok: true, town_directory: path.resolve(String(options.town || '')), validation: validateTownDirectory(options.town || '') };
    else if (command === 'inspect-town') result = inspectTown(options);
    else if (command === 'inspect-building') result = inspectBuilding(options);
    else if (command === 'list-personas') result = listPersonas(options);
    else if (command === 'show-town-knowledge') result = showTownKnowledge(options);
    else if (command === 'list-towns') result = listTowns(options);
    else if (command === 'get-settings') result = getGameSettings(options);
    else if (command === 'get-tree-settings') result = getTreeSettings(options);
    else if (command === 'set-tree-style') result = setTreeStyle(options);
    else if (command === 'set-settings') result = updateGameSettings(options);
    else if (command === 'help' || command === '--help' || command === '-h') result = help();
    else throw new Error(`Unknown command: ${command}`);
    printResult(result, Boolean(options.json));
    if (result.validation && !result.validation.passed) process.exitCode = 1;
  } catch (error) {
    const result = { ok: false, error: error.message };
    if (options.json) console.error(JSON.stringify(result)); else console.error(`Creator Studio: ${error.message}`);
    process.exitCode = 1;
  }
}

if (require.main === module) main();
module.exports = { parseOsmFiles, buildBuildingCollisions, buildPlaceInformation, describeBuildingFeature, importTown, validateTownDirectory, inspectBuilding, listTowns, listPersonas, recommendedPersonas, validatePersonaLibrary, showTownKnowledge, recommendedTownKnowledge, validateTownKnowledge, recommendedGameSettings, validateGameSettings, getGameSettings, updateGameSettings, createStartingLocation, validateStartingLocation, distanceToFixedFootprints };
module.exports.validateGameLore = validateGameLore;
module.exports.validateEnvironmentSettings = validateEnvironmentSettings;
module.exports.getTreeSettings = getTreeSettings;
module.exports.setTreeStyle = setTreeStyle;
