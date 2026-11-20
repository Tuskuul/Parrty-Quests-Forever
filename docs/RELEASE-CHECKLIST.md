# Party Quests Forever 1.1.7-beta8 build record

Based on beta7 (faf0cfb98c5c76b7cc7aeeb8b5e3ae8cd64a3e3a). Addresses the supplied collapsed screenshot and the solo launcher needing minimap clicks after reload.

Collapsed dock sizing no longer subtracts a fixed amount from the expanded content padding: it explicitly includes title inset, font/control height and backdrop bottom padding. Questie controls scale together and native dimensions are restored on undocking. The compact solo launcher is allowed by dock visibility even without the session-only soloOverride, while trackerHidden continues to honor an explicit Hide. This does not change grouped or standalone visibility.

Validation: 28 root Lua files parse; all 28 Lua suites and eight auto-tag tests pass; 32 runtime/attribution package paths validate. Questie tests now use the real ShouldShowPartyView predicate for delayed startup: hidden target, shown target without geometry, then valid geometry. No minimap click occurs. They verify collapsed text/control bounds, repeated updates, larger font, mixed scales, both sides, saved hiding, solo expansion and native control-size restoration. Questie frame writes and Blizzard accesses are rejected by the fixture.

Live review: reload while solo with Questie enabled and verify the compact header appears automatically, then expand/collapse it. Repeat with large header text and a changed tracker scale; check both sides. Hide explicitly, reload and verify it remains hidden. Existing expanded alignment is retained. Local tests cover geometry and lifecycle; actual client border rendering remains a live check.
