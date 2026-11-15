# Party Quests Forever 1.1.6-beta7 beta build record

- User confirmed beta6 Party Quests combat reopening worked; native +/- did not.
- Beta7 routes main combat clicks through a dedicated addon-owned secure button
  over the visible native control. It is shown/hidden by the secure state driver
  and is absent outside combat or when automatic collapse is disabled.
- Native OnClick is no longer wrapped; replacing it cannot remove the dedicated
  combat click handler. The working Party Quests button path is retained.
- Tests cover dedicated-control anchoring, secure visibility, native handler
  replacement, combat toggles, opt-outs and restoration outside combat.
- All 23 root Lua files parse; all 15 regression suites pass.
- Live-client main +/- click behavior still needs verification.
