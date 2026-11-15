# Party Quests Forever 1.1.6-beta1 beta build record

- Continues from stable 1.1.5; main remains stable.
- Sharing adds three actions with full-log and selected-quest scope.
- Copy uses a bounded owner-bearing in-game marker; Import never evaluates code
  or merges foreign quests into the player log or party caches.
- Tests cover forwarded-owner routing through request/response transfer,
  selected-only payloads, Ready and event completion flags, invalid imports,
  cache conflicts, 15-minute expiry and chat-draft/recipient preservation.
- All 23 root Lua files parse; all 15 regression suites pass.
- Packaging ignores test infrastructure and uses this beta's release notes.
- Live-client layout, clipboard shortcuts, forwarding and import remain untested.
- No stable promotion or manual CurseForge file upload is part of this beta.
