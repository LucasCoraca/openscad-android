# UI test checklist (Android)

Everything is tested by tapping the real UI on the emulator (`tools/dev.sh`, `tools/touch.py` for two-finger
gestures), not through shortcuts. ✅ works · ❌ broken (see notes) · ⏳ not tested yet.

Emulator: tablet 1600×1000, density 240 (rounded to device pixel ratio 2), x86_64, swiftshader GPU.

## Welcome screen
| | What | Notes |
|---|---|---|
| ✅ | New | |
| ⏳ | Open (file picker) | |
| ✅ | Help | opens the browser |
| ✅ | Examples tree: expand, select, Open Example | |
| ✅ | Recents list, Open Recent | |
| ⏳ | Don't show again | |

## Editor
| | What | Notes |
|---|---|---|
| ✅ | Typing (soft keyboard appears, layout resizes) | |
| ✅ | Syntax highlighting, line numbers, folding markers | |
| ✅ | Autocompletion popup while typing | was crashing / freezing; fixed in the Qt plugin |
| ✅ | Window grows back when the keyboard hides | |
| ✅ | Tap to place cursor (keyboard appears) | |
| ⏳ | Long-press selection, copy/cut/paste | |
| ⏳ | Undo / redo, indent, comment, find & replace | |
| ⏳ | Tabs: several files, close tab | |
| ✅ | Finger scrolling (editor, lists, text views) | QScroller on every scroll area; drags no longer select |

## 3D view
| | What | Notes |
|---|---|---|
| ✅ | Preview (F5 button) | |
| ✅ | CSG preview: difference / intersection | fixed: OpenCSG on gl4es |
| ✅ | Colours, text(), axes indicator | |
| ✅ | One finger: rotate | |
| ✅ | Two fingers: pinch zoom, pan | |
| ⏳ | Long press: selection menu; double tap: centre | |
| ✅ | Thrown Together | |
| ✅ | Render (F6) with Manifold | |
| ⏳ | View toolbar: all buttons | |
| ⏳ | Show edges, axes, scale markers, crosshairs | |
| ⏳ | Perspective / orthogonal | |
| ⏳ | Measure, selection | |

## Menus and dialogs
| | What | Notes |
|---|---|---|
| ✅ | Menu bar, submenus | third-level submenus open only on a second tap |
| ✅ | Preferences: pages switch, Back closes | font size combo shows -1; sound option has no effect |
| ✅ | Library Info | OK button partly under the taskbar |
| ❌ | Help menu item widths | "OpenSCAD Homepage" elided |
| ⏳ | About, Cheat Sheet, Documentation | |
| ⏳ | Font List | |
| ⏳ | Customizer | |
| ⏳ | Animate | |
| ✅ | Export STL through the system file picker | content:// documents via a local copy |
| ⏳ | Export: 3MF, OFF, AMF, DXF, SVG, PDF, PNG, CSG | |
| ✅ | Save As, Save (writes back to the document), Open (file picker) | |
| ✅ | Close the last tab | leaves an empty design (closing the window quit the app) |
| ⏳ | Window menu: docks, hide/show editor/console | |
| ✅ | Console | |
| ✅ | Error log | backups folder was missing (fixed) |

## System
| | What | Notes |
|---|---|---|
| ✅ | Taps land correctly in dialogs and menus | fixed in the Qt plugin |
| ✅ | No stale pixels after partial repaints | fixed in the Qt plugin |
| ⏳ | Rotation / phone layout | |
| ⏳ | App to background and back | |
| ⏳ | Translations | |
