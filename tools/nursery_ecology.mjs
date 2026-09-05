// Site-specific colonies: attachment points are world-space surfaces, not a scatter grid.
export function dressNursery({node,resource,R}) {
 const v=(x,y)=>'Vector2('+x+', '+y+')';
 const textures={};
 for(const key of ['fern','saxifrage','epiphyte','shelf_fungi'])textures[key]=resource('Texture2D','assets/runtime/foliage/'+key+'.tres','nursery_'+key);
 node('RootedCover','Node2D','NurseryRoom',{z_index:'-4'});
 node('NearCover','Node2D','NurseryRoom',{z_index:'2'});
 const attach=(name,key,x,y,scale,anchor,parent='NurseryRoom/RootedCover',tint='Color(0.8,0.9,0.77,1)')=>node(name,'Sprite2D',parent,{texture:textures[key],texture_filter:'4',centered:'false',position:v(x-anchor[0]*scale,y-anchor[1]*scale),scale:v(scale,scale),modulate:tint});
 // The sheltered entry has one shallow colony, leaving the pressure pedal and low gap bare.
 attach('EntryMoistCrack','saxifrage',-12,530,.07,[360,334]);
 // Broad fronds grow from the damp foot of the first retaining wall; roots disappear behind it.
 attach('RetainingFootFern','fern',405,530,.135,[365,404]);
 // Each lit shelf has a different density. Jump edges themselves remain unobstructed.
 attach('FirstShelfColony','saxifrage',486,486,.070,[360,334]);
 attach('UpperShelfFern','fern',694,400,.09,[365,404]);
 attach('SecondShelfSeedlings','saxifrage',590,444.57,.052,[360,334]);
 // Epiphytes hang from actual roof shoulders, above the actor's jump path.
 attach('EntryRoofEpiphyte','epiphyte',-30,420,.12,[180,24]);
 attach('ArchEpiphyte','epiphyte',406,285,.11,[180,24]);
 // Close foliage and fungi belong to the exposed root face below walkable ground.
 attach('FoundationFungi','shelf_fungi',563,532,.13,[56,70],'NurseryRoom/NearCover','Color(0.39,0.5,0.38,1)');
 attach('NearFern','fern',594,634,.25,[365,404],'NurseryRoom/NearCover','Color(0.17,0.26,0.21,1)');
}
