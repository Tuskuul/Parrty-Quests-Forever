# Party Quests Forever 1.1.6-beta5 beta build record

- Native-only header artwork extends 24 UI units left, with original anchors
  and fixed widths saved/restored separately from the joined header state.
- Title, controls, right edge and height retain their existing geometry.
- Combat transitions reuse captured header regions without looking up protected
  tracker state; native anchors are restored when integration is disabled.
- Tests cover both sidebar sides, repeated fit without accumulation, native-only
  and combat transitions, two-edge art and exact restoration on detach.
- All 23 root Lua files parse; all 15 regression suites pass.
- Live-client alignment remains pending; public notes contain only user changes.
