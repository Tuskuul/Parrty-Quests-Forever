"""Extract acceptance rules, not objective text, from the pinned QuestieDB snapshot.
Corrected eligibility records are marked uncertain rather than guessing how to
interpret upstream runtime corrections. Requires Python and lupa.
"""
from pathlib import Path
import re, urllib.request
from lupa import LuaRuntime
ROOT=Path(__file__).resolve().parents[1]
REV='0f7d8adc92b28ac6594f4ad8745257f4d9784edf'
BASE='https://raw.githubusercontent.com/Questie/QuestieDB/'+REV+'/'
FIELDS={4:'level',6:'races',7:'classes',12:'all',13:'any',15:'group',16:'exclusive',18:'skill',19:'minRep',20:'maxRep',21:'items',22:'next',23:'flags',24:'special',25:'parent',27:'breadcrumb',28:'breadcrumbs',30:'spell',31:'spec',32:'maxLevel',33:'untilDone',34:'starting',35:'ranks',36:'disabled'}
KEYS={'requiredLevel','requiredRaces','requiredClasses','preQuestGroup','preQuestSingle','inGroupWith','exclusiveTo','requiredSkill','requiredMinRep','requiredMaxRep','requiredSourceItems','nextQuestInChain','questFlags','specialFlags','parentQuest','breadcrumbForQuestId','breadcrumbs','requiredSpell','requiredSpecialization','requiredMaxLevel','availableUntilCompleted','availableStartingWith','requiredRanks','disabledByQuest'}
def read(path): return urllib.request.urlopen(BASE+path,timeout=30).read().decode()
def encode(value):
 if isinstance(value,bool): return 'true' if value else 'false'
 if isinstance(value,(int,float)): return str(int(value))
 return '{'+','.join(encode(v) for _,v in sorted(value.items()))+'}'
source=read('data/Forever/foreverQuestDB.lua')
data=LuaRuntime().execute(re.search(r'questData\s*=\s*\[\[(.*?)\]\]',source,re.S).group(1))
uncertain=set()
for path in ['src/corrections/Forever/generated/foreverBaseQuest.lua','src/corrections/Forever/traces/foreverQuestTraces.lua','src/corrections/Forever/foreverQuestFixes.lua']:
 text=read(path);blocks=list(re.finditer(r'^        \[(\d+)\]\s*=\s*\{',text,re.M))
 for i,m in enumerate(blocks):
  block=text[m.end():blocks[i+1].start() if i+1<len(blocks) else len(text)]
  if any('[questKeys.'+key+']' in block for key in KEYS): uncertain.add(int(m.group(1)))
lines=['-- Acceptance metadata from QuestieDB '+REV,
       '-- GPLv3 and historic contributor caveats: third_party/QuestieDB-NOTICE.txt',
       '-- Static rules cannot guarantee server acceptance. Uncertain records never auto-request.',
       'local _, A = ...','A.questEligibility = {']
for questid,row in sorted(data.items()):
 fields=[key+'='+encode(row[index]) for index,key in FIELDS.items() if row[index] is not None]
 if row[23] is None: fields.append('flags=0')
 if int(questid) in uncertain: fields.append('uncertain=true')
 lines.append('    [%d]={%s},'%(questid,','.join(fields)))
lines.append('}')
(ROOT/'QuestEligibility.lua').write_text('\n'.join(lines)+'\n')
print('Generated',len(list(data.items())),'acceptance records;',len(uncertain),'corrected IDs require verification')
