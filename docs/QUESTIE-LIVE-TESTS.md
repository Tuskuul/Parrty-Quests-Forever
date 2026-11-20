# Questie live validation

## Alpha2 — user report

User reports no glaring issues or Lua errors with Questie while **not in a party**.

This establishes an initial solo observation only. The report does not specify Questie/QuestieDB versions, tracker setting, combat coverage, or UI scale. Party discovery, shared objective progress, joining/leaving groups and combat with the party view open remain unverified by this report.

Alpha3 adds beta17's quest-difficulty coloring while retaining alpha2's compatibility guards. The alpha2 observation is not treated as live validation of alpha3's new colors.

## Alpha6 — grouped combat and progress

User report: client 1.60.1 build 70959 (Nov 13 2026), Questie 12.11.0 with tracker disabled (maps-only), Blizzard left sidebar, party of four. Capture contains three PLAYER_REGEN_ENABLED events, no recorded addon-block notifications, no native cleanup error, no progress-processing errors, and visible native counters matching local quest log/API counters. User then confirmed counters working properly and approved 1.1.6 release while moving Questie work into 1.1.7 beta.

This is positive evidence for the tested session, not proof that every taint path or Questie tracker-enabled configuration is covered. Beta1 retains alpha6 gameplay logic and switches back to the normal saved-settings table.

## Beta9 observations before 1.1.7 promotion

The user confirmed expanded and collapsed alignment looked better, then confirmed the populated party layout looked good. They reported that combat hiding collapsed and restored the party pane correctly, no Lua errors had appeared, and quest updates seemed to work. Automatic display remains party-only by explicit user preference. These observations support the tested Questie session; they do not prove every native tracker or addon combination.
