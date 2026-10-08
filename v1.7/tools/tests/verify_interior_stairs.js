'use strict';
const assert = require('assert');
const fs = require('fs');
const path = require('path');
const os = require('os');
const {spawnSync} = require('child_process');
const {validateInteriorStairs} = require('../interiors/validate-stairs');
const {validateTownDirectory} = require('../creator-cli');
const floor = (id,level) => ({id,name:id,level,width_metres:20,height_metres:16,footprint_scale:1,boundary_metres:[[0,0],[20,0],[20,16],[0,16]],holes_metres:[],walls:[],furniture:[],entry_links:[]});
const record = {feature_id:'test',floors:[floor('ground_floor',0),floor('floor_1',1)],stairs:[{id:'stairs_1',from:{floor_id:'ground_floor',x_metres:6,y_metres:9},to:{floor_id:'floor_1',x_metres:6,y_metres:9}}]};
let checks=0;
function expect(value, expected) { assert.strictEqual(validateInteriorStairs(value),expected); checks++; }
expect({feature_id:'test',floors:record.floors},true);
expect(record,true);
function reject(change) { const changed=structuredClone(record); change(changed); expect(changed,false); }
reject(r=>r.stairs[0].to.floor_id='missing');
reject(r=>r.stairs[0].to.floor_id='ground_floor');
reject(r=>r.stairs[0].to.x_metres=Infinity);
reject(r=>r.stairs[0].to.x_metres='6');
reject(r=>r.stairs[0].to.x_metres=0.5);
reject(r=>r.stairs[0].to=null);
reject(r=>r.stairs.push(structuredClone(r.stairs[0])));
reject(r=>r.stairs.push({...structuredClone(r.stairs[0]),id:'overlapping'}));
reject(r=>r.floors[1].holes_metres=[[[5.8,8.8],[6.2,8.8],[6.2,9.2],[5.8,9.2]]]);
reject(r=>r.floors[1].walls=[{start_x_metres:5.5,start_y_metres:7,end_x_metres:5.5,end_y_metres:11,thickness_metres:0.18}]);
reject(r=>r.floors[1].furniture=[{x_metres:6,y_metres:9,width_metres:1,depth_metres:2,rotation_degrees:35}]);
reject(r=>r.floors[1].entry_links=[{spawn_x_metres:6,spawn_y_metres:9}]);
reject(r=>r.floors[1].boundary_metres=[[0,0],[20,0],[20,16],[6.1,16],[6.1,8],[5.9,8],[5.9,16],[0,16]]);
const separate=structuredClone(record);
const turned=structuredClone(record);
turned.stairs[0].from.rotation_degrees=90;
turned.stairs[0].to.rotation_degrees=45;
expect(turned,true);
reject(r=>r.stairs[0].from.rotation_degrees=-1);
reject(r=>r.stairs[0].to.rotation_degrees=360);
reject(r=>r.stairs[0].to.rotation_degrees='90');
separate.stairs.push({id:'stairs_2',from:{floor_id:'ground_floor',x_metres:12,y_metres:9},to:{floor_id:'floor_1',x_metres:12,y_metres:9}});
expect(separate,true);
const cli=path.resolve(__dirname,'../creator-cli.js');
const temporary=fs.mkdtempSync(path.join(os.tmpdir(),'world-twin-stairs-'));
const imported=spawnSync(process.execPath,[cli,'import-town','--name','Stairs CLI test','--workspace',temporary,'--osm',path.join(__dirname,'fixtures/tiny_town.osm'),'--cbd','146.002,-36.007,146.008,-36.003','--start','146.007,-36.0035','--json'],{encoding:'utf8'});
assert.strictEqual(imported.status,0,imported.stderr);
const town=path.join(temporary,'stairs_cli_test');
const metadata=path.join(town,'data/building_interiors.json');
fs.writeFileSync(metadata,JSON.stringify({schema_version:1,kind:'creator_building_interiors',buildings:{test:record}}));
assert(!validateTownDirectory(town).errors.some(e=>e.includes('building_interiors'))); checks++;
// New built-in bathroom IDs must also be accepted by the non-interactive tool.
const bathroom=structuredClone(record);
bathroom.floors[0].flooring={cell_size_metres:0.5,cells:{'2:2':'floor_bathroom_ceramic','3:2':'floor_bathroom_slate','4:2':'floor_bathroom_checker'}};
for (const [index,id] of ['toilet_cubicle','toilet_cubicle_grey','wall_urinal','trough_urinal'].entries()) {
  bathroom.floors[0].furniture.push({id:`fixture_${index}`,catalog_id:id,x_metres:3+index*3,y_metres:3,width_metres:1.2,depth_metres:1.6,rotation_degrees:0,collision:true,object_type:id});
}
fs.writeFileSync(metadata,JSON.stringify({schema_version:1,kind:'creator_building_interiors',buildings:{test:bathroom}}));
assert(!validateTownDirectory(town).errors.some(e=>e.includes('building_interiors')),JSON.stringify(validateTownDirectory(town).errors)); checks++;
const bad=structuredClone(record); bad.stairs[0].to.floor_id='missing';
fs.writeFileSync(metadata,JSON.stringify({schema_version:1,kind:'creator_building_interiors',buildings:{test:bad}}));
assert(validateTownDirectory(town).errors.some(e=>e.includes('stairs'))); checks++;
// Keep these explicitly temporary fixtures for inspection; no user map writes.
console.log(JSON.stringify({passed:true,checks,temporary_town:town}));
