# Party Quests Forever 1.1.6-beta9 beta build record

- Live beta8 report: Party Quests opens in combat; native +/- still does not.
  This build changes settings and documentation only, not combat handlers.
  Native-pane spontaneous blanking fix is not yet confirmed by the user.
- Simplified settings: Display, Tracker/Window layout (conditional), Quests, Tools.
  Sidebar width stays adjustable and its current value is displayed.
- Removed settings controls: visible, collapsed, scan, redraw, shareApiProbe,
  clear and preview. Their underlying methods/existing slash commands remain;
  added /spq inspect for the removed API-inspector button.
- Troubleshooting expands on demand: diagnostics, report, fresh capture and
  mode-specific guarded native repair. Saved preferences are not migrated/reset.
- Existing runtime Lua regression suites and auto-tag checks must pass.
- In-game visual verification: settings scrolling, live mode switches, layout
  sections, troubleshooting expansion/collapse, sidebar width changes, saved
  preferences, share/refresh and diagnostic actions. No live client is available here.
