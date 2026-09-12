'use strict';
const assert = require('assert');
const fs = require('fs');
const path = require('path');
const { parseOsmFiles } = require('../creator-cli');
const rules = require('../../scripts/land_cover/rules.json').rules;
const fixture = parseOsmFiles([path.join(__dirname, 'fixtures/land_cover.osm')]);
assert.deepStrictEqual(fixture.features.map(f => String(f.id)).sort(), ['100','104','105','relation:200'].sort());
assert.strictEqual(fixture.warnings.length, 2);
assert.strictEqual(fixture.features.find(f => f.id === 'relation:200').holes.length, 2);
const report = JSON.parse(fs.readFileSync(path.join(__dirname, 'output/land_cover_report.json'), 'utf8'));
for (const map of report.maps) {
  const imported = parseOsmFiles([map.source]);
  const actual = imported.features.filter(f => f.kind === 'land_cover').map(f => ({id:String(f.id), category:rules.find(r => Object.entries(r.tags).some(([k,values]) => values.includes(String(f.tags[k] || '').toLowerCase())))?.category || '', holes:f.holes.length}));
  const ordered = entries => entries.sort((a,b) => a.id.localeCompare(b.id));
  assert.deepStrictEqual(ordered(actual), ordered(map.land_cover));
  assert.strictEqual(imported.statistics.land_cover_areas, map.statistics.land_cover_areas);
  console.log(`CLI/GODOT LAND COVER PARITY PASSED: ${path.basename(map.source)} (${actual.length} areas)`);
}
