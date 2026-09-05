// One authored chamber. Foreground geometry and UVs refer to a single master painting.
// registration.json is editable source data; no repeated tile strip is used here.
import fs from 'node:fs/promises';
export async function buildNursery({node,resource,R,root}) {
 const d=JSON.parse(await fs.readFile(root+'/assets/source/rooms/nursery/registration.json','utf8'));
 const v=(x,y)=>'Vector2('+x+', '+y+')';
 const points=p=>'PackedVector2Array('+p.flat().map(n=>Number(n.toFixed(3))).join(', ')+')';
 const world=p=>p.map(([x,y])=>[d.artOrigin[0]+x*d.artScale,d.artOrigin[1]+y*d.artScale]);
 const uv=p=>p.map(([x,y])=>[(x-d.artOrigin[0])/d.artScale,(y-d.artOrigin[1])/d.artScale]);
 const nearWorld=p=>p.map(([x,y])=>[d.foreground_origin[0]+x*d.foreground_scale,d.foreground_origin[1]+y*d.foreground_scale]);
 const floor=nearWorld(d.foregroundFloorPixels);
 floor[0][0]=-160; floor[floor.length-1][0]=-160;
 const nearEdge=nearWorld(d.foregroundVaultEdge);
 const vault=[[-160,100],[nearEdge[nearEdge.length-1][0],100],...nearEdge.slice().reverse(),[-160,nearEdge[0][1]]];
 const art=resource('Texture2D','assets/runtime/rooms/nursery_foreground.png','nursery_art');
 const matte=resource('ShaderMaterial','features/level/rooms/foreground_cutout.tres','nursery_foreground_matte');
 const bg=resource('Texture2D','assets/runtime/rooms/nursery_distant.png','nursery_distant');
 const atmosphere=resource('Script','features/level/rooms/nursery_atmosphere.gd','nursery_atmosphere');
 node('NurseryRoom','Node2D','.',{});
 const region=resource('Script','features/level/rooms/room_region.gd','room_region');
 node('EntryView','Node2D','NurseryRoom',{script:region,position:v(-80,200),room_id:'&"nursery_entry"',room_name:'"01 / 培养室"',objective:'"穿过低矮根洞，寻找培养营养"',region_size:v(390,420),camera_center:v(234,233),camera_zoom:'2.5',selection_priority:'1'});
 node('ChamberView','Node2D','NurseryRoom',{script:region,position:v(310,200),room_id:'&"nursery_chamber"',room_name:'"01 / 培养室"',objective:'"按住 E 吸收营养 · 跳跃登上右侧温室步道"',region_size:v(385,420),camera_center:v(162,226),camera_zoom:'2.25',selection_priority:'1'});
 node('RoomAir','Polygon2D','NurseryRoom',{z_index:'-15',polygon:points([[-160,120],[760,120],[760,704],[-160,704]]),color:'Color(0.12,0.25,0.24,1)'});
 node('BackgroundClip','Polygon2D','NurseryRoom',{z_index:'-10',clip_children:'1',polygon:points([[-160,120],[760,120],[760,704],[-160,704]]),color:'Color(1,1,1,1)'});
 node('DistantInterior','Sprite2D','NurseryRoom/BackgroundClip',{texture:bg,centered:'false',position:v(...d.artOrigin),scale:v(d.artScale,d.artScale)});
 node('DistanceVeil','Polygon2D','NurseryRoom/BackgroundClip',{polygon:points([[-160,120],[760,120],[760,704],[-160,704]]),color:'Color(0.28,0.44,0.42,0.22)'});
 for (const [name,p] of [['Foundation',floor],['RootVault',vault]]) {
  node(name,'StaticBody2D','NurseryRoom',{collision_layer:'1',collision_mask:'0'});
  node('Collision','CollisionPolygon2D','NurseryRoom/'+name,{polygon:points(p)});
  node('PaintedStructure','Polygon2D','NurseryRoom/'+name,{visible:'false',antialiased:'true',z_index:'-3',texture:art,polygon:points(p),uv:points(uv(p))});
 }
 node('RoomPainting','Sprite2D','NurseryRoom',{texture:art,material:matte,texture_filter:'4',z_index:'-5',centered:'false',position:v(...d.foreground_origin),scale:v(d.foreground_scale,d.foreground_scale)});
 node('AirMotes','Node2D','NurseryRoom',{script:atmosphere,z_index:'-4'});
}
