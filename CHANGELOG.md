# Changelog

## 2026-02-15

### Added
- Initial release
- Quick entries from command line or interactive menu
- Hashtag support with `-tag` and `-tags`
- Machine signatures with `-machine` and `-machines`
- AES-256 encryption with `-lock` and `-unlock`
- Search with `-search` / `-s`
- Multi-machine sync support
- Portable design (USB, cloud sync, network shares)
- External editor support for composing entries (`-edit`, `-edit -plain`)
- Configurable editor preference via `-editor` flag and setup wizard
- Blank line separator between journal entries
- **Multiple notebooks** — organize entries into separate folders (e.g., work, personal, devlog)
  - `myjo -notebook <name>` to switch active notebook
  - `myjo -notebook <name> "<path>"` to create a new notebook
  - `myjo -notebooks` to list all notebooks with active marker
  - `N. Switch notebook` option in interactive menu
  - Active notebook name shown in menu header
- Auto-migration of old config format (bare path on line 1) to new `notebook:name=path` format
- Setup preserves existing notebooks when re-run
- **Chrome extension** — send text to any notebook from the browser
  - Right-click selected text → "Send to MyJo" → pick a notebook
  - Toolbar popup with notebook dropdown and "Send Clipboard" button
  - Remembers last-used notebook
  - Native messaging host with install script for one-time setup
