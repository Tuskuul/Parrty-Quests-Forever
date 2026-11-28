# Party controls and quest-category audit

Included in Party Quests Forever 1.2.0.

The tracker separates Shared quests from Party members. Collapse all first closes individual member logs; when all member logs are closed, another click hides the names into a slim count bar. Expand restores the names with their logs closed. Expand all restores names and opens their logs, zone groups, quest details and own-progress rows. Shared quest expansion states are preserved. Share / Refresh / Settings use matching dark framed buttons. This applies to the normal tracker renderer, including the companion's reused renderer.

Both reported quests are explicitly Undead Paladin quests in the pinned QuestieDB Forever records: Making Repairs (91316) and Diplomatic Incident (91858), with requiredClasses = classIDs.PALADIN and zoneOrSort = sortKeys.PALADIN.

The static importer previously accepted numeric and zoneIDs values, skipping sortKeys values. The corrected import restores 257 assignments across class, profession and other quest sorts. Audit against the existing pinned QuestieDB snapshot: 5,194 bundled category assignments, 951 unique correction-layer assignments checked, zero unresolved correction expressions, zero mismatches, and zero used categories lacking an English fallback label. Added the missing Blackrock Mountain area-25 fallback, supported by inherited quest 3906's explicit destination text. A zero live category now falls back to bundled data instead of overriding it with Unknown zone. Quests without an authoritative upstream category remain unknown; no destinations are guessed from titles or player location.

Leaders of the Fang (914) was present in a collapsed Wailing Caverns group; the user confirmed expanding it resolved the report. No matching or completion behavior was changed for that quest.

Local validation: 34 Lua regression suites, 12 Python tests and the package manifest pass. New coverage includes the shared completed Fang quest, both Paladin categories, zero-metadata fallback, party header rendering, button states, two-stage collapse, expansion and combat routing. Automated mocks do not replace live visual/combat validation.

Primary metadata: https://github.com/Questie/QuestieDB/blob/0f7d8adc92b28ac6594f4ad8745257f4d9784edf/src/corrections/Forever/generated/foreverBaseQuest.lua and src/corrections/enum/quests.lua.
