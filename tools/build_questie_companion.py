"""Build the two-addon internal test bundle without invoking any publisher."""
import argparse
from pathlib import Path
from zipfile import ZipFile, ZIP_DEFLATED

root = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser()
parser.add_argument('output', type=Path)
args = parser.parse_args()
args.output.parent.mkdir(parents=True, exist_ok=True)
base_files = [line.strip().replace('\\', '/') for line in (root / 'SimplyPartyQuests.toc').read_text().splitlines()
              if line.strip() and not line.startswith('#')]
base_files += ['SimplyPartyQuests.toc', 'LICENSE']
base_files += [f.relative_to(root).as_posix() for folder in ('Assets', 'third_party')
               for f in (root / folder).rglob('*') if f.is_file()]
plugin = root / 'PartyQuestieForever'
with ZipFile(args.output, 'w', ZIP_DEFLATED) as archive:
    for name in sorted(set(base_files)):
        archive.write(root / name, 'SimplyPartyQuests/' + name)
    for source in sorted(plugin.iterdir()):
        if source.is_file():
            archive.write(source, 'PartyQuestieForever/' + source.name)
    archive.writestr('INSTALL.txt', '''Party Questie Forever 0.1.0-dev1 - INTERNAL TEST BUILD

Keep Questie installed. Exit WoW, then copy both addon folders into Interface/AddOns.
Replace the existing SimplyPartyQuests folder with this matching test base; do not create a second copy.
Enable Party Quests Forever, Questie, and Party Questie Forever, then reload.

This bundle contains normal PQF 1.1.11 plus a small plugin API bridge, and the separate companion.
The unmodified CurseForge 1.1.11 does not yet have that bridge. No production branch was updated.
The companion needs both SimplyPartyQuests and Questie. It has its own PartyQuestieForeverDB settings.
Choose Tabbed or Side by Side in the Party Questie Forever AddOns settings category.
Existing quest data, networking and refresh logic belong to normal PQF only.

To remove the companion, disable Party Questie Forever and reload. PQF's normal Questie dock returns.
This is not a CurseForge release. In-game validation is still required.
''')
with ZipFile(args.output) as archive:
    assert archive.testzip() is None
    names = set(archive.namelist())
    assert 'SimplyPartyQuests/SimplyPartyQuests.toc' in names
    assert 'SimplyPartyQuests/PluginAPI.lua' in names
    assert 'PartyQuestieForever/PartyQuestieForever.toc' in names
    assert not any(name.startswith('SimplyPartyQuests/PartyQuestieForever/') for name in names)
print(args.output.resolve())
