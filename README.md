# MyJo - My Journal

A portable PowerShell command-line journal with hashtags, machine signatures, multi-device sync, and AES-256 encryption.

## Features

- **Quick entries** from the command line, interactive menu, or system-wide popup (Ctrl+Alt+A)
- **Hashtag support** - tag entries with `#work`, `#ideas`, etc.
- **Machine signatures** - every entry is stamped with the computer name
- **Multi-machine filtering** - see entries from a specific device
- **AES-256 encryption** - lock your journal with a password
- **Multiple notebooks** - organize entries into separate notebooks (work, personal, etc.)
- **Portable** - runs from USB drives, cloud sync folders, network shares
- **No dependencies** - pure PowerShell, works on Windows 5.1+ and PowerShell 7+

## Quick Start

1. **Run the installer:**
   ```powershell
   .\Install.ps1
   ```

2. **Restart PowerShell** (or run `. $PROFILE`)

3. **Start journaling:**
   ```powershell
   myjo "My first entry #hello"
   ```

Alternatively, import as a module:
```powershell
Import-Module .\MyJo.psd1
myjo "Hello from MyJo"
```

## Commands

### Quick Add
```powershell
myjo "Had a great meeting with the team #work #meeting"
myjo "Remember to buy groceries"
```

### Search
```powershell
myjo -search "meeting"       # Search all entries for "meeting"
myjo -s "project"            # Short alias for search
```

### Tags
```powershell
myjo -tag "work"             # Show all entries tagged #work
myjo -tags                   # List all tags with entry counts
```

### Machine Filtering
```powershell
myjo -machine LUNA           # Show entries from machine LUNA
myjo -machines               # List all machines with entry counts
```

### Editor Entry
```powershell
myjo -edit                   # Open external editor to compose an entry
myjo -edit -plain            # Open editor, strip markdown formatting before saving
```

By default, MyJo opens `notepad.exe`. Set your preferred editor with:
```powershell
myjo -editor "emacs"           # Set editor to emacs
myjo -editor "code --wait"     # Set editor to VS Code (--wait is required)
myjo -editor "notepad++"       # Set editor to Notepad++
```

The editor preference is saved in your config (`~/.myjo/config.txt`). You can also set it during `myjo -setup`, or override it per-session with the `$EDITOR` environment variable.

### Notebooks

Organize entries into separate notebooks (e.g., work, personal, projects). Each notebook is a different folder.

```powershell
myjo -notebooks                           # List all notebooks
myjo -notebook work                       # Switch to notebook "work"
myjo -notebook work "G:\Work Journal"     # Create a new notebook with path
myjo -notebook default                    # Switch back to default
```

Notebooks are stored in your config (`~/.myjo/config.txt`). Old configs (bare path on line 1) are auto-migrated to the new format on first use.

### Encryption
```powershell
myjo -lock                   # Encrypt all journal files (prompts for password)
myjo -unlock                 # Decrypt all journal files (prompts for password)
```

When the journal is locked:
- All read/write operations prompt for the password once per session
- Files stay encrypted on disk at all times
- A `.myjo-locked` marker file indicates the encryption state

### Setup
```powershell
myjo -setup                  # Re-run the first-time setup wizard
```

### Interactive Menu

Just run `myjo` with no arguments to open the interactive menu:

```
===== JOURNAL [MYPC] (work) =====
  1. New entry
  2. View today
  3. View recent (last 7 days)
  4. View by date
  5. Search entries
  6. Filter by tag
  7. List all tags
  8. Edit entry (today)
  9. Delete entry (today)
  E. New entry (editor)
  M. Filter by machine
  L. List all machines
  K. Lock journal
  N. Switch notebook
  Q. Exit
```

## Multi-Machine Setup

MyJo is designed to work across multiple computers:

1. **Store journal files on a shared location** (OneDrive, Dropbox, network drive, USB):
   ```
   myjo -setup
   # Enter: C:\Users\you\OneDrive\Journal
   ```

2. **Install MyJo on each machine** - run `Install.ps1` on each computer

3. **Point all machines to the same journal folder** during setup

4. Each entry is automatically tagged with the machine name (e.g., `@DESKTOP-HOME`, `@LAPTOP-WORK`)

5. **Filter by machine** to see what you wrote where:
   ```powershell
   myjo -machine LAPTOP-WORK
   myjo -machines   # See all machines and entry counts
   ```

## Encryption Details

- Uses **AES-256-CBC** via .NET `System.Security.Cryptography.Aes`
- Key derivation: **PBKDF2** with 100,000 iterations (SHA-256) via `Rfc2898DeriveBytes`
- Each file gets a unique random 16-byte salt
- Password is never stored - you must remember it
- The config file (`~/.myjo/config.txt`) stores notebook paths, active notebook, and encryption preference

## Chrome Extension

Send text to any notebook directly from your browser — right-click selected text or use the toolbar popup to send clipboard contents.

### Setup

1. Run the install script to register the native messaging host:
   ```powershell
   cd <your-myjo-folder>\extension\host
   .\install-host.ps1
   ```

2. In Chrome, go to `chrome://extensions`, enable **Developer mode**, click **Load unpacked**, and select the `extension\chrome` folder.

3. Copy the extension ID from Chrome and re-run:
   ```powershell
   .\install-host.ps1 -ExtensionId "<your-extension-id>"
   ```

4. Reload the extension (click the refresh icon on the extension card).

### Usage

- **Right-click** selected text on any page → **Send to MyJo** → pick a notebook
- **Toolbar icon** → select a notebook → **Send Clipboard**

## Quick Add Popup

A system-wide popup lets you add journal entries from any context on the machine — browser, editor, spreadsheet, or anywhere else — without opening a terminal.

### Setup

Run the install script once to create the Desktop shortcut:
```powershell
cd <your-myjo-folder>
.\Install-QuickAdd.ps1
```

This creates a **MyJo Quick Add** shortcut on your Desktop with the **Ctrl+Alt+A** hotkey. The shortcut must remain on the Desktop for the hotkey to work.

### Usage

Press **Ctrl+Alt+A** from anywhere:
- Select a notebook from the dropdown (pre-selected to your active notebook)
- Type your entry in the text box
- **Ctrl+Enter** to submit, **Escape** to cancel

## Setting Up the Alias Manually

If you prefer not to use the installer, add this to your PowerShell profile (`$PROFILE`):

```powershell
function myjo { & 'C:\path\to\Journal.ps1' @args }
```

## File Structure

```
~/.myjo/
  config.txt              # Notebook paths, active notebook, settings

<journal-folder>/         # Each notebook is a separate folder
  Journal_2026-02-15.txt  # One file per day
  .myjo-locked            # Present when journal is encrypted

QuickAdd.ps1              # System-wide quick-add popup (Ctrl+Alt+A)
Install-QuickAdd.ps1      # Creates the Desktop shortcut for QuickAdd

extension/
  chrome/                 # Chrome extension (load unpacked from here)
    manifest.json
    popup.html
    popup.js
    background.js
    icons/icon48.png
  host/                   # Native messaging host
    myjo-host.ps1
    myjo-host.bat
    com.myjo.host.json    # Generated by install-host.ps1 (machine-specific)
    install-host.ps1
```

Config file format:
```
notebook:default=G:\My Drive\Journal
notebook:work=G:\My Drive\Work Journal
active=default
encryption=disabled
editor=notepad.exe
```

## License

MIT - see [LICENSE](LICENSE) for details.
