# Party Quests Forever 1.1.7-beta9 build record

Based on beta8 (a68952619ac05b3574f76c957104c6c7dd716b3d). User clarified that party-only automatic display is intentional. Reverted the beta8 solo startup exception, keeping the collapsed title/control bounds fix and scaled control restoration.

Validation: 28 root Lua files parse; 28 Lua suites and eight auto-tag tests pass. Docking coverage uses the real ShouldShowPartyView predicate: delayed solo startup remains hidden, joining a party displays it without a user click, leaving the party hides it, and explicit solo opening still works. Explicit Hide, larger fonts, mixed scale, both sides, collapsed text/control bounds and leaving Questie style remain covered. Live visual verification is still needed.
