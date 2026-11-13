"""Build the original Party Quests Forever icon; no game artwork is used."""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFilter
ROOT=Path(__file__).resolve().parents[1]
S=3
def box(*p):return tuple(int(v*S) for v in p)
im=Image.new('RGBA',(512*S,512*S),(15,24,31,255));d=ImageDraw.Draw(im)
d.rounded_rectangle(box(16,16,496,496),radius=76*S,fill='#102b32',outline='#be924b',width=9*S)
d.rounded_rectangle(box(34,34,478,478),radius=60*S,outline='#36505a',width=2*S)
# Scroll, rolled edges and parchment: shapes drawn specifically for this project.
d.rounded_rectangle(box(125,70,398,366),radius=18*S,fill='#071b22')
d.rounded_rectangle(box(110,56,382,346),radius=16*S,fill='#e8cf94',outline='#a9793f',width=7*S)
d.rounded_rectangle(box(91,55,398,102),radius=22*S,fill='#b98b4b',outline='#795530',width=6*S)
d.rounded_rectangle(box(108,62,380,88),radius=12*S,fill='#efd9a2')
d.rounded_rectangle(box(90,315,398,361),radius=22*S,fill='#c99b56',outline='#795530',width=6*S)
d.rounded_rectangle(box(108,325,382,347),radius=10*S,fill='#efd9a2')
# Quest marker and three task lines.
d.rounded_rectangle(box(222,124,260,215),radius=12*S,fill='#825521')
d.ellipse(box(222,229,260,267),fill='#825521')
for y,w in [(148,60),(192,82),(240,57)]:
 d.rounded_rectangle(box(282,y,282+w,y+12),radius=6*S,fill='#b39057')
# Three party portraits linked to the shared scroll.
d.line([box(256,362),box(256,391)],fill='#d6ad64',width=8*S)
d.line([box(146,401),box(146,384),box(366,384),box(366,401)],fill='#d6ad64',width=6*S)
for x,y in [(146,427),(256,422),(366,427)]:
 d.ellipse(box(x-42,y-42,x+42,y+42),fill='#102b32',outline='#d6ad64',width=5*S)
 d.ellipse(box(x-12,y-24,x+12,y),fill='#e8cf94')
 d.rounded_rectangle(box(x-24,y+6,x+24,y+26),radius=11*S,fill='#e8cf94')
im=im.resize((512,512),Image.Resampling.LANCZOS)
im.save(ROOT/'docs'/'project-icon.png')
im.resize((256,256),Image.Resampling.LANCZOS).save(ROOT/'Assets'/'Icon.tga')
