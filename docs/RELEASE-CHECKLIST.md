# Party Quests Forever 1.1.5-beta2 beta build record

- Default-on combat auto-hide setting preserves explicit opt-outs.
- Native visibility uses Blizzard's secure visibility driver with a combat-only
  hide condition; out-of-combat visibility is not forced by the driver.
- Addon contents/background are hidden while auto-hide is active.
- Prior hidden/collapsed choices are preserved; changes during combat defer.
- One native full layout on out-of-combat reopen/combat exit restores expanded
  module contents. Count-mismatch repair guards remain unchanged.
- Combined-parent readiness aggregates actual holders and rejects mixed/unknown
  or missing state; parent and per-player tags are regression checked.
- All 22 root Lua files parse; all 15 regression suites pass.
- Focus highlighting, readiness and combat opt-out behavior covered.
- In-game verification pending. No CurseForge publication performed.
