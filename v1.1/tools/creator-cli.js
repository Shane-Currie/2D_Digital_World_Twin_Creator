#!/usr/bin/env node
'use strict';

// Codex-friendly companion to Creator Studio. It reads and writes the same JSON
// content packs as the GUI and intentionally has no local-LLM development tools.
const fs = require('fs');
const path = require('path');
const landCoverRules = require('../scripts/land_cover/rules.json').rules;
function landCoverCategory(tags) {
  if (['layer', 'level'].some(key => Number.isFinite(Number(tags[key])) && Number(tags[key]) !== 0)) return '';
  if (['bridge', 'tunnel', 'indoor'].some(key => !['', 'no', 'false', '0'].includes(String(tags[key] || '').toLowerCase()))) return '';
  if (String(tags.location || '').toLowerCase() === 'underground') return '';
  return landCoverRules.find(rule => Object.entries(rule.tags).some(([key, values]) => values.includes(String(tags[key] || '').toLowerCase())))?.category || '';
}

const CREATOR_VERSION = '1.1';
const SCHEMA_VERSION = 1;
const REQUIRED_RUNTIME_FEATURES = [
  'walking_player', 'player_driven_wagon', 'npc_pedestrians', 'npc_traffic',
  'traffic_signals_and_intersections', 'traffic_jam_recovery', 'cbd_population_targets',
  'osm_roads_and_buildings', 'building_collisions', 'venues_and_interiors',
  'property_boundaries', 'breakable_fences', 'camera_and_minimap', 'saveable_game_settings',
  'not_playable_robots', 'non_playable_drones', 'aerial_navigation', 'grass_and_surface_tracks'
];

function recommendedGameSettings() {
  const equalSkinToneShare = 100 / 7;
  return {
    schema_version: SCHEMA_VERSION,
    population: {
      traffic_car_count: 150, pedestrian_count: 150, cbd_car_percent: 65, cbd_pedestrian_percent: 65,
      robot_count: 20, cbd_robot_percent: 100, drone_count: 10, cbd_drone_percent: 90
    },
    road_rules: { driving_side: 'left' },
    skin_tone_distribution: {
      very_light_percent: equalSkinToneShare, light_percent: equalSkinToneShare,
      medium_light_percent: equalSkinToneShare, medium_percent: equalSkinToneShare,
      medium_dark_percent: equalSkinToneShare, dark_percent: equalSkinToneShare,
      very_dark_percent: equalSkinToneShare
    },
    driving: {
      forward_speed: 108, reverse_speed: 36, acceleration: 42, reverse_acceleration: 70,
      coast_deceleration: 30, brake_deceleration: 140, steering_rate: 1.9, camera_zoom_multiplier: 0.8
    },
    traffic_recovery: {
      enabled: true, jam_timeout_seconds: 30, recovery_spacing_seconds: 2,
      respawn_distance_pixels: 800, respawn_attempts: 24
    }
  };
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

function isWaterArea(tags) {
  return String(tags.natural || '').toLowerCase() === 'water'
    || Object.hasOwn(tags, 'water')
    || String(tags.landuse || '').toLowerCase() === 'reservoir'
    || String(tags.waterway || '').toLowerCase() === 'riverbank'
    || String(tags.leisure || '').toLowerCase() === 'swimming_pool';
}

function areaKind(tags) {
  if (Object.hasOwn(tags, 'building')) return String(tags.building).toLowerCase() === 'roof' ? 'overhead_structure' : 'building';
  return isWaterArea(tags) ? 'water' : (landCoverCategory(tags) ? 'land_cover' : null);
}

function wayKind(tags, closed) {
  if (Object.hasOwn(tags, 'building')) return String(tags.building).toLowerCase() === 'roof' ? 'overhead_structure' : 'building';
  if (Object.hasOwn(tags, 'highway')) return 'road';
  if (closed && isWaterArea(tags)) return 'water';
  if (closed && landCoverCategory(tags)) return 'land_cover';
  if (['river', 'stream', 'canal', 'drain', 'ditch'].includes(String(tags.waterway || '').toLowerCase())) return 'waterway';
  if (String(tags.natural || '').toLowerCase() === 'coastline') return 'coastline';
  return null;
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
  let buildings = 0, roads = 0, waterAreas = 0, waterways = 0, overheadStructures = 0;
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
    if (['building', 'overhead_structure', 'water', 'land_cover'].includes(kind) && relationMemberWays.has(`${way.id}:${kind}${kind === 'land_cover' ? ':' + landCoverCategory(way.tags) : ''}`)) continue;
    if (kind === 'land_cover' && way.nodeIds.some(id => !nodes.has(id))) {
      warnings.push(`Land cover way ${way.id} has missing boundary points and was omitted.`);
      continue;
    }
    const points = way.nodeIds.map(id => nodes.get(id)).filter(Boolean);
    if (points.length < (['building', 'overhead_structure', 'water'].includes(kind) ? 3 : 2)) continue;
    for (const [longitude, latitude] of points) {
      west = Math.min(west, longitude); east = Math.max(east, longitude);
      south = Math.min(south, latitude); north = Math.max(north, latitude);
    }
    if (kind === 'building') buildings++;
    else if (kind === 'overhead_structure') overheadStructures++;
    else if (kind === 'water') waterAreas++;
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
  if (!features.length) throw new Error('No building footprints or roads were found in the selected files.');
  return {
    features,
    bounds: declaredBounds || { west, south, east, north },
    statistics: {
      source_files: filePaths.length, osm_nodes: nodes.size, osm_ways: ways.size, osm_relations: relations.size,
      buildings, roads, water_areas: waterAreas, linear_waterways_and_coastlines: waterways,
      land_cover_areas: landCoverAreas,
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
  let sourceFootprints = 0, skippedInvalid = 0, estimatedConvexPieces = 0;
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
      source: 'osm_footprint'
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
      skipped_invalid: skippedInvalid, estimated_convex_pieces: estimatedConvexPieces,
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
    if (!['building', 'fixed_footprint'].includes(feature.kind) || feature.points.length < 3) continue;
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
    if (!['building', 'fixed_footprint'].includes(feature.kind) || feature.points.length < 3) continue;
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
  check(settings?.driving, 'forward_speed', 1, 400, 'Forward speed');
  check(settings?.driving, 'reverse_speed', 1, 200, 'Reverse speed');
  check(settings?.driving, 'acceleration', 1, 400, 'Acceleration');
  check(settings?.driving, 'reverse_acceleration', 1, 400, 'Reverse acceleration');
  check(settings?.driving, 'coast_deceleration', 1, 400, 'Coasting slowdown');
  check(settings?.driving, 'brake_deceleration', 1, 800, 'Brake strength');
  check(settings?.driving, 'steering_rate', 0.1, 8, 'Steering speed');
  check(settings?.driving, 'camera_zoom_multiplier', 0.2, 2, 'Driving camera zoom');
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
      osm_water_placement: 'ready',
      bridge_water_crossings: 'ready',
      tunnel_layer_metadata: 'ready',
      navigation_graphs: 'requires_godot_build'
    },
    preview_limitations: [
      'ambiguous_or_missing_osm_water_geometry_requires_a_complete_export_or_future_map_editor_override',
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
      building_collisions: fs.existsSync(buildingCollisionsPath) && !errors.some(error => error.includes('building_collisions')),
      game_settings: fs.existsSync(settingsPath) && !errors.some(error => error.includes('settings')),
      runtime_profile: fs.existsSync(runtimeProfilePath)
    }
  };
}

function getGameSettings(options) {
  if (!options.town) throw new Error('--town is required.');
  const townDirectory = path.resolve(String(options.town));
  const settings = JSON.parse(fs.readFileSync(path.join(townDirectory, 'game_settings.json'), 'utf8'));
  const defaults = recommendedGameSettings();
  if (!settings.road_rules) settings.road_rules = defaults.road_rules;
  settings.population = { ...defaults.population, ...(settings.population || {}) };
  if (!settings.skin_tone_distribution || Object.keys(defaults.skin_tone_distribution).some(key => !(key in settings.skin_tone_distribution))) settings.skin_tone_distribution = defaults.skin_tone_distribution;
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
  if (!settings.skin_tone_distribution || Object.keys(defaults.skin_tone_distribution).some(key => !(key in settings.skin_tone_distribution))) settings.skin_tone_distribution = defaults.skin_tone_distribution;
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
    'forward-speed': ['driving', 'forward_speed', false],
    'reverse-speed': ['driving', 'reverse_speed', false],
    'acceleration': ['driving', 'acceleration', false],
    'brake-deceleration': ['driving', 'brake_deceleration', false],
    'steering-rate': ['driving', 'steering_rate', false],
    'camera-zoom': ['driving', 'camera_zoom_multiplier', false],
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
  if ('skin-tone' in options) {
    const allowedTones = new Set(Object.keys(recommendedGameSettings().skin_tone_distribution));
    for (const assignment of options['skin-tone']) {
      const [shortName, rawValue, ...extra] = String(assignment).split('=');
      const key = `${shortName}_percent`;
      if (extra.length || rawValue === undefined || !allowedTones.has(key)) {
        throw new Error('--skin-tone must use TONE=PERCENT. Use very_light, light, medium_light, medium, medium_dark, dark, or very_dark.');
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
  return { ok: true, town_directory: townDirectory, town, validation };
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
  list-towns    --workspace DIR [--json]
  get-settings  --town DIR [--json]
  set-settings  --town DIR [--traffic-car-count N] [--pedestrian-count N]
                [--cbd-car-percent N] [--cbd-pedestrian-percent N]
                [--robot-count N] [--cbd-robot-percent N]
                [--drone-count N] [--cbd-drone-percent N]
                [--forward-speed N] [--reverse-speed N] [--acceleration N]
                [--brake-deceleration N] [--steering-rate N] [--camera-zoom N]
                [--jam-recovery on|off] [--jam-timeout N] [--json]
                [--driving-side left|right]
                [--skin-tone TONE=PERCENT] (repeat for multiple tones)
                [--equalize-skin-tones]

Skin tone names: very_light, light, medium_light, medium, medium_dark, dark,
                 very_dark. Values must total 100.

The CLI and Creator Studio GUI use the same documented content-pack files.
Local LLMs are not exposed here; they are reserved for NPC dialogue at runtime.`;
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
    else if (command === 'list-towns') result = listTowns(options);
    else if (command === 'get-settings') result = getGameSettings(options);
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
module.exports = { parseOsmFiles, buildBuildingCollisions, importTown, validateTownDirectory, listTowns, recommendedGameSettings, validateGameSettings, getGameSettings, updateGameSettings, createStartingLocation, validateStartingLocation, distanceToFixedFootprints };
