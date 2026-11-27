# Questie tabs development build

Branch: `feature/questie-tabs`, based on stable 1.1.11. Build: `1.1.11-questie-dev1`.
This is an alternative PQF build for testing with Questie, not a release, a change to Questie itself, or a separate quest-data engine. No main/beta/alpha promotion or release tag is part of this work.

## User behavior

With Questie's tracker enabled, Settings → Tracker layout offers **Tabbed** and **Side by Side**. Tabbed is the default for this build's new `questieTrackerLayout` preference; the normal `defaultTrackerLayout` preference is preserved independently. The active tab is shared between providers. Both tabs remain available solo and in a party. The Party tab uses Questie's tracker position, scale and width, with a scrolling content area instead of a second sidebar. Questie's tracker stays intact on Objectives, including its header, item buttons, movement, sizing and collapse controls.

Switch to Objectives to move/resize Questie using its usual controls. Party Quests follows the resulting geometry. When Questie is minimized, the Party view retains the last usable height (420px fallback), capped to the screen. Hide/minimap actions select tabs rather than removing the tab bar. Combat tab/layout changes queue until combat ends. Auto-hide collapses only the Party pane; Questie's objectives keep Questie's own combat behavior.

The Party surface reads Questie's backdrop, border and overall alpha. Its own hover fading uses Questie's configured opacity and fader flag because a hidden Questie root cannot receive mouse events. It does not call Questie's hover scripts or change Questie's settings.

## Implementation and boundaries

`QuestieTabs.lua` is an optional visual provider in this branch's TOC. `TrackerTabs.lua` reuses the existing PQF tabs and renderer, while choosing a provider-specific visibility parent. The adapter reparents only the named `Questie_BaseFrame` root and preserves its original parent and frame level. Questie's anchors, scripts and shown/hidden intent are retained. Questie can continue Show/Hide and layout calls underneath a hidden ordinary parent without flashing through the Party tab. A non-secure parent deliberately avoids imposing Blizzard's protected tracker restrictions on Questie's combat updates.

Leaving tabbed mode, selecting a separate window, disabling Questie's tracker, or replacing/removing the root restores the outgoing parent and frame level. Unknown Questie profile state does not authorize visual ownership. Blizzard's provider retains the existing secure visibility parent and native execution boundary. Questie data, saved variables, private modules, communications and wire protocol are not modified.

Primary upstream source reviewed: https://github.com/Questie/Questie/tree/master/Modules/Tracker
- `TrackerBaseFrame.lua`: named UIParent root, drag/resize and backdrop.
- `TrackerHeaderFrame.lua`: header/icon controls are children of the root.
- `TrackerQuestFrame.lua`: scroll content is a child of the root.
- `TrackerFadeTicker.lua`: root backdrop/border fading.

This is a named-frame integration, not a promised Questie public plugin API. The installed WoW Forever Questie build must be validated in game. Other addons that continually reparent Questie's root may conflict. Questie's separate external durability/voice-over frames remain managed by Questie.

## Validation

`python3 run_checks.py` includes Questie-provider coverage for shared geometry, scale, hidden-root update flashes, original drag script preservation, independent settings, minimized height, solo availability, combat queuing/reopening, restoration, missing roots and switching between Questie and Blizzard. Existing native tracker and docking regression suites remain required. `python3 -m unittest discover -s tests -p test_auto_tag.py -q` checks publishing safeguards.

Before release, check in WoW Forever at 1920×1080: reload solo and grouped; alternate tabs while quest progress/turn-ins update; test Questie's locked/unlocked movement, scale, resizing, header-at-bottom and minimized modes; toggle backgrounds/borders/hover fade; enter and exit combat on both tabs and with a queued switch; leave/join a party; switch Side by Side / Tabbed / Separate window; disable and re-enable Questie's tracker. Confirm no flashing, stranded item buttons, blank native tracker, or Lua errors. Automated mocks do not establish live taint safety.

## Distribution

Replace the installed `SimplyPartyQuests` folder with this branch build. Do not install it beside production under another folder name: it shares PQF's saved variables and frame names. Existing production preferences and quest synchronization remain compatible; only the Questie layout preference is new. Do not tag or upload this development build to CurseForge.
