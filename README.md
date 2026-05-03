# Bookshelf

A skeumorphic home screen for KOReader. Replaces the file manager on launch
with a focused hero card for the currently-reading book and four chip-driven
shelves — Recent, Latest, Series, and Favourites.

<!-- screenshot: TODO -->

---

## Quick start

1. Download the latest release ZIP from [GitHub Releases](https://github.com/AndyHazz/bookshelf.koplugin/releases) and extract `bookshelf.koplugin/` to your KOReader plugins directory ([paths below](#installation)).
2. Restart KOReader — Bookshelf opens automatically as the home screen.
3. Tap **Recent**, **Latest**, **Series**, or **★** to browse your library by shelf.
4. Tap the gear icon (top right) for settings, including hero card customisation and library folder.

---

## Home screen layout

```
┌──────────────────────────────────────┐
│ BOOKSHELF        14:32  73%  ≡       │  ← TitleBar (time, battery, gear)
├──────────────────────────────────────┤
│ [cover]  Title                       │  ← Hero card (currently-reading)
│          Author                      │
│          42 / 218 · 32%              │
│          3h 45m LEFT                 │
│          ════════════░░░░░░░░        │  ← Progress bar
├──────────────────────────────────────┤
│  Recent   Latest   Series   ★        │  ← Chip strip
├──────────────────────────────────────┤
│ Recently read  ·  1–8 of 12  ›       │  ← Shelf label (tappable → full list)
│ [spine] [spine] [spine] [spine]      │  ← Shelf row 1
│ [spine] [spine] [spine] [spine]      │  ← Shelf row 2
└──────────────────────────────────────┘
```

Tap any spine to open that book. Long-press a spine for options (add/remove favourite, show book info, remove from history). Tap the shelf label to open the full paginated library view for the active chip. On the **Series** chip, tap a series stack to expand it in place; tap the back label to collapse.

---

## Customisation

### Hero card lines

The hero card detail strip is driven by token format strings — the same syntax as [Bookends](https://github.com/AndyHazz/bookends.koplugin). Change lines via **gear → Settings → Edit hero card lines**.

Default lines:

```
Page %page_num / %page_count · %book_pct
[if:book_time_left]%book_time_left LEFT[else]Open to start reading[/if]
```

### Token cheatsheet

Tokens are placeholders prefixed with `%`. The full list is in the [design spec](docs/superpowers/specs/2026-05-03-bookshelf-design.md). The most useful ones:

#### Metadata

| Token | Example |
|-------|---------|
| `%title` | *The Great Gatsby* |
| `%author` | *F. Scott Fitzgerald* |
| `%authors` | *Neil Gaiman, Terry Pratchett* |
| `%series` | *Dune #1* |
| `%series_name` | *Dune* |
| `%series_num` | *1* |
| `%filename` | *The_Great_Gatsby* |
| `%format` | *EPUB* |
| `%lang` | *en* |

#### Position / progress

| Token | Example |
|-------|---------|
| `%page_num` | *42* |
| `%page_count` | *218* |
| `%book_pct` | *19%* |
| `%book_pct_left` | *81%* |
| `%pages_left` | *176* |

#### Statistics (requires statistics plugin)

| Token | Example |
|-------|---------|
| `%book_time_left` | *3h 45m* |
| `%book_read_time` | *2h 30m* |
| `%days_reading_book` | *7* |
| `%pages_per_day` | *12* |
| `%speed` | *42* |

Stat tokens auto-hide when the statistics plugin is absent or the book has no recorded reading time. No configuration needed.

#### Device

| Token | Example |
|-------|---------|
| `%batt` | *73%* |
| `%batt_icon` | Changes with charge level |
| `%wifi` | Hidden when off |
| `%time` | *14:35* |
| `%time_12h` | *2:35 PM* |
| `%date` | *3 May* |
| `%light` | *18* |
| `%mem` | *33%* |
| `%disk` | *2.4 GB* |

### Conditionals

Use `[if:condition]...[else]...[/if]` to show content based on state:

```
[if:book_time_left]%book_time_left LEFT[else]Open to start reading[/if]
[if:batt<20]LOW BATTERY %batt[/if]
[if:charging=yes]Charging[else]%batt[/if]
[if:not series]Standalone[/if]
```

Supported operators: `=` `!=` `<` `>` `<=` `>=`. Boolean: `and`, `or`, `not`.

### Inline format tags

`[b]...[/b]`, `[i]...[/i]`, `[u]...[/u]` are accepted in format strings. In v0.1 these tags are stripped before display — bold/italic/underline rendering is planned for a future release.

### Token width caps

Append `{N}` to any token to cap its rendered width at N pixels:

```
%title{200} — %book_pct
```

---

## Installation

**Manual install:** Download the latest release ZIP from [GitHub Releases](https://github.com/AndyHazz/bookshelf.koplugin/releases) and extract to your KOReader plugins directory:

| Device | Path |
|--------|------|
| Kindle | `/mnt/us/koreader/plugins/bookshelf.koplugin/` |
| Kobo | `/mnt/onboard/.adds/koreader/plugins/bookshelf.koplugin/` |
| Android | `<koreader-dir>/plugins/bookshelf.koplugin/` |

Restart KOReader after installing.

---

## Configuration

Settings are stored in KOReader's main settings file alongside all other plugin state:

| Platform | Path |
|----------|------|
| Linux / dev | `~/.config/koreader/settings.reader.lua` |
| Kindle | `/mnt/us/koreader/settings.reader.lua` |
| Kobo | `/mnt/onboard/.adds/koreader/settings.reader.lua` |
| Android | `<koreader-dir>/settings.reader.lua` |

Bookshelf-specific keys are prefixed `bookshelf_` (e.g. `bookshelf_hero_lines`, `bookshelf_active_chip`, `bookshelf_latest_walk_depth`).

---

## Known limitations

- **"Latest" walk performance** — the Latest chip walks the filesystem at every label refresh. On slow devices or large libraries this can cause a brief pause. Caching is planned for v0.2.
- **In-app updater** — there is no built-in update checker in v0.1. Install new releases manually from GitHub Releases. An updater is planned for v1.0.
- **Inline format tags strip-only** — `[b]`, `[i]`, and `[u]` tags in hero card format strings are stripped before display in v0.1. No bold/italic/underline rendering yet; that is planned for a future release.
- **No preset library** — Bookshelf ships with one set of default hero card lines. A preset gallery (as in Bookends) is planned for v2.

---

## Design spec

Full design rationale, widget hierarchy, token vocabulary, and empty-state table:
[`docs/superpowers/specs/2026-05-03-bookshelf-design.md`](docs/superpowers/specs/2026-05-03-bookshelf-design.md)

---

## License

AGPL-3.0 — see [LICENSE](LICENSE)
