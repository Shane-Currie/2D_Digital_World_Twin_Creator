'use strict';
const assert=require('assert'), fs=require('fs'),path=require('path'),os=require('os');
const {spawnSync}=require('child_process');
const {validateBuildingConnections,sharedSegments,withSourcePrecision}=require('../interiors/validate-building-connections');
const {validateTownDirectory}=require('../creator-cli');
const fixture=JSON.parse(fs.readFileSync(process.argv[2],'utf8'));
let checks=0;
function expect(data,features,valid) {assert.strictEqual(validateBuildingConnections(data,features),valid); checks++;}
expect(fixture.data,fixture.features,true);
const alburyFile=path.join(path.dirname(process.argv[2]),'albury_connection_fixture.json');
if(fs.existsSync(alburyFile)) {
  const albury=JSON.parse(fs.readFileSync(alburyFile,'utf8')); expect(albury.data,albury.features,true);
  const alburyTown=path.resolve(__dirname,'../../../Test Maps/albury/albury');
  if(fs.existsSync(path.join(alburyTown,'data/map_features.json'))) {
    const raw=JSON.parse(fs.readFileSync(path.join(alburyTown,'data/map_features.json'),'utf8')).features;
    const preserved=JSON.stringify(raw), recovered=withSourcePrecision(alburyTown,raw);
    expect(albury.data,recovered,true);
    assert.strictEqual(JSON.stringify(raw),preserved); checks++;
  }
}
expect({buildings:{}},[],true);
function reject(change) {const copy=structuredClone(fixture); change(copy); expect(copy.data,copy.features,false);}
reject(f=>f.data.building_connections[0].to.x_metres=Infinity);
reject(f=>f.data.building_connections[0].to.x_metres='1');
reject(f=>f.data.building_connections[0].to.floor_id='missing');
reject(f=>f.data.building_connections[0].from.building_id='b');
reject(f=>f.data.building_connections[0].locked='false');
reject(f=>f.data.building_connections.push({id:'bad',from:42,to:{}}));
reject(f=>f.data.building_connections.push(structuredClone(f.data.building_connections[0])));
reject(f=>f.features=f.features.filter(feature=>feature.id!=='b'));
reject(f=>f.features[1].points=f.features[1].points.map(([x,y])=>[x+.01/(111320*Math.cos(y*Math.PI/180)),y]));
reject(f=>f.data.buildings.b.floors[0].level=1);
reject(f=>f.data.buildings.b.floors[0].holes_metres=[[[.8,5.8],[1.2,5.8],[1.2,6.2],[.8,6.2]]]);
reject(f=>f.data.buildings.b.floors[0].furniture.push({x_metres:1,y_metres:6,width_metres:1,depth_metres:1,collision:true}));
reject(f=>f.data.buildings.b.floors[0].walls.push({start_x_metres:1,start_y_metres:4,end_x_metres:1,end_y_metres:8,thickness_metres:.18}));
reject(f=>f.data.buildings.b.floors[0].entry_links.push({spawn_x_metres:1,spawn_y_metres:6}));
assert(!validateBuildingConnections(fixture.data,fixture.features,[{location:{space:'interior',building_id:'b',floor_id:'ground_floor',x_metres:1,y_metres:6}}])); checks++;
assert(sharedSegments(...fixture.features).length===1); checks++;
const reversed=structuredClone(fixture.features); reversed[1].points.reverse(); assert(sharedSegments(...reversed).length===1); checks++;
const temporary=fs.mkdtempSync(path.join(os.tmpdir(),'world-twin-connections-'));
const cli=path.resolve(__dirname,'../creator-cli.js');
const imported=spawnSync(process.execPath,[cli,'import-town','--name','Connections CLI test','--workspace',temporary,'--osm',path.join(__dirname,'fixtures/tiny_town.osm'),'--cbd','146.002,-36.007,146.008,-36.003','--start','146.007,-36.0035','--json'],{encoding:'utf8'});
assert.strictEqual(imported.status,0,imported.stderr);
const town=path.join(temporary,'connections_cli_test'), metadata=path.join(town,'data/building_interiors.json'), source=path.join(town,'data/map_features.json');
fs.writeFileSync(metadata,JSON.stringify(fixture.data));
const mapped=JSON.parse(fs.readFileSync(source,'utf8')); mapped.features.push(...fixture.features); fs.writeFileSync(source,JSON.stringify(mapped));
assert(!validateTownDirectory(town).errors.some(e=>e.includes('building_interiors')),JSON.stringify(validateTownDirectory(town).errors)); checks++;
const overrides=path.join(town,'data/map_overrides.json'), original=JSON.parse(fs.readFileSync(overrides,'utf8'));
fs.writeFileSync(overrides,JSON.stringify({...original,hidden_feature_ids:['b']}));
assert(validateTownDirectory(town).errors.some(e=>e.includes('connecting doors'))); checks++;
fs.writeFileSync(overrides,JSON.stringify(original));
mapped.features.find(f=>f.id==='b').points=mapped.features.find(f=>f.id==='b').points.map(([x,y])=>[x+.01/(111320*Math.cos(y*Math.PI/180)),y]);
fs.writeFileSync(source,JSON.stringify(mapped));
assert(validateTownDirectory(town).errors.some(e=>e.includes('connecting doors'))); checks++;
console.log(JSON.stringify({passed:true,checks,temporary_town:town}));
