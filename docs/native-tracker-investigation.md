# Native objective tracker investigation

## Evidence from this session

The player's Sharing the Land details showed 10/10, 8/8 and 5/5 complete while
the native objective tracker showed 0/10, 0/8 and 0/5. The user confirmed that
refreshing Blizzard's objective tracker corrected the display. SPQ's retained
report separately captured the other player's counts increasing, readiness,
and eventual removal after two validated membership passes. Those party events
are evidence of working party polling, not a recording of the player's native
tracker state. No before-refresh native API/visible-block comparison was captured.

## Source inspection

Reviewed the published `forever` branch of Gethe/wow-ui-source. This is a
source reference, not proof it exactly matches client build 70888:

- https://github.com/Gethe/wow-ui-source/blob/forever/Interface/AddOns/Blizzard_ObjectiveTracker/Blizzard_QuestObjectiveTracker.lua
- https://github.com/Gethe/wow-ui-source/blob/forever/Interface/AddOns/Blizzard_ObjectiveTracker/Blizzard_ObjectiveTrackerModule.lua
- https://github.com/Gethe/wow-ui-source/blob/forever/Interface/AddOns/Blizzard_ObjectiveTracker/Blizzard_ObjectiveTrackerBlock.lua

The quest module handles QUEST_LOG_UPDATE by marking itself dirty. Its event
list does not directly include QUEST_WATCH_UPDATE or UNIT_QUEST_LOG_CHANGED.
The report nevertheless contains numerous QUEST_LOG_UPDATE events, so a missing
subscription alone does not establish the cause. Dirty layout and existing
block/animation states determine what is refreshed. DoQuestObjectives reads
GetQuestLogLeaderBoard for an indexed objective and writes its text through
AddObjective. GetExistingBlock and GetExistingLine provide read-only lookups
for comparison. MarkDirty schedules the native redraw through its container.

SPQ 0.9.1 does not replace Blizzard's objective getter functions, unregister the
native tracker's events, install tracker hooks or mutate its quest blocks. This
rules out those specific interference mechanisms, not every possible interaction
or interference by another addon. A stuck layout, an error interrupting an
update, an animation issue, API timing, or another addon's interference remain
unresolved hypotheses.

## Delivered in 0.9.2

`/spq report` compares the live objective API and legacy leaderboard text with
current native objective text and animation state. Count differences receive a
COUNT MISMATCH label. An animation in progress may temporarily differ; a mismatch
is an observation, not proof of a permanently stuck tracker. Reports sample
when requested outside combat, not by modifying Blizzard's UI or its event hooks.
ADDON_ACTION_BLOCKED/FORBIDDEN notifications are retained in a small bounded ring;
the addon named by a notification is not necessarily the original cause of taint.

`/spq blizzard refresh` requests one redraw, delayed until out of combat.
`/spq blizzard on` enables a saved, default-off workaround that requests a delayed
native redraw on local quest progress signals or changed local objective data.
Bursts share one deadline; requests have a two-second minimum gap. It does not
untrack/retrack quests, change watch order, set progress, or copy party counts.
Errors and block notifications naming SPQ disable automatic requests. A successful
MarkDirty call means the request was made, not that the screen was verified fixed.
`/spq blizzard off` disables the workaround and cancels its queued request.

## Next live check

1. Install and restart WoW, because NativeTracker.lua is a new TOC entry.
2. Keep automatic redraw off initially. If the display sticks again, capture
   `/spq report` before refreshing. Capture outside combat.
3. Run `/spq blizzard refresh`, wait two seconds, and compare the screen/report.
4. If the manual request works, enable `/spq blizzard on` to test automatic recovery.
5. If the request does not work, keep the report; do not repeatedly rebuild quest
   watches. The native text, API state and block notifications determine the next step.

Automated Lua mocks cover comparison, read-only report behavior, secret values,
manual scheduling, local-only triggers, coalescing, throttling, combat deferral,
unavailable modules, automatic error shutoff and block-event capture. No in-game
execution or specific root-cause reproduction has been performed by the assistant.
