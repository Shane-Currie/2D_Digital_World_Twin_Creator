'use strict';
const assert=require('assert'), fs=require('fs'), path=require('path'), cp=require('child_process');
const {validateNpcCreations}=require('../npc_creations/validate-npc-creations');
const {validateRig,PARTS,VIEWS}=require('../npc_creations/validate-npc-rig');
const {validateGameSettings,recommendedGameSettings}=require('../creator-cli');
const base=path.resolve(__dirname,'../..');
const directory=path.resolve(process.argv[2]);
const library=JSON.parse(fs.readFileSync(path.join(base,'assets/actors/cutout_v16/library.json')));
let checks=0;
function check(value,message){assert.ok(value,message);checks++;}
check(library.style==='illustrated-cutout' && Object.keys(library.rigs).length===20,'Shared library incomplete');
for(const [id,rig] of Object.entries(library.rigs)){
  check(rig.source_asset===id,'Source identity not stable');
  for(const view of VIEWS)for(const part of PARTS){
    const value=rig.views[view].parts[part];
    check(!value.region && value.image.startsWith('res://assets/actors/cutout_v16/'),'Sliced original art still used');
    check(fs.existsSync(path.join(base,value.image.slice(6))),'Missing separate body part');
  }
}
check(library.appearances.player.skin==='#e8bb94' && library.appearances.player.hair==='#5c3f29' && library.appearances.player.jacket==='#b73e35' && library.appearances.player.trousers==='#376e9b','Player colours incorrect');
const catalogue=JSON.parse(fs.readFileSync(path.join(directory,'data/npc_creations.json')));
check(validateNpcCreations(catalogue,directory).ok,'Godot creation fails Node validation');
const creation=catalogue.creations[0];
const appearance={mode:'custom_creation',template_id:creation.id,npc_asset:'creation_'+creation.id,gender:creation.gender,age_group:creation.age_group,skin_tone_group:creation.skin_tone_group,animation_type:'animated'};
check(validateNpcCreations(catalogue,directory,[{actor_kind:'npc',appearance}]).ok,'Animated placement rejected');
appearance.animation_type='static';check(validateNpcCreations(catalogue,directory,[{actor_kind:'npc',appearance}]).ok,'Legacy placement rejected before migration');
appearance.animation_type='invalid';check(!validateNpcCreations(catalogue,directory,[{actor_kind:'npc',appearance}]).ok,'Invalid override accepted');
const bad=structuredClone(creation.rig);bad.views.front.parts.head.region=[0,0,0,20];
check(!validateRig(bad).ok,'Malformed region accepted');
const settings=recommendedGameSettings();settings.character_art={npc_type:'animated',player_type:'animated'};
check(validateGameSettings(settings).passed,'Valid types rejected');
settings.character_art.player_type='invalid';check(!validateGameSettings(settings).passed,'Invalid type accepted');
settings.character_art=[];check(!validateGameSettings(settings).passed,'Malformed settings accepted');
// Exercise normal CLI mutations only in the disposable Godot fixture.
const cli=path.join(base,'tools/creator-cli.js');
const run=(...args)=>JSON.parse(cp.execFileSync(process.execPath,[cli,...args],{encoding:'utf8'}));
check(run('set-settings','--town',directory,'--npc-type','animated','--player-type','animated').ok,'CLI set types failed');
check(run('get-settings','--town',directory).settings.character_art.player_type==='animated','CLI get loses player type');
check(run('set-settings','--town',directory,'--character-zoom','2.7').ok && run('get-settings','--town',directory).settings.character_art.npc_type==='animated','Unrelated CLI settings reset type');
const saved=JSON.parse(fs.readFileSync(path.join(directory,'game_settings.json')));delete saved.character_art;
fs.writeFileSync(path.join(directory,'game_settings.json'),JSON.stringify(saved));
check(run('get-settings','--town',directory).settings.character_art.npc_type==='animated','Old settings migration failed');
saved.character_art={npc_type:'static',player_type:'static'};
fs.writeFileSync(path.join(directory,'game_settings.json'),JSON.stringify(saved));
const prior=fs.readFileSync(path.join(directory,'game_settings.json'),'utf8');
check(run('get-settings','--town',directory).settings.character_art.player_type==='animated' && fs.readFileSync(path.join(directory,'game_settings.json'),'utf8')===prior,'Legacy player read-only migration failed');
check(run('set-settings','--town',directory,'--character-zoom','2.7').ok && run('get-settings','--town',directory).settings.character_art.npc_type==='animated','Saving legacy settings restores Static NPC');
const beforeRejection=fs.readFileSync(path.join(directory,'game_settings.json'),'utf8');
const rejection=cp.spawnSync(process.execPath,[cli,'set-settings','--town',directory,'--npc-type','static'],{encoding:'utf8'});
check(rejection.status!==0 && fs.readFileSync(path.join(directory,'game_settings.json'),'utf8')===beforeRejection,'Static NPC CLI option accepted or damaged saved settings');
const playerRejection=cp.spawnSync(process.execPath,[cli,'set-settings','--town',directory,'--player-type','static'],{encoding:'utf8'});
check(playerRejection.status!==0 && fs.readFileSync(path.join(directory,'game_settings.json'),'utf8')===beforeRejection,'Static player CLI option accepted or damaged saved settings');
console.log('NODE CUTOUT / ANIMATION TYPES: '+checks+' checks, 0 failures');
