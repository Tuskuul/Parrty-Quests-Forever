# Party Quests Forever — submission copy

## Project fields

- **Name:** Party Quests Forever
- **Suggested slug:** party-quests-forever (availability must be checked)
- **Summary:** Track party quests, compare objective progress, and share clickable quest-log snapshots in WoW Forever.
- **Game/flavor/version:** World of Warcraft / WoW Forever / 1.60.1 only
- **Main category:** Quests & Leveling
- **Additional category:** Chat & Communication
- **License:** GPLv3 for project code; preserve the full bundled QuestieDB statement and caveat.
- **Release file:** PartyQuestsForever_1.1.5-beta3.zip
- **Release type:** Beta
- **Logo:** `docs/project-icon.png` (full-resolution 1254 × 1254 PNG)
- **Required dependencies:** None
- **Optional integration:** WIM. Do not mark it as a required dependency.
- **Project ID / issue URL:** Unassigned; add only after the project exists.

## Public description

**Party Quests Forever** helps your group see what to work on together in **WoW Forever**.

See available party quests beside Blizzard's objective tracker or in a separate movable, resizable window. Collapse players, zones and quests, combine shared quests, and compare available objective progress without crowding your own tracker.

### Features

- Choose **Full log** or **Select quests** when sharing; select one or more quests to include only those entries.

- Discover quest information Forever exposes for party members, even when they do not have the addon.
- Exchange fuller quest-log snapshots when party members also have it installed.
- Combine shared quests with available per-player progress.
- Group quests by zone and display Forever character surnames.
- Choose a left/right tracker sidebar or a separate resizable window.
- Double-click a foreign quest to check known eligibility and request a manual share by whisper.
- Click **Share** in the party tracker header or **Share Quest Log** in the main Map & Quest Log title bar to draft a clickable snapshot link.
- View shared logs in a Blizzard-styled window with collapsible quests, objective completion and turn-in status.
- Share through character whispers, WIM and Battle.net whispers. Battle.net uses a separate data route for cross-faction/realm sharing.
- Configure the addon through its AddOns settings page and draggable minimap button.

### Getting started

Open **Esc → Settings → AddOns → Party Quests Forever**, or right-click its minimap button. Choose your display and grouping preferences. Left-click the minimap button to toggle the pane; Shift-click to refresh.

### What can it see?

Native discovery depends on the information the client exposes. Range, quest type, combat and client restrictions affect coverage and update timing. Distant or offline entries can remain cached or unknown. The addon does not invent objective counts or promise complete, instant remote tracking.

Installing the addon on both players provides fuller snapshot sharing. A chat snapshot is fixed at capture time and shows a timestamp. It includes the active quest log, not lifetime completed-quest history. The owner must remain online for the first fetch; links last fifteen minutes. Clicking Share drafts a message for you to send.

WIM sending/receiving and Battle.net transfers have passed user testing. Not every chat addon, client build, or cross-faction/cross-realm combination has been verified. Both Battle.net users must be in the same WoW client flavor with a compatible addon.

### Updating and troubleshooting

Existing **Simply Party Quests** users retain their settings. Keep the addon folder named **SimplyPartyQuests**; only its displayed name changes. Replace files and `/reload`. A first installation may need a full client restart. Disable the obsolete PoofPartyQuests addon if it is still installed.

Settings includes a diagnostic report; the shared-log viewer also has **Transfer diagnostics**. Review names and quest details before sharing reports. Include addon/client versions and the affected quest. Guarded Blizzard tracker refresh defaults on for new/unset preferences. It checks confirmed count mismatches outside combat and pauses after blank or unverifiable redraws. Explicit off settings remain saved.

Built for **WoW Forever 1.60.1**. Retail, other Classic clients and raid tracking are not supported.

### Credits

Created by Wolfie. Static fallback quest data adapts [QuestieDB](https://github.com/Questie/QuestieDB/tree/0f7d8adc92b28ac6594f4ad8745257f4d9784edf) and historic Questie contributions. Full upstream licensing, attribution and its historical caveat are bundled. Party Quests Forever is not affiliated with Questie. Its project icon is original artwork.

## Release changelog

Party Quests Forever 1.1.5-beta3

Beta behavior correction for WoW Forever 1.60.1 (interface 16001).

- Combat behavior now collapses the tracker to its compact header instead of
  hiding the whole tracker. All Objectives, Party Quests and the main + remain.
- Renames the Display option to Collapse tracker during combat; enabled by
  default and preserves an existing saved off choice.
- Restores the previous expanded or collapsed state after combat without
  changing quest/player expansion choices.
- Separate-window mode keeps its title bar during combat as well.
- Retains focused-quest highlighting, reopening restoration and shared Ready tags.

Changes to this setting during combat take effect after combat ends.
In-game confirmation of the corrected collapse behavior is pending.

## Submission references checked 2026-11-13

- https://support.curseforge.com/support/solutions/articles/9000197241-creating-and-submitting-a-project
- https://support.curseforge.com/support/solutions/articles/9000199552-overview-of-the-project-submission-page
- https://support.curseforge.com/support/solutions/articles/9000196615-known-issues

This package has not been submitted or published to CurseForge.
