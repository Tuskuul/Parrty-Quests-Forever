# Party Quests Forever 1.1.5-beta4 beta build record

- Secure state handler hides native modules while keeping the main header visible.
- Secure click wrappers reopen both columns from the compact Party Quests/main
  controls during combat; normal Party Quests toggling remains when expanded.
- Normal full native collapse/Update is not invoked from combat auto-collapse.
- Regression executes the actual secure snippet bodies for state transitions,
  module redraw suppression and click handling, using mocked frame handles.
- Prior native collapsed state and opt-out remain covered.
- Out-of-combat Party Quests clicks expand a genuinely collapsed native tracker.
- All 22 root Lua files parse; all 15 regression suites pass.
- In-game verification pending. No CurseForge publication performed.
