# Party Quests Forever 1.1.6-beta6 beta build record

- Secure click snippets toggle captured native module visibility before calling
  ordinary Lua for header textures and addon-owned pane updates.
- Native tracker SetCollapsed/Update and module layout rebuilds are not called
  from the combat reopen path. The native header method only swaps textures.
- Combat polling respects manual-open state rather than hiding the pane again.
- Queue-after-combat fallback remains for calls without the secure click path.
- Tests model protected modules and the ordinary-Lua CallMethod boundary, reject
  insecure Show/Hide and native rebuilds, and exercise repeated buttons, redraw
  suppression/restoration, empty modules, pane visibility, opt-outs and combat exit.
- All 23 root Lua files parse; all 15 regression suites pass.
- Live-client secure reopening is experimental and remains to be verified.
