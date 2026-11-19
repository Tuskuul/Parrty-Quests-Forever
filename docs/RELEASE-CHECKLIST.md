# Party Quests Forever 1.1.6-beta20 build record

Native restoration now reconciles the addon sidebar without directly calling the full Blizzard container Update, module SetCollapsed, or ContentsFrame Show. Required out-of-combat native collapse changes and guarded quest-module MarkDirty requests use securecallfunction with the original native method, reject methods marked insecure by issecurevariable, and have no direct-call fallback. This is an execution boundary, not a combat bypass or a repair for an already-tainted session.

Combat background sizing reads actual native collapse when no prepared controller owns visual collapse. Alpha Questie cleanup preserves sidebar collapse state. Existing prepared-controller combat behavior is retained.

Validation: source syntax, Lua regression suites including collapsed Questie background reproduction and native-call isolation, and automatic-tag tests. Live validation remains required: fully restart/reload into this build; test native and Party Quests collapse before/during/after combat, with Questie maps-only and without Questie, solo and in a party. Confirm no blank backdrop, aura error, blocked Show/SetPoint, lost quest rows, or changed collapse preference. Check naturally progressing local quest counters and manually requested refresh on a genuine mismatch.

The original intermittent map-marker clipboard taint is not claimed fixed. Main remains unchanged.
