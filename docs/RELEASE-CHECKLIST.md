# Party Quests Forever 1.1.6-beta17 beta build record

Baseline: beta16, 86780be1b9b08269ca1d44fc93433abe6c5f180c.

Quest title presentation uses GetDifficultyColor with C_PlayerInfo.GetContentDifficultyQuestForPlayer, matching the native quest list. A legacy native level/color API is a fallback. Invalid, missing or restricted values leave the existing text color. Acceptance minimum levels are never used as difficulty levels. Colors are computed locally and never serialized.

Applies to the joined tracker, standalone combined/member lists, received log and offer titles, selected/shareable quest lists and owner confirmation. Completion/objective text and eligibility reasons retain their existing status colors. Level-up and quest-data events refresh open lists without resetting selections.

Validation: source syntax, complete Lua regression suite, tagging tests. Live verification: compare red/orange/yellow/green/gray quests against the native list; check selected/offer/received logs and level-up with an open list. Confirm ready and ineligible labels remain readable on parchment.

The prior intermittent map-marker CopyToClipboard block and earlier combat blocked-action reports remain unresolved. The provided post-reload taint capture did not reproduce them. This build makes no map, chat routing or combat protection changes. Main remains 1.1.5; Questie alpha work is separate.
