# Clackey

**Vimium-style keyboard navigation for any Windows application.**

Navigate buttons, links, tabs, menus, and dropdowns without touching your mouse. Press Alt+key shortcuts to scroll, click elements, and navigate — works anywhere, never conflicts with typing.

![AutoHotkey](https://img.shields.io/badge/AutoHotkey-v2.0%2B-green)
![License](https://img.shields.io/badge/license-MIT-blue)
![Platform](https://img.shields.io/badge/platform-Windows-lightgrey)

## How it works

### Shortcuts

| Shortcut | Action |
|----------|--------|
| `Alt+f` | Show hint labels — type letters to click any element |
| `Ctrl+j` / `Ctrl+k` | Scroll down / up (configurable: use Alt if no GlazeWM) |
| `Ctrl+g` / `Ctrl+Shift+g` | Half page down / up (Vim-style G/gg) |
| `F3` | UIA Inspector — shows element info under cursor |
| `ScrollLock` | Pause/resume Clackey |

### Hint mode

1. Press `Alt+f` to activate hints
2. Yellow labels appear on all interactive elements
3. Type the shown letters to click that element
4. Press `Escape` to cancel, `Backspace` to correct

## Technical approach

Clackey uses Microsoft's **UI Automation (UIA)** framework — the same accessibility API used by screen readers. It does **not** use screen scraping, OCR, or pixel reading.

| Property | Clackey |
|----------|---------|
| **What is read** | Only element positions and types |
| **Scan scope** | Only the active window |
| **Method** | Single `FindElements` call with filters |
| **Privacy** | No text/names read (privacy mode) |
| **Speed** | ~50–300ms |

### Privacy

In privacy mode (on by default), the scanner reads **only**:
- **Element type**: Button, Hyperlink, Edit, etc. (to know it's interactive)
- **Position**: x, y, width, height (to place the hint label)

No text, names, values, or other content is read or stored. Nothing is sent over the network.

**Exception**: Before clicking, the element name is momentarily read to check for destructive keywords (delete, remove, etc.). If detected, a confirmation dialog appears. The name is immediately discarded from memory — nothing is logged or stored.

## Installation

### Requirements

- [AutoHotkey v2.0+](https://www.autohotkey.com/)
- **UIA.ahk** — download from [Descolada/UIA-v2](https://github.com/Descolada/UIA-v2) and place in the `lib/` folder (not included in this repo)

### Steps

1. **Install AutoHotkey v2** from [autohotkey.com](https://www.autohotkey.com/)
2. **Download UIA.ahk** from the [UIA-v2 GitHub](https://github.com/Descolada/UIA-v2):
   - Click "Code" → "Download ZIP"
   - Extract the ZIP and find `UIA.ahk` in the `Lib` folder
   - Copy `UIA.ahk` into this project's `lib/` folder
3. **Run** `Clackey.ahk` (double-click)

### Folder structure

```
clackey/
├── Clackey.ahk            ← Main script (run this)
├── settings.ini           ← Configuration
├── lib/
│   └── UIA.ahk            ← UIA-v2 library (download separately)
└── src/
    ├── Scanner.ahk        ← UIA element scanner
    ├── Overlay.ahk        ← Hint overlay GUI
    └── HintEngine.ahk     ← Hint code generation
```

## Configuration

Edit `settings.ini` to customize:

### General

| Setting | Default | Description |
|---------|---------|-------------|
| `Modifier` | `Ctrl` | Modifier for scroll keys: `Ctrl` or `Alt`. Use Ctrl for GlazeWM compatibility |
| `TriggerKey` | `f` | Key for hint mode (used as Alt+key) |
| `InspectKey` | `F3` | Key for UIA Inspector |
| `HintChars` | `asdfghjkl` | Characters for hint labels |
| `PrivacyMode` | `1` (on) | Don't read element names |
| `MaxElements` | `200` | Max number of hints |
| `ScanTypes` | `Button,CheckBox,...` | Element types to scan |

### Navigation

| Setting | Default | Description |
|---------|---------|-------------|
| `ScrollDown` | `j` | Scroll down key |
| `ScrollUp` | `k` | Scroll up key |
| `HalfPageDown` | `g` | Half page down key (Ctrl+g) |
| `HalfPageUp` | `+g` | Half page up key (Ctrl+Shift+g, prefix `+` = Shift) |
| `ScrollLines` | `2` | Lines per scroll (1=smooth, 3+=faster) |
| `HalfPageLines` | `8` | Lines per half page |
| `SmoothScroll` | `1` | 1=multiple small ticks (smoother), 0=single batch |

### Appearance

| Setting | Default | Description |
|---------|---------|-------------|
| `BgColor` | `FFCC00` | Hint background color (hex) |
| `TextColor` | `000000` | Hint text color (hex) |
| `FontSize` | `11` | Font size |
| `FontName` | `Consolas` | Font family |
| `HintOpacity` | `220` | Label opacity (0–255) |

### Hotkey syntax

| Symbol | Key |
|--------|-----|
| `!` | Alt |
| `^` | Ctrl |
| `+` | Shift |
| `#` | Windows |

## Features

- **Hint mode** (`Alt+f`): Click any interactive element by typing its hint code
- **Scrolling** (`Ctrl+j/k`): Vim-style scrolling (Ctrl default for GlazeWM compatibility)
- **Half page** (`Ctrl+g` / `Ctrl+Shift+g`): Vim-style G/gg page navigation
- **Destructive action safety**: Confirms before clicking elements named "Delete", "Remove", etc.
- **Auto re-scan**: After opening a dropdown, hints automatically refresh
- **Smart click strategy**: Uses the optimal UIA pattern per element type
- **UIA Inspector** (`F3`): See UIA properties of any element
- **Pause** (`ScrollLock`): Emergency stop — disables all hotkeys
- **Zero conflicts**: Alt+key shortcuts never interfere with normal typing

## How it works under the hood

1. **Scan**: `ElementScanner` queries the active window via UIA with a single batched `FindElements` call
2. **Filter**: Elements are filtered by size, visibility, and window bounds using cached positions
3. **Generate**: `HintEngine` assigns base-N letter codes using home-row keys
4. **Display**: `HintOverlay` creates a transparent click-through window with colored labels
5. **Input**: An `InputHook` captures keystrokes, progressively filtering hints in real-time
6. **Execute**: The matched element is clicked using the best available UIA pattern

## Security & reliability

### Is Clackey safe for sensitive work?

- **Local only**: No network calls, no telemetry, no data sent anywhere
- **Privacy mode** (default): The scanner reads only element positions and types — no text, names, or values
- **Destructive action guard**: Before clicking, element names are momentarily checked for dangerous keywords (delete, remove, erase, etc.). If detected, a Yes/No confirmation appears (default: No). The name is immediately discarded from memory — nothing is ever logged or stored.
- **Open source**: You can audit the code

### Misclick risk

You must type the exact hint code (e.g. `as`, `df`) to click. The chance of misclicking depends on:

- **Typing accuracy**: Wrong character → wrong element. Use `Backspace` to correct, `Escape` to cancel
- **Filtering**: After the first character, only matching hints stay visible — reduces ambiguity
- **Critical actions**: For delete/confirm buttons, use the right-click prefix (`.`) or double-click (`,`) to be more deliberate

**Tip**: For high-risk actions, pause Clackey with `ScrollLock` and use the mouse.

## Known limitations

- **First scan of Chromium-based apps**: May take ~500ms due to accessibility initialization. Subsequent scans are fast.
- **UWP/Modern UI apps**: Some apps have limited UIA support.
- **Admin windows**: If the target window runs as administrator, Clackey must also run as administrator.
- **Fullscreen games**: Overlay may not render correctly in fullscreen DirectX/Vulkan applications.

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/my-feature`)
3. Commit your changes (`git commit -m 'Add my feature'`)
4. Push to the branch (`git push origin feature/my-feature`)
5. Open a Pull Request

## License

This project is licensed under the MIT License — see the [LICENSE](LICENSE) file for details.

## Acknowledgments

- [Descolada](https://github.com/Descolada) for the excellent [UIA-v2](https://github.com/Descolada/UIA-v2) library (MIT License)
- Inspired by [Vimium](https://vimium.github.io/) for browser navigation
