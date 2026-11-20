# Party Quests Forever 1.1.7-beta6 build record

Based on beta5 (4f049c6b14fd53962d43bae975cf13055689059c). Fixes the combat-exit visibility snapshot race reported with the Blizzard tracker and automatic collapse enabled.

Restoration now waits until both lockdown and the secure combat state have ended. Setup cannot overwrite the pre-combat snapshot during that interval. The secure exit does not first replay stale visibility; ordinary safe restoration checks current hasContents, saved collapse and native OnShow/OnHide intent. Addon-originated visibility changes are excluded from that intent. An explicit reopen supersedes earlier native hides. No full native tracker Update, module rebuild or aura query is introduced. The party-pane invalidation becomes due immediately after restoration. Questie cleanup clears deferred cycle state.

Validation: 28 root Lua files parse; 28 Lua suites and eight auto-tag tests pass. The new suite exercises 50 alternating event/driver exit orders, an exit before lockdown clears, rapid combat re-entry, newly populated modules, emptied modules, native hide/show intent and 20 preclosed cycles. Existing combat controls, ownership guards and package checks remain covered. Combat test frames now dispatch visibility hooks and preserve multiple HookScript handlers.

Live verification: disable Questie, enable combat automatic collapse, try several combats with the native tracker initially open and initially closed. Reopen during combat with both controls; gain progress or complete objectives during combat. After leaving, check content and saved collapse restore correctly without needing another combat or manual refresh. Local simulations validate ordering and visibility, not the client's full native layout or secure runtime.
