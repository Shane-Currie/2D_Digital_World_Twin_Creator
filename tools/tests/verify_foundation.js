'use strict';

const assert = require('assert');
const fs = require('fs');
const os = require('os');
const path = require('path');
const { spawnSync } = require('child_process');

const root = path.resolve(__dirname, '..', '..');
const cli = path.join(root, 'tools', 'creator-cli.js');
const { distanceToFixedFootprints, parseOsmFiles, buildBuildingCollisions } = require(cli);
const fixture = path.join(root, 'tools', 'tests', 'fixtures', 'tiny_town.osm');
const waterFixture = path.join(root, 'tools', 'tests', 'fixtures', 'water_crossings.osm');
const temporaryWorkspace = fs.mkdtempSync(path.join(os.tmpdir(), 'world-twin-creator-'));

function run(argumentsList) {
  const result = spawnSync(process.execPath, [cli, ...argumentsList, '--json'], { encoding: 'utf8' });
  assert.strictEqual(result.status, 0, result.stderr || result.stdout);
  return JSON.parse(result.stdout);
}

try {
  const environmental = parseOsmFiles([waterFixture]);
  assert.strictEqual(environmental.statistics.water_areas, 1);
  assert.strictEqual(environmental.statistics.bridge_roads, 1);
  assert.strictEqual(environmental.statistics.tunnel_roads, 1);
  assert.strictEqual(environmental.statistics.overhead_structures, 1);
  assert.strictEqual(environmental.statistics.unresolved_water_relations, 1);
  const environmentalCollisions = buildBuildingCollisions(environmental.features, environmental.bounds);
  assert.strictEqual(environmentalCollisions.water_areas.length, 1);
  assert.strictEqual(environmentalCollisions.water_crossings.length, 2);
  const verticalCollisionFixture = [
    { id: 'ground', kind: 'building', tags: { building: 'yes' }, points: [[146.001, -36.002], [146.002, -36.002], [146.002, -36.001], [146.001, -36.001], [146.001, -36.002]], holes: [] },
    { id: 'raised', kind: 'building', tags: { building: 'yes', 'building:min_level': '1' }, points: [[146.003, -36.002], [146.004, -36.002], [146.004, -36.001], [146.003, -36.001], [146.003, -36.002]], holes: [] }
  ];
  const verticalCollisions = buildBuildingCollisions(verticalCollisionFixture, { west: 146, south: -36.01, east: 146.01, north: -36 });
  assert.strictEqual(verticalCollisions.buildings.length, 1);
  assert.strictEqual(verticalCollisions.buildings[0].vertical_context, 'ground');
  assert.strictEqual(verticalCollisions.statistics.non_ground_structures, 1);
  const unresolvedWorkspace = path.join(temporaryWorkspace, 'unresolved-water');
  const rejectedWater = spawnSync(process.execPath, [
    cli, 'import-town', '--name', 'Unsafe Water Town', '--workspace', unresolvedWorkspace,
    '--osm', waterFixture, '--cbd', '146.0005,-36.0098,146.0095,-36.0005', '--start', '146.002,-36.003', '--json'
  ], { encoding: 'utf8' });
  assert.notStrictEqual(rejectedWater.status, 0);
  assert(JSON.parse(rejectedWater.stderr).error.includes('incomplete water boundaries'));
  assert(!fs.existsSync(path.join(unresolvedWorkspace, 'unsafe_water_town')));

  const imported = run([
    'import-town', '--name', 'Tiny Test Town', '--workspace', temporaryWorkspace,
    '--osm', fixture, '--cbd', '146.002,-36.007,146.008,-36.003', '--start', '146.007,-36.0035'
  ]);
  assert.strictEqual(imported.ok, true);
  assert.strictEqual(imported.town.id, 'tiny_test_town');
  assert.strictEqual(imported.town.creator_version, '1.2');
  assert.strictEqual(imported.town.statistics.buildings, 1);
  assert.strictEqual(imported.town.statistics.roads, 1);
	assert.strictEqual(imported.town.source.original_files.length, 1);
	assert.strictEqual(imported.town.source.original_files[0], path.resolve(fixture));
  assert(imported.town.starting_location.vehicle, 'A separate vehicle start was not generated');
  assert.notStrictEqual(imported.town.starting_location.vehicle.longitude, imported.town.starting_location.longitude);
  assert.strictEqual(path.dirname(imported.town_directory), temporaryWorkspace, 'The chosen save directory was not respected');
  assert(fs.existsSync(path.join(imported.town_directory, 'town.json')));
  assert(fs.existsSync(path.join(imported.town_directory, 'source_osm', '01_tiny_town.osm')));
  assert(fs.existsSync(path.join(imported.town_directory, 'data', 'map_features.json')));
  assert(fs.existsSync(path.join(imported.town_directory, 'data', 'building_collisions.json')));
  assert(fs.existsSync(path.join(imported.town_directory, 'game_settings.json')));
  assert(fs.existsSync(path.join(imported.town_directory, 'runtime_profile.json')));
  const importedFeatureIndex = JSON.parse(fs.readFileSync(path.join(imported.town_directory, 'data', 'map_features.json'), 'utf8'));
  const importedFeatures = importedFeatureIndex.features;
	assert.strictEqual(importedFeatureIndex.preserves_osm_node_tags, true);
	assert.strictEqual(importedFeatures.find(feature => feature.kind === 'road').node_tags['5'].highway, 'traffic_signals');
  const importedCollisions = JSON.parse(fs.readFileSync(path.join(imported.town_directory, 'data', 'building_collisions.json'), 'utf8'));
  assert.strictEqual(importedCollisions.kind, 'building_collision_index');
  assert.strictEqual(importedCollisions.buildings.length, 1);
  assert(importedCollisions.buildings[0].area_square_metres > 0);
  assert(distanceToFixedFootprints([imported.town.starting_location.longitude, imported.town.starting_location.latitude], importedFeatures) >= 1);
  assert(distanceToFixedFootprints([imported.town.starting_location.vehicle.longitude, imported.town.starting_location.vehicle.latitude], importedFeatures) >= 4);

  const defaultSettings = run(['get-settings', '--town', imported.town_directory]);
  assert.strictEqual(defaultSettings.settings.population.traffic_car_count, 150);
  assert.strictEqual(defaultSettings.settings.population.cbd_car_percent, 65);
  assert.strictEqual(defaultSettings.settings.road_rules.driving_side, 'left');
  assert(Math.abs(defaultSettings.settings.skin_tone_distribution.dark_percent - (100 / 7)) < 0.001);
  assert.strictEqual(defaultSettings.settings.population.robot_count, 20);
  assert.strictEqual(defaultSettings.settings.population.cbd_robot_percent, 100);
  assert.strictEqual(defaultSettings.settings.population.drone_count, 10);
  assert.strictEqual(defaultSettings.settings.population.cbd_drone_percent, 90);
  const changedSettings = run([
    'set-settings', '--town', imported.town_directory,
    '--traffic-car-count', '225', '--pedestrian-count', '175',
    '--cbd-car-percent', '72', '--jam-recovery', 'off', '--driving-side', 'right',
    '--robot-count', '30', '--cbd-robot-percent', '80',
    '--drone-count', '12', '--cbd-drone-percent', '75', '--equalize-skin-tones'
  ]);
  assert.strictEqual(changedSettings.settings.population.traffic_car_count, 225);
  assert.strictEqual(changedSettings.settings.population.pedestrian_count, 175);
  assert.strictEqual(changedSettings.settings.population.cbd_car_percent, 72);
  assert.strictEqual(changedSettings.settings.traffic_recovery.enabled, false);
  assert.strictEqual(changedSettings.settings.road_rules.driving_side, 'right');
  assert.strictEqual(changedSettings.settings.population.robot_count, 30);
  assert.strictEqual(changedSettings.settings.population.cbd_robot_percent, 80);
  assert.strictEqual(changedSettings.settings.population.drone_count, 12);
  assert.strictEqual(changedSettings.settings.population.cbd_drone_percent, 75);
  const rejectedSettings = spawnSync(process.execPath, [
    cli, 'set-settings', '--town', imported.town_directory, '--cbd-car-percent', '101', '--json'
  ], { encoding: 'utf8' });
  assert.notStrictEqual(rejectedSettings.status, 0);
  assert(JSON.parse(rejectedSettings.stderr).error.includes('between 0 and 100'));
  assert.strictEqual(run(['get-settings', '--town', imported.town_directory]).settings.population.cbd_car_percent, 72);
  const rejectedToneTotal = spawnSync(process.execPath, [
    cli, 'set-settings', '--town', imported.town_directory, '--skin-tone', 'dark=40', '--json'
  ], { encoding: 'utf8' });
  assert.notStrictEqual(rejectedToneTotal.status, 0);
  assert(JSON.parse(rejectedToneTotal.stderr).error.includes('must total 100%'));
  assert(Math.abs(run(['get-settings', '--town', imported.town_directory]).settings.skin_tone_distribution.dark_percent - (100 / 7)) < 0.001);

  const unsafeWorkspace = path.join(temporaryWorkspace, 'unsafe');
  const rejectedSpawn = spawnSync(process.execPath, [
    cli, 'import-town', '--name', 'Unsafe Start Town', '--workspace', unsafeWorkspace,
    '--osm', fixture, '--cbd', '146.002,-36.007,146.008,-36.003', '--start', '146.004,-36.005', '--json'
  ], { encoding: 'utf8' });
  assert.notStrictEqual(rejectedSpawn.status, 0);
  assert(JSON.parse(rejectedSpawn.stderr).error.includes('inside or too close to a fixed building'));
  assert(!fs.existsSync(path.join(unsafeWorkspace, 'unsafe_start_town')), 'An unsafe town folder was created');

  const validation = run(['validate-town', '--town', imported.town_directory]);
  assert.strictEqual(validation.validation.passed, true);
  const inspected = run(['inspect-town', '--town', imported.town_directory]);
  assert.strictEqual(inspected.town.display_name, 'Tiny Test Town');
  const listed = run(['list-towns', '--workspace', temporaryWorkspace]);
  assert.deepStrictEqual(listed.towns.map(town => town.id), ['tiny_test_town']);

  const projectText = fs.readFileSync(path.join(root, 'project.godot'), 'utf8');
  assert(projectText.includes('config/name="2D Digital World Twin Creator"'));
  const appText = fs.readFileSync(path.join(root, 'scripts', 'app', 'creator_studio.gd'), 'utf8');
  assert(appText.includes('Choose save directory'));
  assert(appText.includes('Local models are used only'));
  assert(appText.includes('_show_game_settings_page'));
  assert(appText.includes('Restore recommended settings'));
  console.log(JSON.stringify({ passed: true, checks: 76, imported_town: imported.town_directory }));
} finally {
  fs.rmSync(temporaryWorkspace, { recursive: true, force: true });
}
