# Zsh Configuration

This repository contains Valerie's personal `.zshrc` file.  
It customizes the Z shell (zsh) environment with useful plugins, aliases, and tools to improve productivity on macOS and Linux.

---

## Features

### Core Setup
- **Coreutils first**: Replaces default macOS utilities with GNU Coreutils via Homebrew.
- **History**: Expands history to 10,000 entries and ensures history is always saved.
- **Extended globbing**: Enables advanced globbing patterns (`setopt extended_glob`).

### Plugins & Enhancements
- **zsh-completions**: Adds extended completions for many commands.
- **zsh-syntax-highlighting**: Highlights commands as you type.
- **zsh-autosuggestions**: Suggests commands from history.
- **zmv**: Autoloads the powerful `zmv` function for batch renaming.

### Oh My Zsh
- Uses [Oh My Zsh](https://ohmyz.sh/) as a plugin manager.
- Theme: `dracula-pro`.
- Plugins enabled:
  - `git`
  - `autoupdate`
  - `jsontools`

### Aliases
- **Python**: Defaults `python` → `python3`, `pip` → `pip3`.
- **Editor**: `vim` and `vi` point to Neovim with a custom config.
- **Mosh**: Runs mosh with firewall allowance.
- **Homebrew maintenance**: `brewski` updates, upgrades, cleans, and checks for issues.
- **Process kill**: `killadobe` terminates all Adobe processes.
- **YouTube downloads**: Aliases for `yt-dlp` with aria2c for fast parallel downloads.
- **sudo TouchID**: `touchsudo` enables macOS TouchID for `sudo`.
- **Directory listing**: Aliases `ls`, `l`, and `ll` to [lsd](https://github.com/lsd-rs/lsd).
- **Misc**:
  - `powershell` → `pwsh`
  - `rsync` → Homebrew-installed `rsync`

---

## Requirements

To use this `.zshrc` effectively, install the following:

- [zsh](https://www.zsh.org/)
- [Oh My Zsh](https://ohmyz.sh/)
- [Homebrew](https://brew.sh/)
- [coreutils](https://formulae.brew.sh/formula/coreutils)
- [zsh-syntax-highlighting](https://formulae.brew.sh/formula/zsh-syntax-highlighting)
- [zsh-autosuggestions](https://formulae.brew.sh/formula/zsh-autosuggestions)
- [lsd](https://github.com/lsd-rs/lsd)
- [neovim](https://neovim.io/)
- [mosh](https://mosh.org/)
- [yt-dlp](https://github.com/yt-dlp/yt-dlp)
- [aria2](https://aria2.github.io/)
- [powershell](https://formulae.brew.sh/cask/powershell)

---

## Installation

1. Clone this repository:
   ```bash
   git clone https://github.com/vwarner1411/zshell.git
   ```

2. Backup your existing `.zshrc`:
   ```bash
   mv ~/.zshrc ~/.zshrc.backup
   ```

3. Symlink this repo’s `.zshrc`:
   ```bash
   ln -s ~/path/to/repo/.zshrc ~/.zshrc
   ```

4. Reload your shell:
   ```bash
   source ~/.zshrc
   ```

---

## Notes
- Make sure you have the [Dracula Pro theme](https://draculatheme.com/pro) for Oh My Zsh, or adjust the theme in the `.zshrc`.
- Some aliases (like `mosh` and `touchsudo`) are tailored for Valerie’s environment and may need editing for yours.

---

## License
MIT – feel free to reuse and adapt.
