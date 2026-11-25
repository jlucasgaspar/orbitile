<p align="center">
  <img src="docs/images/icon-light.svg" alt="Orbitile" width="128" height="128">
</p>

<h1 align="center">Orbitile</h1>

<p align="center">
  Tile any window on macOS with one click of the middle mouse button.<br>
  A radial menu opens at your cursor, you pick a layout, and the window snaps into place.
</p>

<p align="center">
  <img src="docs/images/demo.gif" alt="Orbitile in action: open the fan, pick a layout, drag across cells, the window snaps into place" width="720">
</p>

> The images are rendered by the app's own SwiftUI views over a mock desktop, so they match what the app draws. Regenerate them with `swift run Orbitile --scenes <folder>`. The backdrop blur and the real window movement are not part of those renders.

## What it does

Hover a window, click the middle button, and a ring of four layouts opens around the cursor. Move to a layout, pick a cell on the mini screen, and the window moves there. A blue preview shows the exact destination on your real screen before you commit.

| Open | Click a cell | Drag to merge | Preview on screen |
| :---: | :---: | :---: | :---: |
| <img src="docs/images/open.png" width="200"> | <img src="docs/images/click.png" width="200"> | <img src="docs/images/drag.png" width="200"> | <img src="docs/images/preview.png" width="200"> |
| Hover a family on the ring | Press a cell, release to apply | Drag across cells and release | The real target, before you commit |

### Layouts

| Family | Position on the ring | Grid | Key |
| :---: | :---: | :---: | :---: |
| 2 | 12 o'clock | 2 × 1 | `2` |
| 4 | 3 o'clock | 2 × 2 | `4` |
| 6 | 6 o'clock | 3 × 2 | `6` |
| 8 | 9 o'clock | 4 × 2 | `8` |

## Requirements

- macOS 14 (Sonoma) or newer
- A mouse with a middle button (a clickable scroll wheel)
- Swift 5.9+ toolchain (Xcode 15+ or the Command Line Tools) to build from source
- Accessibility permission, and possibly Input Monitoring

## Install

There is no packaged release yet, so build from source:

```sh
git clone <this repository>
cd orbitile
swift run -c release Orbitile
```

The first run asks for **Accessibility** access. Orbitile needs it to find the window under the cursor and to move it.

1. Open **System Settings → Privacy & Security → Accessibility**.
2. Enable the terminal you ran it from (Terminal, iTerm, VS Code…), or the built binary in `.build/release/Orbitile`.
3. Quit and run it again. macOS may also ask for **Input Monitoring**, used by the global event tap.

A small grid icon appears in the menu bar. Use it to quit.

## How to use

1. Hover the window you want to move.
2. **Click the middle button once and release.** You do not need to hold it. The fan opens centered on the cursor, and slides to stay on screen near the edges.
3. Hover a layout on the ring, or press `2`, `4`, `6` or `8`.
4. Point at a cell on the mini screen. The blue preview shows where the window will go.
5. **Click a cell** to apply instantly, or **press and drag across several cells** and release to merge them into one area.

### Controls

| Action | How |
| --- | --- |
| Open | Middle click on a window |
| Switch layout | Hover the ring, or press `2` `4` `6` `8` |
| Apply to one cell | Left click the cell, or middle click while hovering it |
| Merge cells | Press on a cell, drag over others, release |
| Cancel | `Esc`, click outside the disc, or middle click with no cell hovered |

Releasing a drag outside the cells only clears the selection and keeps the fan open. If there is no movable window under the cursor, the middle click passes through to the app untouched.

## Troubleshooting

- **Nothing happens on middle click.** Accessibility is not granted for the process that launched Orbitile. Grant it and relaunch.
- **The fan opens but the window does not move.** Some apps (non-standard windows, some full screen or Electron windows) do not expose a movable window through Accessibility.
- **The blur behind the disc looks flat.** Check that *Reduce transparency* is off in System Settings → Accessibility → Display.

## Project layout

| Path | What is in it |
| --- | --- |
| `Sources/OrbitileCore` | Pure geometry and hover state: families, hit testing, target frames, easing |
| `Sources/Orbitile` | The app: event tap, Accessibility capture and move, overlay panel, SwiftUI fan |
| `Sources/OrbitileChecks` | Assertions for the core. Run with `swift run OrbitileChecks` |
| `design/` | The design project exported from Claude Design (reference only) |
| `docs/images/` | Logo and images used by this README |

## Roadmap

What is left before a proper release (packaged `.app`, menu bar icon, launch at login, signed builds) is tracked in [spec.md](spec.md).
