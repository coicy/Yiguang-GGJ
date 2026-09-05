import fs from 'node:fs/promises';

export async function build(root) {
const {buildNursery} = await import('file:///'+root+'/tools/nursery_room.mjs?v='+Date.now());
const {dressTerrain} = await import('file:///'+root+'/tools/terrain_set_dressing.mjs?v='+Date.now());
const ext=[], shapes=[], nodes=[];
let count=0;
function resource(type,path,id){ext.push('[ext_resource type="'+type+'" path="res://'+path+'" id="'+id+'"]');return 'ExtResource("'+id+'")';}
const R={};
for(const [id,type,file] of [
['skin','Script','features/level/terrain/terrain_skin.gd'],
['style_root_passage','Resource','features/level/terrain/data/root_passage.tres'],
['cutout','ShaderMaterial','features/level/terrain/terrain_cutout.tres'],
['level','Script','features/level/combat/greenhouse_level.gd'],
['phantom_host','Script','addons/phantom_camera/scripts/phantom_camera_host/phantom_camera_host.gd'],
['phantom_camera','Script','addons/phantom_camera/scripts/phantom_camera/phantom_camera_2d.gd'],
['camera_tween','Script','addons/phantom_camera/scripts/resources/tween_resource.gd'],
['player','PackedScene','features/player/player.tscn'],
['terrain','PackedScene','features/level/handbuilt/terrain_piece.tscn'],
['spawn','PackedScene','features/level/handbuilt/spawn_point.tscn'],
['bounds','PackedScene','features/level/handbuilt/camera_bounds.tscn'],
['grow','PackedScene','features/level/nutrition_tank.tscn'],
['toxin','PackedScene','features/level/toxin_resource.tscn'],
['checkpoint','PackedScene','features/level/checkpoint.tscn'],
['switch','PackedScene','features/level/ability_switch.tscn'],
['anchor','PackedScene','features/abilities/vine_anchor.tscn'],
['exit','PackedScene','features/level/exit_goal.tscn'],
['encounter','Script','features/level/combat/encounter_controller.gd'],
['backdrop','Script','features/level/combat/greenhouse_backdrop.gd'],
['feedback','Script','features/combat/combat_feedback.gd'],
['sounds','PackedScene','features/audio/sound_emitter.tscn'],
['hud','PackedScene','features/ui/handbuilt_hud.tscn'],
['combat_hud','PackedScene','features/ui/combat_hud.tscn'],
['moss','Texture2D','assets/runtime/scenery/_0036_苔藓地1.png'],
['steel','Texture2D','assets/runtime/scenery/_0030_锈蚀钢板-.png'],
['branch','Texture2D','assets/runtime/scenery/_0026_树枝平台（延申）.png'],
['grass','Texture2D','assets/runtime/scenery/_0011_高草1.png'],
['root','Texture2D','assets/runtime/scenery/_0006_树根1.png'],
['vine','Texture2D','assets/runtime/scenery/_0021_爬墙藤.png'],
['flowers','Texture2D','assets/runtime/scenery/_0002_红花1.png'],
['tank','Texture2D','assets/runtime/scenery/_0014_培养罐.png'],
['ground_art','Texture2D','assets/runtime/scenery/greenhouse_ground.png'],
['glasshouse_art','Texture2D','assets/runtime/scenery/greenhouse_background.png'],
['font','FontFile','assets/runtime/ui/botanical/NotoSansSC.ttf']
])R[id]=resource(type,file,id);
shapes.push('[sub_resource type="AtlasTexture" id="flat_moss"]\natlas = '+R.ground_art+'\nregion = Rect2(0, 98, 1774, 789)\nfilter_clip = true');
R.flat_moss = 'SubResource("flat_moss")';
shapes.push('[sub_resource type="Resource" id="camera_transition"]\nscript = '+R.camera_tween+'\nduration = 0.35\ntransition = 1\nease = 2');
[["style_nursery","Resource","features/level/terrain/data/nursery.tres"],["style_moss","Resource","features/level/terrain/data/moss.tres"],["style_spore","Resource","features/level/terrain/data/spore.tres"],["style_workshop","Resource","features/level/terrain/data/workshop.tres"],["style_canopy","Resource","features/level/terrain/data/canopy.tres"],["style_courtyard","Resource","features/level/terrain/data/courtyard.tres"],["style_core","Resource","features/level/terrain/data/core.tres"],["part_drain","Texture2D","assets/runtime/terrain/parts/drain.tres"],["part_catwalk","Texture2D","assets/runtime/terrain/parts/catwalk.tres"],["part_culvert","Texture2D","assets/runtime/terrain/parts/culvert.tres"],["part_pipe","Texture2D","assets/runtime/terrain/parts/pipe.tres"],["part_buttress","Texture2D","assets/runtime/terrain/parts/buttress.tres"],["part_core_plinth","Texture2D","assets/runtime/terrain/parts/core_plinth.tres"],["part_root_soil","Texture2D","assets/runtime/terrain/parts/root_soil.tres"],["part_fungal_log","Texture2D","assets/runtime/terrain/parts/fungal_log.tres"],["part_seedling_tray","Texture2D","assets/runtime/terrain/parts/seedling_tray.tres"],["part_broken_planter","Texture2D","assets/runtime/terrain/parts/broken_planter.tres"],["root_support","Texture2D","assets/runtime/scenery/_0025_根部延申.png"],["root_wall","Texture2D","assets/runtime/scenery/branch_wall.png"],["slab_a","Texture2D","assets/runtime/scenery/_0032_底面地板.png"],["slab_b","Texture2D","assets/runtime/scenery/_0034_水泥板.png"],["stone_alt","Texture2D","assets/runtime/scenery/_0029_石板.png"],["slope","Texture2D","assets/runtime/scenery/_0035_草地坡.png"],["hang_a","Texture2D","assets/runtime/scenery/_0040_垂坠1.png"],["hang_b","Texture2D","assets/runtime/scenery/_0041_垂坠2.png"],["tuft_b","Texture2D","assets/runtime/scenery/_0001_草团2.png"],["flower_b","Texture2D","assets/runtime/scenery/_0003_红花2.png"],["grass_low","Texture2D","assets/runtime/scenery/_0022_草皮.png"],["grass_low_b","Texture2D","assets/runtime/scenery/_0023_草皮2.png"],["grass_low_c","Texture2D","assets/runtime/scenery/_0024_草皮.png"],["needle_a","Texture2D","assets/runtime/scenery/_0004_针草1.png"],["needle_b","Texture2D","assets/runtime/scenery/_0005_针草2.png"],["beaker","Texture2D","assets/runtime/scenery/_0016_量杯.png"],["flask_alt","Texture2D","assets/runtime/scenery/_0017_锥形瓶1.png"]].forEach(([id,type,file])=>R[id]=resource(type,file,id));
function node(name,type,parent,props={},instance=null){
let h='[node name="'+name+'"'+(type?' type="'+type+'"':'')+(parent===null?'':' parent="'+parent+'"')+(instance?' instance='+instance:'')+']';
nodes.push(h+'\n'+Object.entries(props).map(([k,v])=>k+' = '+v).join('\n'));
}
function vec(x,y){return 'Vector2('+x+', '+y+')';}
function floor(name,x,y,w,h=70,material='moss',oneway=false){
const mainSkin=name.startsWith('Floor')||name==='CanopyCatch'||name.startsWith('SporeCover')||name==='RootPracticeLedge'||material==='branch';
const style=['SproutTunnel','SproutAlcoveRoof'].includes(name)?'root_passage':material==='branch'?'canopy':name==='CanopyCatch'?'moss':x<760?'nursery':x<2200?'moss':x<3640?'spore':x<5080?'workshop':x<6480?'moss':x<7440?'courtyard':'core';
node(name,null,'Geometry/Terrain',{position:vec(x,y),piece_size:vec(w,h),sprite_variants:'null',show_artwork:String(!mainSkin),art_texture:R[material],art_scale_multiplier:'0.35',tile_art_vertically:'false',art_offset:vec(0,material==='steel'?0:-5),collision_mode:oneway?'1':'0',one_way_collision:String(oneway)},R.terrain);
if(mainSkin)node('Surface','Node2D','Geometry/Terrain/'+name,{script:R.skin,profile:R['style_'+style],span:String(w),depth:String(h),z_index:'-3',pattern_offset:String(Math.abs(Math.floor(x/140))%5)});
}
function wall(name,x,y,w,h,parent='Geometry/Mechanisms',unique=false,artColor='Color(0.24,0.38,0.28,1)'){
const sid='wall'+(++count);shapes.push('[sub_resource type="RectangleShape2D" id="'+sid+'"]\nsize = '+vec(w,h));
node(name,'StaticBody2D',parent,{position:vec(x,y),'collision_layer':'1','collision_mask':'0',...(unique?{unique_name_in_owner:'true'}:{})});
node('CollisionShape2D','CollisionShape2D',parent+'/'+name,{shape:'SubResource("'+sid+'")'});
node('Artwork','Polygon2D',parent+'/'+name,{polygon:'PackedVector2Array('+[-w/2,-h/2,w/2,-h/2,w/2,h/2,-w/2,h/2].join(', ')+')',color:artColor});
}
function sprite(name,asset,x,y,scale,parent='Background',tint='Color(1,1,1,1)'){
node(name,'Sprite2D',parent,{texture:R[asset],position:vec(x,y),scale:vec(scale,scale),modulate:tint});
}
function label(name,text,x,y,size=15,parent='Background'){
node(name,'Label',parent,{visible:'false',offset_left:String(x),offset_top:String(y),text:JSON.stringify(text),'theme_override_colors/font_color':'Color(0.85,0.87,0.68,1)','theme_override_colors/font_shadow_color':'Color(0.07,0.14,0.12,1)','theme_override_constants/shadow_offset_x':'1','theme_override_constants/shadow_offset_y':'1','theme_override_font_sizes/font_size':String(size),mouse_filter:'2'});
}
node('Level01','Node2D',null,{script:R.level});
node('Background','Node2D','.',{z_index:'-20'});
node('Glasshouse','Node2D','Background',{script:R.backdrop,background_texture:R.glasshouse_art,length:'8620.0',floor_y:'400.0'});
node('Geometry','Node2D','.');
node('Terrain','Node2D','Geometry');
node('Mechanisms','Node2D','Geometry');
for(const [x,w,material] of [[760,1440,'moss'],[2200,1440,'moss'],[3640,1440,'steel'],[5080,320,'moss'],[6140,340,'moss'],[6480,960,'steel'],[7440,1180,'steel']])
floor('Floor'+x,x,400,w,x===3640?24:140,material);
wall('LeftBoundary',-150,450,20,510);
await buildNursery({node,resource,R,root});
wall('RightBoundary',8570,200,20,400);

node('SproutSwitch',null,'Geometry/Mechanisms',{unique_name_in_owner:'true',position:vec(196,517),mode:'1',low_profile:'true'},R.switch);
wall('IntroGate',695,300,20,200,'Geometry/Mechanisms',true);

for(const [name,x,y,w] of [
['BeetlePlatformA',1180,340,120],['BeetlePlatformB',1504,340,120],
['WorkshopPlatformB',4770,340,120],['CourtyardPlatform',6560,340,104]])floor(name,x,y,w,8,x>=3640?'steel':'slab_b',true);
for(const [name,x,y,w] of [
['TreeStep',5290,350,140],['CanopyWest',5480,300,120],['CanopyCrown',5660,260,150],['CanopyEast',5880,300,130],['TreeLanding',6090,350,130]])floor(name,x,y,w,20,'branch',true);
floor('SporeCoverA',2320,368,64,32,'slab_b');
floor('SporeCoverB',3040,368,64,32,'slab_b');
floor('CanopyCatch',5300,555,860,80,'moss');
for(const [i,x,y] of [[0,5840,510],[1,5940,465],[2,6040,420]])floor('CatchReturn'+i,x,y,100,12,'branch',true);
floor('SproutAlcoveRoof',5370,486,165,36,'branch');
// Close the non-traversable slit with a visibly continuous root end.
wall('AlcoveBackwall',5393.375,520.5,45.25,69,'Geometry/Mechanisms',false,'Color(0,0,0,0)');
node('SupportEnd','Sprite2D','Geometry/Mechanisms/AlcoveBackwall',{texture:R.part_buttress,material:R.cutout,position:vec(-22.625,-34.5),centered:'false',scale:vec(69/462,69/462)});
floor('ReturnFoundationSeal',6140,540,20,15,'slab_b');
node('Areas','Node2D','.');
function tank(name,x,y,grow=true,form=''){
node(name,null,'Areas',{position:vec(x,y),show_world_prompt:'false',...(grow&&form?{accepted_form_id:'&"'+form+'"'}:{})},grow?R.grow:R.toxin);
}
tank('FirstGrowth',429.43,511.43,true,'sprout');
// The functional source is painted into the first retaining-wall face.
node('TankSprite',null,'Areas/FirstGrowth',{visible:'false'});
shapes.push('[sub_resource type="RectangleShape2D" id="nursery_source_reach"]\nsize = Vector2(96, 48)');
node('CollisionShape2D',null,'Areas/FirstGrowth',{shape:'SubResource("nursery_source_reach")'});
tank('MatureGrowth',5190,385,true);
tank('BranchWither',5600,540,false);
tank('BranchRegrowth',5680,540,true);
tank('CoreGrowth',7190,385,true);
tank('CoreWither',7280,385,false);
node('Checkpoints','Node2D','.');
for(const [name,x,y]of [['Nursery',725,380],['Canopy',5160,380],['Crown',5740,240],['Core',7360,380]]){
node(name,null,'Checkpoints',{position:vec(x,y)},R.checkpoint);
}
node('Actors','Node2D','.');
node('Player',null,'Actors',{unique_name_in_owner:'true',position:vec(35,530)},R.player);
// The bright greenhouse needs a softer flower light than the dark source scene.
node('FlowerLight',null,'Actors/Player/Visuals',{energy:'0.3',texture_scale:'0.72'});
node('Camera2D','Camera2D','.',{unique_name_in_owner:'true',process_mode:'1',position:vec(80,450),zoom:vec(2.5,2.5),position_smoothing_enabled:'false',limit_smoothed:'false'});
node('PhantomCameraHost','Node','Camera2D',{unique_name_in_owner:'true',script:R.phantom_host,interpolation_mode:'2'});
node('PhantomCamera2D','Node2D','.',{unique_name_in_owner:'true',process_mode:'1',script:R.phantom_camera,position:vec(80,450),priority:'10',follow_mode:'5',zoom:vec(2.5,2.5),follow_offset:vec(45,-60),follow_damping:'true',follow_damping_value:vec(.12,.18),dead_zone_width:'0.6',dead_zone_height:'0.52',lookahead:'true',lookahead_time:vec(.2,0),lookahead_max:'true',lookahead_max_value:vec(300,0),tween_resource:'SubResource("camera_transition")',tween_on_load:'false'});
node('EncounterCamera2D','Node2D','.',{unique_name_in_owner:'true',process_mode:'1',script:R.phantom_camera,position:vec(80,450),priority:'0',follow_mode:'0',zoom:vec(2.1,2.1),tween_resource:'SubResource("camera_transition")',tween_on_load:'false'});
node('SpawnPoint',null,'.',{unique_name_in_owner:'true',position:vec(35,530)},R.spawn);
node('CameraBounds',null,'.',{unique_name_in_owner:'true',position:vec(-160,-180),bounds_size:vec(8840,850)},R.bounds);

for(const [i,x,y] of [[0,5540,210],[1,5730,170],[2,5950,210]]){
node('Ring'+i,null,'Geometry/Mechanisms',{position:vec(x,y)},R.anchor);
}
node('Encounters','Node2D','.',{unique_name_in_owner:'true'});
const battles=[
['BeetleIntro','beetle_intro',760,560,'苔藓步道','观察蓄力，跳过冲撞后反击',[['beetle']],2.1],
['BeetlePair','beetle_pair',1480,560,'苔藓步道','连击末段击退 · Shift 闪避',[['beetle','beetle']],2.1],
['SporeIntro','spore_intro',2200,560,'孢子廊','F 弹反孢子，或跳跃接近',[['spore']],2.1],
['SporeMixed','spore_mixed',2920,560,'孢子廊','利用高低差，先处理远程威胁',[['spore','beetle']],2.1],
['PrunerIntro','pruner_intro',3640,560,'修枝车间','右键破防 · F 弹反挥刃',[['pruner']],2.1],
['PrunerMixed','pruner_mixed',4360,560,'修枝车间','绕背、破防与闪避交替使用',[['pruner','beetle']],2.1],
['Quarantine','quarantine',6480,560,'隔离庭院','两轮防线 · 注意远程与近战配合',[['beetle','beetle','spore'],['beetle','spore','pruner']],2.1],
['Warden','warden',7440,720,'温室核心','红叉重砸不可弹反 · 抓住收招',[['warden']],1.65]
];
for(const [name,id,x,width,title,goal,waves,zoom] of battles){
node(name,'Node2D','Encounters',{position:vec(x,400),script:R.encounter,encounter_id:'&"'+id+'"',display_name:JSON.stringify(title),objective:JSON.stringify(goal),arena_size:vec(width,280),camera_zoom:String(zoom),waves:'Array[PackedStringArray](['+waves.map(w=>'PackedStringArray('+w.map(a=>JSON.stringify(a)).join(', ')+')').join(', ')+'])'});
}
node('ExitGoal',null,'Areas',{unique_name_in_owner:'true',position:vec(8370,400)},R.exit);
node('Foreground','Node2D','.',{z_index:'5'});
node('Effects','Node2D','.',{z_index:'10'});
node('CombatFeedback','Node2D','Effects',{unique_name_in_owner:'true',script:R.feedback});
node('LevelSounds',null,'.',{unique_name_in_owner:'true'},R.sounds);
node('Interface','CanvasLayer','.');
node('HandbuiltHud',null,'Interface',{unique_name_in_owner:'true'},R.hud);
node('CombatHud',null,'.',{unique_name_in_owner:'true'},R.combat_hud);
dressTerrain({node,sprite,R});
const output='[gd_scene format=3]\n\n'+ext.join('\n')+'\n\n'+shapes.join('\n\n')+'\n\n'+nodes.join('\n\n')+'\n';
await fs.writeFile(root+'/scenes/levels/level_01.tscn',output);
return {nodes:nodes.length,encounters:battles.length,length:8620};
}
