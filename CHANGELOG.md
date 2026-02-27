# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/), and this project adheres to [Semantic Versioning](https://semver.org/).

## [Unreleased]

### Changed
- **Docs**: Screenshots per language — each README shows Classic/Modern in its own language (5 languages × 2 layouts = 10 screenshots)

### Fixed
- **Code**: Fix `as? AXUIElement` conditional downcast warning in `showTabBar()` (CoreFoundation type always succeeds)

## [1.0.0] - 2026-02-27

Initial release of File Tab Opener (macOS Native).
Native SwiftUI reimplementation of [file_tab_opener](https://github.com/obott9/file_tab_opener) (Python/Tk v1.1.3).

### Added
- **Core**: AX API + AppleScript hybrid Finder tab control (opens 10 tabs in ~3 seconds)
- **Core**: AXUIElement cache and lightweight child-count polling for performance
- **Core**: Pre-compiled NSAppleScript with handler calls (eliminates repeated compilation)
- **Core**: Automatic fallback to separate Finder windows on tab creation failure
- **UI**: Classic layout (Python version compatible) with button-based tab group management
- **UI**: Modern layout with sidebar + detail panel (HSplitView)
- **UI**: Classic/Modern layout toggle switch in settings bar
- **UI**: FlowLayout for tab button wrapping (max 3 visible rows with scroll)
- **UI**: Dark mode support (follows macOS system appearance)
- **UI**: Toast-style progress indicator during tab opening
- **Tab Groups**: Create, rename, copy, delete, and reorder tab groups
- **Tab Groups**: Window geometry (position/size) save and restore per tab group
- **Paths**: Add, remove, reorder paths within a tab group
- **Paths**: Path validation (existence check, duplicate prevention)
- **Paths**: Drag & drop folder support on path entry field
- **Paths**: Strip surrounding quotes from pasted paths
- **History**: Recently opened folders with pin support
- **i18n**: 5 languages (English, Japanese, Korean, Traditional Chinese, Simplified Chinese)
- **Config**: JSON configuration compatible with Python version (snake_case keys, no `id` field)
- **Config**: Robust decoding with `decodeIfPresent` for all fields (handles missing/null values)
- **Config**: Config version field for future migration support
- **Logging**: File logger at `~/Library/Logs/FileTabOpenerM/app.log`
- **Logging**: Log rotation (1 MB threshold, 3 backup generations)
- **Accessibility**: Permission check dialog with system settings link on first launch
- **Docs**: README in 5 languages, MIT License
- **Tests**: 25 unit tests (Codable round-trip, Localization, String format helpers)

[Unreleased]: https://github.com/obott9/FileTabOpenerM/compare/v1.0.0...HEAD
[1.0.0]: https://github.com/obott9/FileTabOpenerM/releases/tag/v1.0.0
