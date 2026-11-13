# Blizzard tracker integration, 0.10.0

The party view is a separate module in the native ObjectiveTrackerFrame container,
not an overlay window and not a replacement for QuestObjectiveTracker. It appears
before the normal Quests section. Shared quests have their party comparison here;
your original quest entries retain Blizzard's controls. Foreign quests are addon
entries using known party data and are never inserted into your actual quest log.

The adapter creates a frame from ObjectiveTrackerModuleTemplate, mixes its own
settings/layout callbacks into that frame, and assigns it through
ObjectiveTrackerManager:SetModuleContainer. Blocks and lines use Blizzard's pools
and native generic templates. It does not patch native quest line getters,
completion animations, watch lists, quest block scripts or cache state.

The model reuses SPQ's shared-by-ID grouping and zone resolver. Collapse keys for
quests are shared with the window; native group collapse keys and native pagination
are separate. Three compact model entries appear per page. Long expanded details
may stay in the full hover tooltip to preserve space for remaining headings. The
module uses at most 280 pixels and manages its own overflow, so its truncation does
not force the container to suppress later native modules.

Attachment, model updates, mode changes and detach defer while in combat. Existing
party data remains subject to the native API's location and restricted-value
limits. Native unavailability shows the pop-out and retries; an exception in party
layout or an addon-block notification falls back to the standalone window. Mode,
page, clipping and errors appear in /spq report.

## Controls

- /spq tracker: native Party Quests section (the default after this update).
- /spq window: the existing resizable window, including its Combine and Zone buttons.
- Use Blizzard tracker in the pop-out: return to the native view.
- /spq or /spq show: toggle/show the current view.
- Module collapse button: native section collapse, remembered.
- Control row: click next page, right-click previous. On a single page, click refresh.
- Group/quest header: click expand/collapse.
- Any party block header: Shift-click refresh, Ctrl-click open pop-out.
- An owned party quest: right-click opens its normal quest details.
- Quest hover: full cached party progress and its group/zone.

## Source contracts reviewed

The published `forever` branch was consulted, not verified as byte-for-byte identical
to the user's installed build:

- https://github.com/Gethe/wow-ui-source/blob/forever/Interface/AddOns/Blizzard_ObjectiveTracker/Blizzard_ObjectiveTrackerModule.lua
- https://github.com/Gethe/wow-ui-source/blob/forever/Interface/AddOns/Blizzard_ObjectiveTracker/Blizzard_ObjectiveTrackerModule.xml
- https://github.com/Gethe/wow-ui-source/blob/forever/Interface/AddOns/Blizzard_ObjectiveTracker/Blizzard_ObjectiveTrackerContainer.lua
- https://github.com/Gethe/wow-ui-source/blob/forever/Interface/AddOns/Blizzard_ObjectiveTracker/Blizzard_ObjectiveTrackerManager.lua
- https://github.com/Gethe/wow-ui-source/blob/forever/Interface/AddOns/Blizzard_ObjectiveTracker/Blizzard_ObjectiveTrackerBlock.lua

Automated Lua mocks verify the adapter/model behavior, not a rendered in-game
tracker or protected-frame behavior. Validate the real templates, font scaling,
frame pooling, collapse/edit-mode behavior, combat deferral and error handling in
Forever. The earlier native tracker freeze is not established as fixed by this
integration; its separate optional redraw workaround remains available.

## First live test

1. Replace the existing addon files and use /reload.
2. Join a party. Confirm Party Quests appears inside All Objectives and the normal
   Quests section remains visible. If not, use /spq report and /spq window.
3. Expand a shared quest and an unowned quest; hover to inspect each member's data.
4. Check next/previous pages and zone collapse. Kill or loot a needed objective,
   leave combat, and verify the displayed counts update.
5. Turn in a quest; verify the party entry is removed on confirmed membership update
   without leaving a gap. Collapse/reopen the Party Quests section as well.
6. Switch between /spq window and /spq tracker. Verify saved names, sizes, grouping,
   expanded quests and normal quest click controls remain intact.
7. Check /spq report for clipped entries, attach errors or block notifications before
   attributing a native tracker freeze to the new module.
