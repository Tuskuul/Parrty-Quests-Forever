# Party Quests Forever 1.1.4 release record

- Own progress is independently collapsible and defaults closed; party progress
  remains expanded. Combat toggles and per-quest state are regression checked.
- Regression coverage verifies two players with distinct counts and separate rows.
- Main collapse restores the compact native header, hides party contents and
  shared backdrop, and expands back to the joined centered header.
- Combat shared-background resizing measures current native bounds read-only.
- Automatic combat party reflow, own-log event deadlines and heartbeat covered.
- Existing native redraw guards, opt-outs and combat deferral preserved.
- All 22 root Lua files parse; all 13 regression suites pass.
- Existing SavedVariables and install-folder identity retained.
- User confirmed compact collapse/restore in-game and approved the readability
  changes for a small stable update. No CurseForge publication performed.
