# Party Quests Forever 1.1.6-beta11 beta build record

Baseline: beta10, 2fff71023a1435b931e1464483c1d2204cfa4739.

User capture retained at least 340.2 seconds of activity. It contained two
Frame:Show blocks and four OpenSettingsPanel blocks, no recorded secure combat
stages or overlay/modules, and suspended repair with zero redraw requests.
The report did not distinguish disabled auto-collapse from missing initialization.

Changes:
- Queue Settings requests before any panel initialization/native access in combat.
  The existing tick opens once after lockdown ends; repeated requests coalesce.
- Log blocked actions, but ignore settings blocks for tracker restoration/repair.
  Other unrelated blocks preserve the repair preference; a block during an actual
  redraw or verification still suspends repair. Existing saved opt-outs stay off.
- Report auto-collapse preference, setup status/phase/error, required global API
  availability, controller, driver, module count and queued settings request.
- Bound setup failure retries to ten seconds. Explicit option changes allow a fresh
  attempt. Module initialization errors no longer vanish behind the native iterator's
  pcall, and partially initialized modules are not incorrectly marked complete.

Validation: 23 Lua sources parse; 18 regression suites; 7 auto-tag tests.
New tests cover repeated combat settings requests, exactly one post-combat open,
setup-disabled/missing-API/native-unavailable/failure cases and retry backoff.
Repair tests distinguish unrelated UI blocks from verification/in-flight failures.

Live checks: Settings in combat, queued open after combat, /spq report setup status,
native +/- and Party Quests clicks, and spontaneous native-pane blanking. This build
does not claim native +/- is fixed. Do not promote to 1.2.0 on automated checks alone.

See AUDIT-1.1.6-beta10.md for the preceding full audit.
