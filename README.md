# Party Quests Forever

<img src="docs/project-icon.png" alt="Party Quests Forever icon" width="512">

[Full-size artwork](docs/artwork/PartyQuestsForever-adventure.png)

Track party quests and available objective progress in **WoW Forever 1.60.1**.
Choose a Blizzard-styled tracker sidebar or a separate resizable window, combine shared quests, and group quests by player and zone.

## Current build

**1.1.5-beta3**, a testing build with default-on combat auto-collapse and tracker reopening fixes. Focused quest highlighting is retained. Your own progress starts collapsed under **+ You**. Party members retain separate headings and objective rows. Character/WIM sending and receiving and a Battle.net snapshot transfer have passed user testing. Native discovery remains limited to what the client exposes.

Combat auto-collapse is under **Display → Collapse tracker during combat**. It leaves the compact header visible and restores the previous expanded or collapsed view afterward; disable it to leave the tracker expanded during combat. Changes to this setting during combat apply afterward.

## Install

The addon folder must be named **SimplyPartyQuests**. Put this repository's addon files directly inside `Interface/AddOns/SimplyPartyQuests/`, so `SimplyPartyQuests.toc` sits directly inside that folder. A GitHub source ZIP's repository-named wrapper must be renamed appropriately.

Existing Simply Party Quests users keep their settings. Replace files and `/reload`; a first installation may need a full client restart.

Open **Esc → Settings → AddOns → Party Quests Forever**, or right-click the minimap button. `/spq` remains supported.

Native party quests show **Ready** when the member's reported progress completes every known requirement, even without an explicit turn-in flag. Unknown or partial progress remains unmarked.

Progress queries and sidebar text update during combat. You can expand or collapse players, zones and quests, toggle the party pane, and reopen it during combat. These actions rebuild the addon panel from known data. Discovery, membership checks and native tracker repair wait until combat ends. Client restrictions still affect available data.

The party sidebar background follows the Objective Tracker opacity in Blizzard Edit Mode. It also follows the tracker's live fonts, size, outline, shadow, colors and scale. Appearance changes reflow rows outside combat.

When Blizzard's tracker is empty or hidden, the party pane uses a compact **Party Quests** header at the tracker position. Empty quest sections are omitted.

The party pane shrinks to its contents and expands up to the Objective Tracker height set in Blizzard Edit Mode. Longer lists scroll; there is no separate sidebar height setting.

Ready tags and turn-in text are bright green. Guarded Blizzard tracker refresh defaults on for new or unset preferences; explicit off settings are preserved. It requests redraws only for confirmed numeric mismatches outside combat, checks the result, and pauses after blank or unverifiable results. Settings can disable it.

## Quest-log links

Share now offers **Full log** or **Select quests**. Choose one or more quests and click **Share selected** to share just those entries and their objective progress. Cancel or Escape restores the original chat draft.

Click **Share** in the Party Quests tracker header, or **Share Quest Log** in the main Map & Quest Log title bar, left of fullscreen. It inserts a snapshot link into your current chat draft for you to send. Compatible recipients click to inspect the active quests and objective completion. This is a timestamped snapshot, not lifetime completion history or a live view.

Character chat, WIM and Battle.net whispers are supported. The owner must remain online with the addon for first fetch. Battle.net requires a compatible WoW session and uses its own data route for cross-faction/realm sharing. Not every UI/client/server combination has been tested.

## Documentation

- [Installation, controls and troubleshooting](README.txt)
- [Changelog](CHANGELOG.txt)
- [CurseForge listing copy](docs/CURSEFORGE.md)
- [Release checklist](docs/RELEASE-CHECKLIST.md)
- [Chat integration notes](docs/chat-compatibility.md)

The `.pkgmeta` file sets `package-as: SimplyPartyQuests` to preserve the install folder when a CurseForge-compatible packager is configured. It does not publish a release by itself.

## License and credits

Created by Wolfie. Project code is GPLv3. Static fallback data derives from QuestieDB and historic Questie contributions. The full [upstream notice](third_party/QuestieDB-NOTICE.txt) and [licensing statement, including its historical contributor caveat](third_party/QuestieDB-LICENSE.md), are retained. This addon is not affiliated with Questie. The project icon is original artwork.
