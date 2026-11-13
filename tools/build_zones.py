"""Extract static quest categories and English area-name fallbacks from QuestieDB."""
from pathlib import Path
import json,re,urllib.request
from lupa import LuaRuntime
ROOT=Path(__file__).resolve().parents[1]
REV='0f7d8adc92b28ac6594f4ad8745257f4d9784edf'
BASE='https://raw.githubusercontent.com/Questie/QuestieDB/'+REV+'/'
def read(path): return urllib.request.urlopen(BASE+path,timeout=30).read().decode()
lua=LuaRuntime()
s=read('data/Forever/foreverQuestDB.lua')
data=lua.execute(re.search(r'questData\s*=\s*\[\[(.*?)\]\]',s,re.S).group(1))
symbols={k:int(v) for k,v in re.findall(r'^\s*([A-Z][A-Z_0-9]+)\s*=\s*(\d+)',read('src/corrections/enum/zones.lua'),re.M)}
names={v:k.replace('_FOREVER','').replace('_',' ').title() for k,v in symbols.items()}
# Use authored English labels where the map relationship table provides them.
for area,comment in re.findall(r'^\s*\[(\d+)\]\s*=\s*\d+,\s*-- ([^\n]+)',read('support/Forever/Zones/areaIdToUiMapId.lua'),re.M):
 label=comment.split(' -> ')[0].strip()
 if not label.startswith(('Referenced','Synthetic','Existing','Legacy')): names[int(area)]=label
zones={int(id):int(r[17]) for id,r in data.items() if r[17] and r[17]!=0}
# Apply explicit zoneOrSort assignments from Forever correction layers.
for path in ['src/corrections/Forever/generated/foreverBaseQuest.lua','src/corrections/Forever/traces/foreverQuestTraces.lua','src/corrections/Forever/foreverQuestFixes.lua']:
 s=read(path);blocks=list(re.finditer(r'^        \[(\d+)\]\s*=\s*\{',s,re.M))
 for i,m in enumerate(blocks):
  b=s[m.end():blocks[i+1].start() if i+1<len(blocks) else len(s)]
  a=re.search(r'\[questKeys.zoneOrSort\]\s*=\s*(-?\d+|zoneIDs\.\w+)\s*[,\n]',b)
  if a:
   expr=a.group(1);v=symbols.get(expr[8:]) if expr.startswith('zoneIDs.') else int(expr)
   if v is not None: zones[int(m.group(1))]=v
# Known class bit flags provide readable fallback labels for class categories.
classes={1:'Warrior',2:'Paladin',4:'Hunter',8:'Rogue',16:'Priest',64:'Shaman',128:'Mage',256:'Warlock',1024:'Druid'}
for id,zone in zones.items():
 if zone<0:
  mask=data[id] and data[id][7]
  if mask in classes: names[zone]=classes[mask]+' quests'
  elif data[id] and data[id][18]: names[zone]='Profession quests'
for zone in set(zones.values()):
 if zone<0 and zone not in names: names[zone]='Other quests'
lines=['-- Quest zone/category data adapted from QuestieDB, snapshot '+REV,
 '-- GPLv3 terms and provenance: third_party/QuestieDB-NOTICE.txt','local _, A = ...','A.questZones = {']
lines += ['    [%d] = %d,'%(id,z) for id,z in sorted(zones.items())]
lines += ['}','A.zoneNames = {']
used=set(zones.values())
lines += ['    [%d] = %s,'%(id,json.dumps(name,ensure_ascii=True)) for id,name in sorted(names.items()) if id in used]
lines += ['}']
(ROOT/'QuestZones.lua').write_text('\n'.join(lines)+'\n')
print('Generated',len(zones),'quest categories')
