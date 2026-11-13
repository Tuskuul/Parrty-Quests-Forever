"""Extract requirement summaries only; do not import quest progress or addon logic."""
from pathlib import Path
import json, re, urllib.request
from lupa import LuaRuntime
ROOT=Path(__file__).resolve().parents[1]
REV='0f7d8adc92b28ac6594f4ad8745257f4d9784edf'
BASE='https://raw.githubusercontent.com/Questie/QuestieDB/'+REV+'/'
def read(path):
    return urllib.request.urlopen(BASE+path,timeout=30).read().decode()
def quote(s):
    return '"'+''.join('\\'+c if c in '\\"' else ('\\%03d'%ord(c) if ord(c)<32 else c) for c in s)+'"'
lua=LuaRuntime(unpack_returned_tuples=True)
source=read('data/Forever/foreverQuestDB.lua')
expr=re.search(r'questData\s*=\s*\[\[(.*?)\]\]',source,re.S).group(1)
data=lua.execute(expr)
result={}
for id,row in data.items():
    if row[8]:
        texts=[v for _,v in sorted(row[8].items()) if isinstance(v,str) and v.strip()]
        if texts:result[int(id)]=texts
# Authored summaries override generated base/trace summaries where supplied.
paths=['src/corrections/Forever/generated/foreverBaseQuest.lua',
       'src/corrections/Forever/traces/foreverQuestTraces.lua',
       'src/corrections/Forever/foreverQuestFixes.lua']
# These fields contain simple quoted strings, not correction expressions.
string=r'"(?:\\.|[^"\\])*"|\'(?:\\.|[^\'\\])*\''
for path in paths:
    text=read(path)
    blocks=list(re.finditer(r'^        \[(\d+)\]\s*=\s*\{',text,re.M))
    for i,m in enumerate(blocks):
        block=text[m.end():blocks[i+1].start() if i+1<len(blocks) else len(text)]
        found=re.search(r'\[questKeys\.objectivesText\]\s*=\s*\{((?:\s*(?:'+string+r')\s*,?\s*)*)\}',block,re.S)
        if found:
            values=re.findall(string,found.group(1))
            strings=[lua.eval(s) for s in values]
            if strings:result[int(m.group(1))]=strings
            else:result.pop(int(m.group(1)),None)
lines=['-- Quest requirement summaries adapted from QuestieDB; static text only.',
       '-- GPLv3 terms and provenance: third_party/QuestieDB-NOTICE.txt',
       '-- Source snapshot: '+REV,'local _, A = ...','A.questRequirements = {']
for id,texts in sorted(result.items()):
    lines.append('    [%d] = {%s},'%(id,','.join(quote(s) for s in texts)))
lines+=['}']
(ROOT/'QuestRequirements.lua').write_text('\n'.join(lines)+'\n')
(ROOT/'third_party'/'QuestieDB-LICENSE.md').write_text(read('LICENSE.md'))
(ROOT/'third_party'/'GPL-3.0.md').write_text(read('gpl-3.0.md'))
(ROOT/'third_party'/'QuestieDB-NOTICE.txt').write_text(
    'Requirement summaries adapted from QuestieDB and its historic Questie contributors.\n'
    'Source: https://github.com/Questie/QuestieDB/tree/'+REV+'\n'
    'Modified for Simply Party Quests: extracted objectivesText summaries only, merged\n'
    'generated/trace/authored summary overrides, omitted all progress and runtime code.\n'
    'Bundled summaries are an English fallback; client-provided text takes priority.\n'
    'Redistributed under GPLv3 terms as permitted by the upstream licensing notice.\n'
    'See QuestieDB-LICENSE.md for the complete upstream licensing statement and\n'
    'GPL-3.0.md for the license. No affiliation with Questie is implied.\n'
    'Regenerate with tools/build_requirements.py (Python + lupa; network required).\n')
print('Generated static summaries for',len(result),'quests')
