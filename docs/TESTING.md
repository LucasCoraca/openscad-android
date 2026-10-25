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
| ✅ | Undo, Edit-menu copy/paste (Android clipboard), Find (highlights, next), Replace | the cursor handle covers the field below for 4 s, as on Android (tap again) |
| ✅ | Tabs: several files, new file | |
| ✅ | Finger scrolling (editor, lists, text views) | QScroller on every scroll area; drags no longer select |

## 3D view
| | What | Notes |
|---|---|---|
| ✅ | Preview (F5 button) | |
| ✅ | CSG preview: difference / intersection | fixed: OpenCSG on gl4es |
| ✅ | Colours, text(), axes indicator | |
| ✅ | One finger: rotate | |
| ✅ | Two fingers: pinch zoom, pan | |
| ✅ | Long press: object menu, jumps to the source line; double tap: centre on the point | GLES cannot read depth: depth rendered offscreen as color (MouseSelector::depthAt) |
| ✅ | Thrown Together | |
| ✅ | Render (F6) with Manifold | |
| ✅ | View toolbar: view directions, view all, zoom, reset, perspective/orthogonal | objects vanished after some view changes: Qt changes GL state behind gl4es's caches; gl4es now resyncs at each frame |
| ✅ | Show edges, axes, scale markers, crosshairs | edges: ViewEdges.frag divided a vec3 by an int (not valid GLSL ES) |
| ⏳ | Perspective / orthogonal | |
| ✅ | Measure distance / angle by tapping points or edges (after F6) | |

## Menus and dialogs
| | What | Notes |
|---|---|---|
| ✅ | Menu bar, submenus | third-level submenus sometimes need a second tap |
| ✅ | Preferences: pages switch, Back closes | sound option has no effect |
| ✅ | Library Info | dialogs are now kept inside the space above the taskbar |
| ✅ | Menu item widths | labels were elided ("Para…tric"): Fusion metrics vs 72-dpi Android; fixed by a proxy style |
| ✅ | About (scrolls), Cheat Sheet (opens the browser) | |
| ✅ | Font List (system fonts via fontconfig), Color List (filter, tabs) | a docked tab opened from the Window menu is not raised (as upstream) |
| ✅ | Customizer: combo, spin box, slider, checkbox, auto preview, presets (+, -, select), detail modes, scrolling | editable preset combo has small rows; Android text handle lingers after the keyboard closes |
| ✅ | Animate: FPS/steps, play/pause, step, rewind | number fields get the full keyboard |
| ✅ | Export STL through the system file picker | content:// documents via a local copy |
| ✅ | Export: OBJ, 3MF, SVG, DXF, PDF, PNG (via the picker; option dialogs fit the screen) | 3MF (lib3mf) and PDF (cairo) were not built; PDF wrote 0 bytes |
| ✅ | Save As, Save (writes back to the document), Open (file picker) | |
| ✅ | Close the last tab | leaves an empty design (closing the window quit the app) |
| ✅ | Window menu: docks; splitter drag | dock sizes now survive the keyboard; the focused field is scrolled into view |
| ✅ | Console | |
| ✅ | Error log | backups folder was missing (fixed) |

## System
| | What | Notes |
|---|---|---|
| ✅ | Text fields with the on-screen keyboard (composing, suggestions) | `adb input text` (raw key events) can reorder letters; the keyboard itself does not |
| ⚠️ | Emulator-only: "stuck fence / GPU hang" ANR once under host load (swiftshader) | all app threads idle |
| ✅ | Taps land correctly in dialogs and menus | fixed in the Qt plugin |
| ✅ | No stale pixels after partial repaints | fixed in the Qt plugin |
| ✅ | Rotation; phone layout (1080x2400 @420dpi) | narrow portrait windows put the editor above the 3D view and side docks below; restored when wide; 3D toolbar overflows into a » menu |
| ✅ | App to background and back | via the browser; preview still renders |
| ⏳ | Translations | |
| ✅ | Back on the main window | sends the app to the background (closed OpenSCAD before) |
| ❌ | Grey box over the 3D view after typing in a dock field | Qt's hidden Android edit view at the old field position; goes away when focus moves |
