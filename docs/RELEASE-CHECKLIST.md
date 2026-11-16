# Party Quests Forever 1.1.6-beta12 beta build record

Baseline: beta11, f9d02391f03473cc19a33672de461e38b7155bc5.

The user confirmed that combat toggles work when the tracker starts expanded,
but a tracker closed before combat cannot reopen until combat ends. The latest
report records native and party click entry during combat with setup ready.
Earlier combat periods also recorded ObjectiveTrackerFrame:Show and Frame:SetPoint
blocks. These do not establish which call caused the last reproduction.

Source checked: Gethe/wow-ui-source at bebcb6bf309cf41b41bd74f8ca651e6a105b2676,
Blizzard_ObjectiveTrackerContainer.lua SetCollapsed/Update and
Blizzard_ObjectiveTrackerModule.lua Update/EndLayout. Native collapsed state
causes EndLayout to hide modules even when their contents have been prepared.
The old combat callback changed visibility/header art but left that native
collapsed state intact. This is a code-level cause addressed by this beta;
automated tests cannot establish that it is the sole live-client cause.

Changes:
- With combat auto-collapse enabled, prepare the actual native expanded layout
  outside lockdown and retain a separate visual collapse preference.
- The addon-owned main control handles visual collapse outside combat as well.
  It does not invoke native SetCollapsed/Update while combat is locked down.
- Existing native collapse changes are picked up by the integration hook and
  normalized outside combat; guards prevent recursive native layout preparation.
- Secure and ordinary module show hooks respect visual collapse. Combat exit
  restores the prior closed/open appearance; disabling the option restores native
  ownership and the current outside-combat collapse preference.
- Joined art, sidebar visibility, queued expansion and repair readiness use the
  same visual collapse state. Reports expose prepared layout and native state.

Validation: 23 source files parse; 18 Lua regression suites; 7 auto-tag tests.
Expanded combat regression covers pre-collapsed preparation, both combat controls,
native visibility refresh, post-combat restoration, outside-combat toggle and
option-off ownership restoration, with protected addon-Lua writes prohibited.

Live check: Outside combat close with -, enter combat, reopen with +, collapse,
reopen with Party Quests; confirm visible quest rows, no blocked actions and
restoration after combat. Also check collapse/expand outside combat and option-off
behavior. If unsuccessful, capture /spq report during combat after both clicks.
No stable promotion on automated checks alone. Keep main at 1.1.5.
