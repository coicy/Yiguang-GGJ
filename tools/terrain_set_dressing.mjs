// Authored placement: structures follow local facility uses, not a global scatter loop.
export function dressTerrain({node,sprite,R}) {
 const V=(x,y)=>'Vector2('+x+', '+y+')';
 node('Architecture','Node2D','.',{z_index:'-2'});
 node('RoomDetails','Node2D','Background',{z_index:'15'});
 const sizes={drain:[476,128],catwalk:[493,127],culvert:[478,221],pipe:[341,444],buttress:[303,462],core_plinth:[502,217],root_soil:[679,376],fungal_log:[694,397],seedling_tray:[708,333],broken_planter:[676,546]};
 function part(name,key,x,y,width,parent='Architecture',tint='Color(0.8,0.84,0.76,1)'){
  const sc=width/sizes[key][0];
  node(name,'Sprite2D',parent,{texture:R['part_'+key],material:R.cutout,position:V(x,y),scale:V(sc,sc),centered:'false',modulate:tint});
 }
 // Nursery is a complete chamber owned by nursery_room.mjs.
 // Foundation joints and roots explain where old cultivation paths fractured.
 part('WalkDrainTransition','culvert',1345,403,170);
 part('SporeDrainTransition','drain',2080,402,114);
 for(const [name,x,y,scale] of [['PathRootA',915,450,.48],['PathRootB',1880,455,.38],['PathRootC',2050,409,.26]])
  sprite(name,'root_support',x,y,scale,'Architecture','Color(0.63,0.72,0.51,1)');
 sprite('MossShoulder','slope',1400,420,.4,'Architecture','Color(0.74,0.8,0.62,1)');
 // Spore hall: shaded pipes and damp bearing arches, with two real cover planters.
 part('SporeCulvertA','culvert',2220,408,205);
 part('SporeCulvertB','culvert',3240,408,215);
 part('SporePipeA','pipe',2645,262,108,'Background/RoomDetails','Color(0.34,0.46,0.43,1)');
 part('SporePipeB','pipe',2920,278,94,'Background/RoomDetails','Color(0.38,0.47,0.39,1)');
 part('FungalTimberA','fungal_log',2580,415,145,'Architecture','Color(0.63,0.68,0.55,1)');
 part('FungalTimberB','fungal_log',3320,418,118,'Architecture','Color(0.6,0.65,0.54,1)');
 part('SporeCoverSeedlingsA','seedling_tray',2325,344,54,'Background/RoomDetails','Color(0.5,0.56,0.42,1)');
 part('SporeCoverSeedlingsB','seedling_tray',3045,344,54,'Background/RoomDetails','Color(0.47,0.52,0.42,1)');
 // Workshop: exposed trusses with occasional columns, a service bridge and an exit root joint.
 for(const [i,x] of [[0,3650],[1,4060],[2,4380],[3,4860]])part('WorkshopColumn'+i,'buttress',x,421,52);
 part('WorkshopBridge','catwalk',4200,401,160);
 part('WorkshopServicePipe','pipe',4170,295,100,'Background/RoomDetails','Color(0.45,0.51,0.44,1)');
 part('WorkshopSideBracket','catwalk',4770,343,120,'Background/RoomDetails','Color(0.46,0.56,0.49,1)');
 sprite('WorkshopRootJoint','root_support',5035,420,.46,'Architecture','Color(0.64,0.73,0.53,1)');
 // Canopy: each landing is rooted in a distinct bearing branch, with a supported lower trough.
 for(const [name,x,y,scale] of [
  ['RootStairBearing',5350,409,.56],['WestBranchBearing',5515,355,.53],
  ['CrownBranchBearing',5730,325,.64],['EastBranchBearing',5920,357,.54],
  ['LandingRootBearing',6150,414,.6],['ReturnBranch0',5900,555,.39],
  ['ReturnBranch1',6000,510,.39],['ReturnBranch2',6100,465,.39]])
   sprite(name,'root_support',x,y,scale,'Background/RoomDetails','Color(0.48,0.59,0.39,1)');
 for(const [name,x,y] of [['CanopyTrunkWest',5490,320],['CanopyTrunkEast',5960,340]])
  node(name,'Sprite2D','Background/RoomDetails',{texture:R.root_wall,position:V(x,y),scale:V(.94,.94),rotation:'1.5707963',modulate:'Color(0.26,0.38,0.27,1)'});
 part('LowerNurseryTrough','seedling_tray',5440,560,155);
 part('LowerNurseryPlanter','broken_planter',5775,488,78,'Background/RoomDetails','Color(0.5,0.57,0.4,1)');
 part('CanopyDrainOutlet','drain',5320,557,120);
 sprite('CrownHangingLeaves','hang_a',5740,318,.25,'Background/RoomDetails','Color(0.5,0.62,0.43,1)');
 sprite('WestHangingLeaves','hang_b',5500,354,.20,'Background/RoomDetails','Color(0.4,0.54,0.38,1)');
 // Courtyard: buttressed retaining structure; the three-enemy center stays visually open.
 for(const [i,x] of [[0,6560],[1,6629]])part('CourtSideSupport'+i,'buttress',x,346,35,'Background/RoomDetails','Color(0.28,0.38,0.33,1)');
 for(const [i,x] of [[0,6485],[1,7000],[2,7360]])part('CourtButtress'+i,'buttress',x,404,62);
 part('CourtPlanter','broken_planter',7090,320,95,'Background/RoomDetails','Color(0.4,0.46,0.37,1)');
 part('CourtPrepareTray','seedling_tray',7170,405,120);
 part('CourtRootDrain','drain',7290,404,100);
 // Core: masonry walk plane over bronze conduits; arena ends remain empty at player height.
 // The core profile already supplies complete conduit blocks; avoid overlapping a second row.
 part('CorePipeLeft','pipe',7465,280,92,'Background/RoomDetails','Color(0.37,0.44,0.38,1)');
 part('CorePipeRight','pipe',8090,280,92,'Background/RoomDetails','Color(0.37,0.44,0.38,1)');
 sprite('CoreRootFeed','root_support',7855,475,.55,'Architecture','Color(0.54,0.62,0.44,1)');
 part('ExitSeedlings','seedling_tray',8480,360,80,'Background/RoomDetails','Color(0.58,0.69,0.48,1)');
 // Localized vegetation palettes, placed away from enemy spawn/telegraph columns.
 for(const [i,key,x,y,s] of [
  [3,'grass_low_b',820,402,.16],[4,'tuft_b',1250,402,.08],[5,'needle_a',1405,403,.07],
  [6,'flowers',1540,402,.055],[7,'grass_low_c',1980,402,.16],[8,'needle_b',2140,402,.075],
  [9,'grass_low_b',2250,402,.11],[10,'tuft_b',2700,402,.055],[11,'grass_low_c',2890,402,.12],
  [12,'grass_low',3490,402,.12],[13,'needle_a',4990,401,.065],
  [14,'tuft_b',5170,401,.08],[15,'flower_b',5375,351,.055],[16,'grass_low_b',5715,261,.11],
  [17,'needle_b',5980,301,.065],[18,'grass_low_c',6310,402,.15],[19,'flower_b',7080,402,.05],
  [20,'tuft_b',7420,402,.06],[21,'grass_low',8250,402,.13],[22,'flower_b',8520,402,.055]])
   sprite('LocalGrowth'+i,key,x,y,s,'Background/RoomDetails','Color(0.55,0.69,0.48,1)');
}
