# Questie tabs development build

Branch: `feature/questie-tabs`, based on stable 1.1.11. Companion: **Party Questie Forever 0.1.0-dev1**.
This is a separate companion addon for normal PQF and Questie, not a release or a separate quest-data engine. No main/beta/alpha promotion or release tag is part of this work.

## User behavior

With Questie's tracker enabled, Settings → Tracker layout offers **Tabbed** and **Side by Side**. Tabbed is the default for the companion's `PartyQuestieForeverDB.layout`; normal PQF's `defaultTrackerLayout` is preserved independently. The companion has a Party Questie Forever AddOns settings category; the host's layout controls also reflect the active provider. The active tab is shared between providers. Both tabs remain available solo and in a party. The Party tab uses Questie's tracker position, scale and width, with a scrolling content area instead of a second sidebar. Questie's tracker stays intact on Objectives, including its header, item buttons, movement, sizing and collapse controls.

Switch to Objectives to move/resize Questie using its usual controls. Party Quests follows the resulting geometry. When Questie is minimized, the Party view retains the last usable height (420px fallback), capped to the screen. Hide/minimap actions select tabs rather than removing the tab bar. Combat tab/layout changes queue until combat ends. Auto-hide collapses only the Party pane; Questie's objectives keep Questie's own combat behavior.

The Party surface reads Questie's backdrop, border and overall alpha. Its own hover fading uses Questie's configured opacity and fader flag because a hidden Questie root cannot receive mouse events. It does not call Questie's hover scripts or change Questie's settings.

## Implementation and boundaries

The `PartyQuestieForever/` addon has its own TOC, namespace and saved variable. Its Bootstrap registers once through contract 1 of `PartyQuestsForeverAPI`, provided by the host's new `PluginAPI.lua`. Its controller reuses PQF's tab selection, labels, party renderer and quest engine, while supplying a Questie-specific visibility parent. Blizzard initialization, teardown and update logic delegate to the dependency's existing methods. No second PQF Core, event/polling loop, communications prefix, minimap button or quest database is loaded. The adapter reparents only the named `Questie_BaseFrame` root and preserves its original parent and frame level. Questie's anchors, scripts and shown/hidden intent are retained. Questie can continue Show/Hide and layout calls underneath a hidden ordinary parent without flashing through the Party tab. A non-secure parent deliberately avoids imposing Blizzard's protected tracker restrictions on Questie's combat updates.

Leaving tabbed mode, selecting a separate window, disabling Questie's tracker, or replacing/removing the root restores the outgoing parent and frame level. Unknown Questie profile state does not authorize visual ownership. Blizzard's provider retains the dependency's existing secure visibility parent and native execution boundary. Questie data, saved variables, private modules, communications and wire protocol are not modified.

Primary upstream source reviewed: https://github.com/Questie/Questie/tree/master/Modules/Tracker
- `TrackerBaseFrame.lua`: named UIParent root, drag/resize and backdrop.
- `TrackerHeaderFrame.lua`: header/icon controls are children of the root.
- `TrackerQuestFrame.lua`: scroll content is a child of the root.
- `TrackerFadeTicker.lua`: root backdrop/border fading.

This is a named-frame integration, not a promised Questie public plugin API. The installed WoW Forever Questie build must be validated in game. Other addons that continually reparent Questie's root may conflict. Questie's separate external durability/voice-over frames remain managed by Questie.

## Validation

`python3 run_checks.py` includes Questie-provider coverage for shared geometry, scale, hidden-root update flashes, original drag script preservation, independent settings, minimized height, solo availability, combat queuing/reopening, restoration, missing roots and switching between Questie and Blizzard. Existing native tracker and docking regression suites remain required. `python3 -m unittest discover -s tests -p test_auto_tag.py -q` checks publishing safeguards.

Before release, check in WoW Forever at 1920×1080: reload solo and grouped; alternate tabs while quest progress/turn-ins update; test Questie's locked/unlocked movement, scale, resizing, header-at-bottom and minimized modes; toggle backgrounds/borders/hover fade; enter and exit combat on both tabs and with a queued switch; leave/join a party; switch Side by Side / Tabbed / Separate window; disable and re-enable Questie's tracker. Confirm no flashing, stranded item buttons, blank native tracker, or Lua errors. Automated mocks do not establish live taint safety.

## Installation and dependencies

The companion TOC declares `Dependencies: SimplyPartyQuests, Questie`. Missing dependencies are handled by WoW's addon loader. An older PQF without `PartyQuestsForeverAPI` produces a clear plugin-support message and the companion stops without creating another engine.

Current stable CurseForge 1.1.11 predates the plugin API. The test bundle therefore includes **SimplyPartyQuests** (normal 1.1.11 plus only the small bridge and its TOC entry) and **PartyQuestieForever** as sibling addon folders. Keep the separately installed **Questie** folder. There are three enabled addons, not two copies of Party Quests. Main/beta/alpha are not updated by this branch work. A future normal PQF release must carry the bridge before the companion can be distributed alone to existing CurseForge users.

Build the bundle with `python3 tools/build_questie_companion.py /path/to/PartyQuestieForever_0.1.0-dev1_TestBundle.zip`. The builder reads both manifests, validates the archive and never tags or publishes. The base `.pkgmeta` explicitly excludes the companion directory, so normal addon packaging does not nest a second addon inside it.

Disable **Party Questie Forever** and reload to restore normal PQF docking and native tabs. Its layout preference stays in `PartyQuestieForeverDB`; quest logs and normal settings stay with PQF. Do not rename a complete PQF build and install both engines. Do not tag or upload this development bundle to CurseForge.
