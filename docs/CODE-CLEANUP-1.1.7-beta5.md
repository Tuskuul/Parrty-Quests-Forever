# 1.1.7-beta5 cleanup record

Based on beta4, commit 4cb5d0a543f1090ee9b5449dddd689f46b2d4f73.

## User-facing changes

Removed the redundant map sharing shortcut and its placement/collision scanner. Sharing remains accessible through the tracker, Questie menu, separate window and Settings. The separate window now keeps Share and Refresh in its action row; grouping and docking preferences remain in Settings. This recovers 55 UI units for quest rows. Removed the obsolete Alpha title. Blizzard-only repair controls are hidden while Questie owns the tracker without altering the saved preference.

## Runtime changes

The regular update pass checks Questie compatibility once. Direct UI calls still refresh ownership and geometry. Hidden standalone windows defer rebuilding their quest rows until opened; the dock continues to receive invalidations. Questie font, fixed anchors and collapse artwork are updated when their inputs change. Live font, opacity and scale changes remain supported.

Removed obsolete restoreNativeLayout bookkeeping and its no-op helper. Retained blockedRestore, deferred combat actions and native ownership guards. No native module rebuild or restricted aura access was added.

## Size and packaging

Excluded three promotional PNGs from installed packages while retaining them in GitHub. The runtime icon, all TOC entries, quest datasets and required license/attribution files remain included. Package estimates use ZIP deflate and literal .pkgmeta exclusions; actual CurseForge package size may differ. Before the final documentation edits, the estimate fell from 7,303,852 to 644,158 bytes (about 91%).

Runtime Lua excluding five static datasets fell from 6,324 lines / 350,614 bytes to 6,194 lines / 343,434 bytes: 130 lines and 7,180 bytes removed. Those datasets total 985,452 bytes and are byte-identical to beta4. They support quest details and eligibility and were retained deliberately.

## Validation and limits

28 root Lua files pass syntax checks; all 27 Lua regression suites pass. Eight auto-tag tests pass. Package checks cover 32 runtime/attribution paths and reject promotional artwork entering the package. Regression coverage includes hidden-window refresh, standalone controls, ownership-dependent settings, repeated dock styling, live font changes, direct versus regular compatibility checks, map independence and deferred native recovery.

QuestLogCopy, QuestLogSharePicker, QuestOffers, QuestShareDestinations, ChatCompatibility, BattleNetQuestLinks and ShareRequests are byte-identical to beta4. QuestLogLinks changes remove only map shortcut installation and placement code. Quest sharing protocols and payload formats are unchanged.

Live verification remains necessary for visual placement, Questie/Blizzard transitions, fresh content when reopening the separate window, retained sharing entry points and combat reopening. Mocked regression tests cannot prove in-game protected execution behavior.
