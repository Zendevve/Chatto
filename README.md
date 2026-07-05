# Chatto

[![Version](https://img.shields.io/badge/version-1.0.0-blue.svg)](https://github.com/Zendevve/Chatto/releases)
[![WoW](https://img.shields.io/badge/world%20of%20warcraft-3.3.5a-orange.svg)](https://wowpedia.blizzard.com/wotlk)
[![License](https://img.shields.io/badge/license-Proprietary-red.svg)](LICENSE)

**Chatto** is a premium, high-performance, and modular chat enhancement addon for **World of Warcraft 3.3.5a** (Wrath of the Lich King). Developed by **Zendevve**, it combines clean layout styling, prioritized message filters, and advanced quality-of-life utilities into a single unified interface that obsoletes clunky competitor setups.

---

## Table of Contents

- [Features](#features)
- [Installation](#installation)
- [Configuration](#configuration)
- [Slash Commands](#slash-commands)
- [Filter Pipeline](#filter-pipeline)
- [Compatibility](#compatibility)
- [License](#license)

---

## Features

### Presentation Layouts

| Layout | Description |
|------|-------------|
| **Glass Layout** | A modern, transparent chat UI replacement. Messages slide up smoothly with customizable easing, tabs fade in/out on hover, and unread indicator overlays keep you aware of missed activity. |
| **Classic Layout** | Enhances Blizzard's default chat frames by removing clunky side buttons, applying flat translucent edit box backdrops, enabling mousewheel scrolling (with Shift acceleration), and setting custom scroll limits. |

* **Draggable Movers** -- When unlocked, drag anywhere on the chat frame to move, or drag corners to resize. Custom dimensions and positions persist per-window.
* **Whisper Windows** -- Automated routing hooks dynamically capture temporary whisper conversations and place them in the custom layout container.
* **Render Loop Optimization** -- Active Glass frames utilize an optimized render loop that only ticks when animations are executing or fading, resulting in zero CPU overhead during normal gameplay.

### Message Filters (Data Cleansing)

| Filter | Description |
|--------|-------------|
| **Money Iconizer** | Replaces text money gains with compact coin icons (`Assets/coins.tga`) and aggregates multi-gains into single lines. |
| **Loot Simplifier** | Converts loot alerts, vendor sales, roll results, mail retrievals, and item destructions into clean transaction logs. |
| **XP & Rep Aggregators** | Combines multiple experience gains, zone discoveries, level up attributes, and faction reputation changes occurring in the same frame into single-line messages. |
| **Quest Summarizer** | Simplifies quest accept/complete logs and groups turn-in rewards (items, money, XP) into a combined message. |
| **Status Cleaners** | Compresses spell learning, specialization swaps, AFK/DND statuses, and custom private server metrics (e.g. Glory and Arena Point caps). |
| **Smart Blacklist** | Silently filters user-defined terms, simplifies death/durability logs, and swallows benign client assert errors (`ChatFrame.lua:3481`). |

### Quality of Life Utilities

* **Alt Character Mapping** -- Scans guild notes and officer notes to automatically append main character names next to alts in chat (`[AltName(MainName)]`).
* **Alt-Click Invites** -- Alt-clicking any character name link in either layout instantly sends a group invite.
* **Keyword Highlights** -- Scans messages for user-specified words and highlights them with custom colors, optionally playing a warning sound.
* **Sticky Channels** -- Toggles input stickiness for Say, Emote, Guild, Officer, Whisper, and Custom channels.
* **Target Whispering** -- Converts `/tt <message>` in the input edit box directly into `/w TargetName <message>` as you type.
* **Custom Timestamps** -- Prepends messages with colored, formatted timestamps (`[HH:MM:SS]`).
* **Url Copy Dialogs** -- Detects protocols (`http://`, `https://`) and domains (`www.`), highlights them in chat, and opens a copy-paste dialog (`Ctrl-C`) when clicked.

---

## Installation

### Steps

1. Clone the repository or download the latest release:

   ```bash
   git clone https://github.com/Zendevve/Chatto.git
   ```

2. Copy the `Chatto` subdirectory into your World of Warcraft AddOns folder:

   ```
   World of Warcraft/
   └── Interface/
       └── AddOns/
           └── Chatto/                  <-- this directory
               ├── Chatto.toc
               ├── Embeds.xml
               ├── Core/
               ├── Filters/
               ├── Layouts/
               └── Utilities/
   ```

3. Restart the game client or run `/reload` in-game. Ensure **Chatto** is checked in the **AddOns** list on your character selection screen.

---

## Configuration

Open the options GUI by typing `/chatto` or `/ct` in-game. The panel is registered via AceConfig-3.0 and supports granular adjustments for:

* Active Layout Mode (Classic or Glass)
* Layout-specific Fonts, Font Sizes, and Font Flags
* Message transition durations, slide speeds, and mouseover fading delays
* Global and per-channel filter toggles
* Keyword highlights, blacklist phrases, and timestamp formats

---

## Slash Commands

| Command | Aliases | Description |
|---------|---------|-------------|
| `/chatto` | `/ct` | Open the Chatto configuration options panel |
| `/tt` | | Whisper your current target |

---

## Filter Pipeline

Chatto filters are executed sequentially via a prioritized pipeline. Developers can hook into this pipeline via the public API:

```lua
-- Register a custom filter
Chatto:RegisterFilter("MyFilter", function(core, chatFrame, text, r, g, b, chatID, ...)
    -- Return nil to block, or modified values
    return text, r, g, b
end, priority)
```

---

## Compatibility

* **WoW Client**: World of Warcraft 3.3.5a (Interface version `30300`).
* **Libraries**: Includes embedded Ace3, LibSharedMedia-3.0, LibEasing-1.0, and LibMoreEvents-1.0. No external dependencies are required.

---

## License

This project is published under a proprietary **Copyright Notice and Limited Personal Use** license. See the [LICENSE](LICENSE) file for the full terms.
