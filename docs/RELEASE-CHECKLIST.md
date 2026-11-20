# Party Quests Forever 1.1.7 release record

Promotes tested beta9 (f0804a1998badc863b82d9fe2a875b2e8c3b811e) to the stable main branch, authorized by the user. Runtime behavior is identical to beta9; only version metadata, diagnostic version text and release documentation change.

Validation: 28 root Lua files parse; 28 Lua regression suites and eight automatic-tag tests pass. Package checks validate 32 runtime/attribution paths. All runtime Lua except the diagnostic version string are byte-identical to beta9. Five static datasets and all sharing modules remain unchanged. The existing main-branch workflow requires a stable X.Y.Z version and publishes the matching tag only after checks pass.

User live observations on beta9: expanded, collapsed, solo/manual and populated party docking looked correct; party-pane combat collapse/restoration worked; no Lua errors had appeared; quest updates appeared to work. These are reported observations, not comprehensive coverage of every client state or addon combination. Automated tests retain native/Questie ownership guards, combat ordering, party-only visibility and sharing coverage.

Distribution: main uses 1.1.7; beta retains 1.1.7-beta9 for reproducibility. The stable version tag triggers the existing CurseForge packaging webhook. CurseForge processing/approval must be verified separately from GitHub CI and tag creation.
