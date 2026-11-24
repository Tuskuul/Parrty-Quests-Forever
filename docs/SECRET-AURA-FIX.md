# Legacy Forever secret-aura compatibility fix

Status: included in 1.1.8. This is a targeted workaround for a native-client defect,
not a claim that every possible source of UI taint has been removed.

## Reported failure

On leveling, the user received two errors at the same timestamp. One surfaced
from Edit Mode's anchor-change broadcast, the other from the scenario objective
tracker layout. Both reached `ShouldShowMawBuffs` and its unguarded
`C_UnitAuras.GetAuraDataByIndex("player", 1, "MAW")` read while auras were secret.
The reported taint context was SimplyPartyQuests.

The addon level-up handler schedules its own difficulty-color refresh after
0.2 seconds. Inspection found no aura read in that handler. The supplied stacks
do not establish which earlier operation first tainted execution.

## Evidence

- Forever-specific report of the same Edit Mode path:
  https://github.com/Stanzilla/WoWUIBugs/issues/890
- Related native layout/collapse failure:
  https://github.com/Stanzilla/WoWUIBugs/issues/882
- Older predicate in the Forever source:
  https://github.com/Gethe/wow-ui-source/blob/forever/Interface/AddOns/Blizzard_MawBuffs/Blizzard_MawBuffs.lua
- Upstream revision replacing the aura lookup with a presence API:
  https://github.com/Gethe/wow-ui-source/blob/ea64ca56ccee872795edd8c70ae0d96e364bf250/Interface/AddOns/Blizzard_MawBuffs/Blizzard_MawBuffs.lua

The newer API must not be assumed to exist on the user's older Forever build.

## Implementation and limits

`NativeAuraCompatibility.lua` applies only to interface 16001. When the newer
`C_MawBuffs.HasAnyMawBuffs` API exists it does not install a workaround. When
the legacy predicate and `C_Secrets.ShouldAurasBeSecret` are available, it wraps
the small global `ShouldShowMawBuffs` predicate. That is an intentional native
global replacement, not a secure hook or a general taint barrier.

While aura data is readable the original predicate is used unchanged. While
secret, unknown, or failing the secrecy check, the wrapper does not read aura
data and returns only the safely available tower condition. Consequently an
aura-only Maw indicator is omitted during secrecy on the affected old client;
normal quest modules, broadcasts, and tracker updates are not disabled.

The workaround never changes the aura API, scenario layout, Edit Mode handlers,
or native tracker update functions. It does not swallow errors thrown by the
original predicate in a readable state. It supports late loading and does not
stack wrappers or overwrite a later replacement by another addon.

This avoids the known failing read; it does not repair already-tainted native
state, guarantee that every other secret-value issue is fixed, or resolve the
separate TomTom/CompactUnitFrame health-color error.

The diagnostic report includes `Native aura compatibility:` with installation
status. No user-facing setting is added for this compatibility detail.

## Validation

`python3 run_checks.py`: 30 source files syntax checked; 30 regression suites
passed; package manifest checked with zero errors.

The new suite models both native entry paths continuing past the predicate,
readable behavior, secrecy/unknown/failure handling, tower fallback, late
loading, wrapper ownership, and modern/non-Forever exclusions. Existing combat,
native refresh, Questie, sharing, and scheduling suites remain green.

Mocks cannot reproduce the game client's actual taint engine. In-game validation
is still required in the combined release: reload, confirm guard status, level
with Questie active, check tracker updates, enter/exit Edit Mode, then exercise
combat collapse/restoration. Repeat without Questie as a separate case. Record
GetBuildInfo and any new stack. Do not force native frame updates from a macro
as part of the ordinary test.

The combined 1.1.8 release also includes ready-only XP and Questie docking refinements.
