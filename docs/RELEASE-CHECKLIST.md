# Party Quests Forever 1.1.7-beta3 build record

Beta-only visual follow-up to the user's screenshot of beta2's oversized, opaque empty party pane. Main 1.1.6 and alpha6 remain unchanged.

Reads Questie_BaseFrame GetBackdropColor/GetBackdropBorderColor and effective alpha. Actual rendered colors take precedence over profile colors, preserving Questie's dynamic backdrop fade; explicit disabled settings remain transparent. Guarded profile fallback is used only when the rendered getters are unavailable, and an unsupported hover fader falls back to transparent rather than a fixed dark box. Background and border opacity remain separate from text: only overall tracker alpha affects party text. All changes apply to addon-owned frames; no Questie/native frame writes or private module calls are added.

Questie mode uses a plain backdrop, hidden native header art, simple member/zone headings, tighter content padding, a two-unit column gap and the matching rendered header font/scale. A compact menu retains Share/Refresh/Settings and draft capture; the heading independently toggles collapse and right-click opens the menu. Solo mode uses a 180-unit compact header, with no empty content box; party entry restores the configured width and saved collapse preference. Undocking restores normal art, controls, font and alpha before returning to the Blizzard integration.

Validation: 28 Lua sources parse; 27 regression suites and 8 auto-tag tests pass. The expanded docking suite covers rendered/fallback/disabled/zero/faded opacity, border alpha, overall transparency, header font/scale, compact toolbar/menu actions and chat draft capture, solo-to-party expansion, and restoration when leaving Questie. Existing scale/edge/combat/collapse/preference/native-isolation and map-collision checks remain green.

Live visual validation pending: compare Questie's background disabled/enabled, alpha slider and hover-fader states, border settings, header font/scale, side changes and drag/resize alignment. Inspect compact solo and populated party states, menu actions, combat collapse/reopen and returning to Blizzard. Automated mocks do not prove exact pixels or every secure-runtime interaction.
