# Party Quests Forever 1.1.7-beta7 build record

Based on beta6 (0c5a296833043901b93166c1067e19dbbe50e57d). Addresses the gap and unequal background tops in the supplied Questie docking screenshot.

Geometry joins rendered fill edges, accounting for both inset backgrounds. The addon-owned pane remains numerically positioned beside Questie without parenting to or writing Questie frames. Public backdrop metadata and rendered title geometry are read defensively, with fallbacks. Font, scale and backdrop changes invalidate only the corresponding cached style. Standalone/Blizzard appearance is restored on undocking. Body spacing and total height include the actual title offset.

Validation: all 28 root Lua files parse; all 28 Lua regression suites and eight auto-tag tests pass. Questie docking coverage checks both sides, scaled fill-edge alignment, asymmetric backdrop padding, rendered label position, dynamic font/opacity, unchanged style caching, screen-edge fallback, compact solo mode, combat follow/reopen and leaving the adapter. Test frames reject all Questie writes and Blizzard tracker accesses in this path.

In-game review remains required for the actual border rendering: check opaque, translucent and disabled backgrounds, both docking sides and tracker/UI scales. The two panes keep independent content heights; the party pane does not reserve a tall empty column to match Questie's full log.
