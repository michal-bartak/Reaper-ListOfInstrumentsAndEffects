# Changelog

All notable changes to List of Instruments and Effects. Format:
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/); versions follow ReaPack, where a letter
suffix (`3.1.0beta1`) marks a pre-release.

> **Feeds releases:** the section matching the manifest `@version` is extracted by
> [`.github/workflows/release.yml`](.github/workflows/release.yml) into the GitHub release
> description. Keep `[Unreleased]` current; at release time rename it to `## [X.Y.Z] - YYYY-MM-DD`.
> The ReaPack changelog lives separately, in the `@changelog` block of
> [`ReaPack/MXM_List of Instruments and Effects.lua`](ReaPack/MXM_List%20of%20Instruments%20and%20Effects.lua).

## [3.0.0beta1] - 2026-10-15

### Added

- **Plugins on media items** — FX on the active take count as instruments or effects; FX on the other takes are listed as offline/inactive.
- **Input FX section** — record input FX on every track, not only the monitoring chain.
- **FX inside containers** — followed to any depth; the container itself is no longer listed, and bypassing or offlining one marks its contents inactive. Needs REAPER 7.06 or later.
- **About dialog** (ⓘ) — version, author, licence, and links to the documentation and source.
- **DAW section** — the report opens with the REAPER version it was made in.

### Changed

- **Window rebuilt on ReaImGui** — sharp on HiDPI displays, and resizable. **Requires ReaImGui 0.10 or later**.

### Fixed

- **Markdown tables line up** — with a long `Plugin Name` heading, and with accented names.
- **Report follows the active project tab**

## [2.1.0] - 2026-09-21

### Added

- **Toolbar icon**, at 1x, 150% and 200%.

### Changed

- **Install path** is now `Scripts/MXM Scripts/MXM_ListOfInstrumentsAndEffects/` instead of `Scripts/MXM Scripts/Various/`. ReaPack moves the file, but toolbar buttons, shortcuts and custom actions bound to the old path must be pointed at the new one.

## [2.0] - 2024-01-12

### Added

- **Window** with export to plain text, Markdown, BB plain and BB code, built on Lokasenna's GUI library v2. Needs SWS for the clipboard.

### Fixed

- **Sorting** of plugin names.

## [1.0] - 2023-11-11

First public release, through ReaPack. Lists plugins as Markdown tables, grouped into instruments, effects, monitoring and offline/inactive.

## [0.9] - 2023-11-11

Initial version.
