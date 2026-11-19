# Questie docking — 1.1.7-beta3

Source inspected: [Questie at 58f8a2c2b08560283e7a1bd2bd4a81e2284c505e](https://github.com/Questie/Questie/tree/58f8a2c2b08560283e7a1bd2bd4a81e2284c505e), especially Modules/Tracker/TrackerBaseFrame.lua, TrackerHeaderFrame.lua and QuestieTracker.lua. The first two create named Questie_BaseFrame and Questie_HeaderFrame frames. QuestieTracker computes manual/automatic width and height; header location changes with collapse and the header-at-bottom option. This upstream snapshot is not proof of every installed package's internals.

Party Quests reads these named frames' visible bounds and effective scale, then positions its own sidebar numerically relative to UIParent. It does not anchor to Questie, import private modules, add secure children or replace tracker scripts. No shared background is stretched across Questie's tracker. The existing party sidebar renderer and controls are reused in a separate visual column.

Height follows the visible Questie tracker up to screen bounds; a minimized tracker retains the last expanded party height so the independent pane remains usable. A top header aligns the party title; a bottom header does not pull the party pane down to the bottom. Side preference is respected when it fits, otherwise the roomier side is used. If neither side has 320 UI units, the existing standalone mode is used temporarily. Requested preferences are not rewritten.

All named-frame reads are guarded and missing/hidden/invalid geometry falls back. Entry/handoff is deferred during combat; an already-independent pane may follow geometry changes during combat. Our collapse and visibility preferences never toggle Questie's tracker. Native Blizzard refresh and secure combat control remain paused as in beta1. The named UI frames are an integration surface rather than a public stability contract; a future Questie redesign may require an adapter update.

Map share-button placement is generic and does not assume Questie caused the collision. It reads visible button rectangles in a bounded subtree of WorldMapFrame and moves only the Party Quests control. Other controls and map-marker handlers are untouched. This does not claim to resolve the older intermittent clipboard taint report.

## Beta3 appearance

The screenshot review exposed beta2's fixed 0.35 background alpha and full-width toolbar as visually inconsistent with Questie. Beta3 uses the named tracker's rendered backdrop and border colors (including fade alpha), with an overall effective-alpha ratio for matching inherited transparency. Profile fallback recognizes trackerBackdropEnabled, trackerBackdropColor, trackerBackdropFader and trackerBorderEnabled; it never writes them. TrackerBaseFrame.lua and TrackerFadeTicker.lua at the source snapshot above demonstrate that hover fading changes backdrop alpha independently of text alpha.

The party pane uses addon-owned BackdropTemplate art matching Questie's simple white-fill/tooltip-border layout. Normal Blizzard background art is hidden only while this adapter is active. Native member/zone header bars are likewise suppressed only for the Questie renderer. The rendered Questie_HeaderFrame.trackedQuests.label font is read to align header typography and scale. Leaving the adapter restores the prior controls, font, alpha and native art.

Dock gap is two UI units. The party title aligns with the top Questie header and the available party height ends at the same lower bound. A bottom-positioned Questie header does not drag the whole party column down. Solo mode uses a compact 180-unit heading near the tracker, while grouped mode retains configured width. The ... menu and right-click heading provide Share/Refresh/Settings; no Questie buttons or tracker scripts are replaced.
