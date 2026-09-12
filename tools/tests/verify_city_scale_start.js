'use strict';

const assert = require('assert');
const { createStartingLocation } = require('../creator-cli.js');

// A synthetic city-scale check using New York-like coordinates. The feature
// count, not the city name, is what exercises the generic search algorithm.
const features = [];
for (let index = 0; index < 100000; index++) {
  const longitude = -75 + (index % 500) * 0.00003;
  const latitude = 40 + Math.floor(index / 500) * 0.00003;
  features.push({
    id: `building_${index}`,
    kind: 'building',
    points: [
      [longitude, latitude], [longitude + 0.00001, latitude],
      [longitude + 0.00001, latitude + 0.00001], [longitude, latitude + 0.00001],
      [longitude, latitude]
    ]
  });
}
for (let index = 0; index < 50000; index++) {
  const longitude = -74.4 + (index % 500) * 0.00002;
  const latitude = 40.6 + Math.floor(index / 500) * 0.00002;
  features.push({ id: `road_${index}`, kind: 'road', points: [[longitude, latitude], [longitude + 0.00001, latitude + 0.00001]] });
}
features.push({ id: 'nearby_road', kind: 'road', points: [[-73.9902, 40.75], [-73.989, 40.75]] });

const startedAt = Date.now();
const result = createStartingLocation({ longitude: -73.99, latitude: 40.75 }, features);
const elapsedMilliseconds = Date.now() - startedAt;
assert.strictEqual(result.ok, true);
assert(result.starting_location.vehicle);
assert(elapsedMilliseconds < 2000, `City-scale start search took ${elapsedMilliseconds} ms`);
console.log(JSON.stringify({ passed: true, features: features.length, elapsed_milliseconds: elapsedMilliseconds }));
