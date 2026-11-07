const fs=require('fs');const meta=require('./bosses2.json');
const dec=s=>s.replace(/&amp;/g,'&').replace(/&#39;|&#x27;|&rsquo;/g,"'").replace(/&ldquo;|&rdquo;|&quot;/g,'"');
function bossesWithIds(slug){
  const h=fs.readFileSync('raw/'+slug+'.html','utf8');
  const i=h.search(/Bosses · \d+/); if(i<0)return[];
  // primeira lista <ol class="idt-bosses"> = dificuldade padrao (5 jogadores / raid normal)
  const ol=h.slice(i).match(/<ol class="idt-bosses">([\s\S]*?)<\/ol>/); if(!ol)return[];
  const out=[];const re=/<li>([\s\S]*?)<\/li>/g;let m;
  while((m=re.exec(ol[1]))){const li=m[1];
    const el=li.match(/<(a|span) class="idt-boss"([^>]*)>([\s\S]*?)<\/\1>/); if(!el)continue;
    let name=dec(el[3].replace(/<[^>]+>/g,'')).replace(/\s*★\s*/g,'').trim();
    const idm=el[2].match(/npc=(\d+)/); let npc=idm?+idm[1]:null;
    // quando o cliente da outro nome para a luta, o link aponta para outro NPC: usa o nome da luta, sem id
    const f=li.match(/calls the fight &ldquo;(.+?)&rdquo;/); if(f){name=dec(f[1]);npc=null;}
    const isNew=/★/.test(li);
    if(name) out.push({name,npc,isNew});}
  return out;
}
const wings={
 'scarlet-monastery':{'Interrogator Vishas':'Cemitério','Bloodmage Thalnos':'Cemitério','Houndmaster Loksey':'Biblioteca','Arcanist Doan':'Biblioteca','Herod':'Arsenal','High Inquisitor Fairbanks':'Catedral','High Inquisitor Whitemane':'Catedral'},
 'dire-maul':{'Zevrim Thornhoof':'Leste','Hydrospawn':'Leste','Lethtendris':'Leste','Pusillin':'Leste','Alzzin the Wildshaper':'Leste','Tendris Warpwood':'Oeste','Illyanna Ravenoak':'Oeste','Magister Kalendris':'Oeste','Immol\'thar':'Oeste','Prince Tortheldrin':'Oeste','Lord Hel\'nurath':'Oeste','Tsu\'zee':'Oeste','Guard Mol\'dar':'Norte','Stomper Kreeg':'Norte','Guard Fengus':'Norte','Guard Slip\'kik':'Norte','Captain Kromcrush':'Norte','Cho\'Rush the Observer':'Norte','King Gordok':'Norte'},
 'blackrock-spire':{'Pyroguard Emberseer':'Superior','Warchief Rend Blackhand':'Superior','The Beast':'Superior','General Drakkisath':'Superior','Lord Valthalak':'Superior'},
 'stratholme':{'Baroness Anastari':'Morta-viva','Nerub\'enkan':'Morta-viva','Maleki the Pallid':'Morta-viva','Magistrate Barthilas':'Morta-viva','Ramstein the Gorger':'Morta-viva','Baron Rivendare':'Morta-viva','Black Guard Swordsmith':'Morta-viva','Stonespine':'Morta-viva'},
};
const defWing={'blackrock-spire':'Inferior','stratholme':'Viva'};
const announced=[
 ['the-drowned-city',"The Drowned City",'party','35-40','Stranglethorn Vale'],
 ['krol-dor-stronghold',"Krol'dor Stronghold",'party','40-55','Riverglades'],
 ['alcaz-prison',"Alcaz Prison",'party','?','Dustwallow Marsh'],
 ['blackmaw-hold',"Blackmaw Hold",'party','55-60','Azshara'],
 ['shaper-s-terrace',"Shaper's Terrace",'party','58-60','Un\'Goro Crater'],
 ['barrow-deeps',"Barrow Deeps",'raid','60','?'],
 ['hyjal-summit',"Hyjal Summit",'raid','60','Mount Hyjal'],
];
const L=s=>JSON.stringify(s);
let lua='-- GERADO AUTOMATICAMENTE por tools/gen.js a partir do cliente WoW Forever (build 1.60.1)\n-- Fonte: wowforevertalents.com (dados lidos do cliente beta/launch). Nao edite a mao.\nlocal _, ns = ...\nns.Instances = {\n';
const order=Object.entries(meta).filter(([k,v])=>/^(Dungeon|Raid)/.test(v.type)||announced.some(a=>a[0]===k));
const ann=new Set(announced.map(a=>a[0]));
const rows=[];
for(const [k,v] of Object.entries(meta)){
  if(!/^(Dungeon|Raid)/.test(v.type)&&!(k==='karazhan-crypts'))continue;
  if(ann.has(k))continue;
  rows.push({k,name:v.title,map:v.map,kind:/^Raid/.test(v.type)?'raid':'party',size:+((v.type.match(/(\d+) players/)||[])[1]||5),lvl:v.lvl,bosses:bossesWithIds(k)});
}
for(const a of announced) rows.push({k:a[0],name:a[1],map:(meta[a[0]]&&meta[a[0]].map)||null,kind:a[2],size:a[2]==='raid'?0:5,lvl:a[3],zone:a[4],bosses:[],announced:true});
// dungeons novas nao tem nivel de entrada no cliente: usa o nivel do Group Finder
const finder={'the-hall-of-thanes':'13','ruins-of-lordaeron':'15','excavation-site-wetlands':'26','city-of-dalaran':'28'};
for(const r of rows) if(!r.lvl&&finder[r.k]) r.lvl=finder[r.k];
for(const r of rows){
  lua+=`  { key=${L(r.k)}, name=${L(r.name)}, instanceID=${r.map||'nil'}, kind=${L(r.kind)}${r.size?`, size=${r.size}`:''}${r.lvl?`, minLevel=${L(r.lvl)}`:''}${r.zone?`, zone=${L(r.zone)}`:''}${r.announced?', announced=true':''},\n    bosses={\n`;
  r.bosses.forEach(b=>{const w=(wings[r.k]&&wings[r.k][b.name])||defWing[r.k];
    lua+=`      { name=${L(b.name)}${b.npc?`, npc=${b.npc}`:''}${w?`, wing=${L(w)}`:''}${b.isNew?', new=true':''} },\n`;});
  lua+='    } },\n';
}
lua+='}\n';
fs.writeFileSync(process.argv[2],lua);
console.log(rows.length+' instances; '+rows.reduce((a,r)=>a+r.bosses.length,0)+' bosses');
for(const r of rows)console.log(r.k,r.map,r.bosses.length,r.bosses.filter(b=>b.npc).length);
