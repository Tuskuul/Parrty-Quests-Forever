# Party Quests Forever 1.1.5-beta3 beta build record

- Combat option collapses to a visible compact header, rather than hiding.
- Uses the normal native SetCollapsed method; no combat visibility driver.
- Expanded/collapsed state is captured outside combat and restored afterward.
- Explicit setting off is preserved; combat changes apply after combat ends.
- Popout title visibility and hidden-native state are regression checked.
- Shared Ready aggregation, highlight and reopening fixes retained.
- All 22 root Lua files parse; all 15 regression suites pass.
- In-game confirmation pending. No CurseForge publication performed.
