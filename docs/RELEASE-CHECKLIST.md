# Party Quests Forever 1.1.7-alpha4 build record

Selected mockup: warmer aged umber parchment. The native paper texture is tinted at 65% brightness by default, with a saved 35–100% brightness slider and reset action under Quest windows. Ordinary text, ready and error states use a contrasting light palette below 80%, and dark ink above that. Difficulty colors remain native. Copy/Import text uses an independent dark input role.

The shared styling registry updates existing windows and font strings immediately without rebuilding input fields or selections. Alpha also recolors its parchment pop-out rows and inline objective/status text. Native Blizzard frames and beta's standalone dark window are not reskinned.

Validation: Lua syntax and full regression suites on each branch, including saved/invalid values, live palette/texture updates, input contrast and existing draft/selection preservation. Tagging tests run for each branch. Live verification remains necessary for actual client texture appearance and the slider.

Prior intermittent map-marker clipboard taint and combat blocked-action reports remain unresolved; no change here claims to fix them. Main is unchanged.
