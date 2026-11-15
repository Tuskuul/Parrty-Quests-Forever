# Party Quests Forever 1.1.6-beta2 beta build record

- Copy/Import temporarily hide the chooser without finalizing its draft/state.
- All close paths return to the previous scope and quest selection; successful
  imports finalize the draft and open the viewer with both chooser dialogs closed.
- Repeated Share requests do not reopen the chooser over an active transfer.
- Both windows support dragging and screen clamping; anchors are set only once.
- Tests cover first/repeated opens, Copy Done, Import Cancel, invalid/successful
  imports, Escape and selection/draft preservation, plus existing regressions.
- All 23 root Lua files parse; all 15 regression suites pass.
- Main remains stable 1.1.5; in-game visual verification is pending.
