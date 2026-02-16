# Changelog

## 2026-02-15

### Added
- **Multiple notebooks** — organize entries into separate folders (e.g., work, personal, devlog)
  - `myjo -notebook <name>` to switch active notebook
  - `myjo -notebook <name> "<path>"` to create a new notebook
  - `myjo -notebooks` to list all notebooks with active marker
  - `N. Switch notebook` option in interactive menu
  - Active notebook name shown in menu header
- **Auto-migration** — old config format (bare path on line 1) automatically migrates to new `notebook:name=path` format
- **Setup preserves notebooks** — re-running `myjo -setup` now detects existing notebooks and asks whether to keep them

### Changed
- Config format updated from bare path to `notebook:name=path` entries with `active=` key
- Editor config writer updated to use structured config format

## 2026-02-14

### Added
- Configurable editor preference via `-editor` flag and setup wizard
- Blank line separator between journal entries
- External editor support for composing entries (`-edit`, `-edit -plain`)

## 2026-02-13

### Added
- Initial release
- Quick entries from command line or interactive menu
- Hashtag support with `-tag` and `-tags`
- Machine signatures with `-machine` and `-machines`
- AES-256 encryption with `-lock` and `-unlock`
- Search with `-search` / `-s`
- Multi-machine sync support
- Portable design (USB, cloud sync, network shares)
