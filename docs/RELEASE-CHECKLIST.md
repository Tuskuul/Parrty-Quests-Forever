# Party Quests Forever 1.1.6-beta4 beta build record

- Shared-log scroll viewport ends 52 units above the window bottom; diagnostics
  occupies units 14-36, leaving a 16-unit gap between list and button.
- Explicit child clipping prevents quest rows drawing over the footer.
- All 23 root Lua files parse; all 15 regression suites pass.
- Live-client footer spacing verification is pending.
