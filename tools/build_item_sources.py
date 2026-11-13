"""Extract static quest-item source IDs; no player progress is imported."""
from pathlib import Path
import re, urllib.request
from lupa import LuaRuntime
ROOT=Path(__file__).resolve().parents[1]
REV='0f7d8adc92b28ac6594f4ad8745257f4d9784edf'
url='https://raw.githubusercontent.com/Questie/QuestieDB/'+REV+'/data/Forever/foreverQuestDB.lua'
source=urllib.request.urlopen(url,timeout=30).read().decode()
data=LuaRuntime().execute(re.search(r'questData\s*=\s*\[\[(.*?)\]\]',source,re.S).group(1))
lines=['-- Static quest objective item IDs from QuestieDB, snapshot '+REV,
       '-- GPLv3 terms and provenance: third_party/QuestieDB-NOTICE.txt',
       '-- Candidate tooltips only: these IDs never establish player progress.',
       'local _, A = ...','A.questItemSources = {']
count=0
for id,row in sorted(data.items()):
    objective=row[10]
    items=objective and objective[3]
    if not items: continue
    ids=sorted({int(r[1]) for _,r in items.items() if r[1] and r[1]>0})
    if ids:
        lines.append('    [%d] = {%s},'%(id,','.join(map(str,ids))))
        count+=1
lines.append('}')
(ROOT/'QuestItemSources.lua').write_text('\n'.join(lines)+'\n')
print('Generated',count,'quest item source mappings')
