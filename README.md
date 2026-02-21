# Bootstrap Environment

Reusable bootstrap for macOS desktops and Debian-based Linux workstations (Ubuntu and Debian) with a consistent terminal-first setup.

The repo provides:

- A single `curl` entrypoint that installs prerequisites, ensures `chezmoi`, runs Ansible roles, and applies dotfiles.
- Idempotent package management: Homebrew on macOS, `apt` + upstream release installs on Linux.
- A profile-aware flow (`desktop` or `server`) so workstation and server hosts can share one bootstrap path.

## Quick Start

Run from an interactive shell. On macOS, run as your normal user (do not prepend `sudo`).

```bash
curl -fsSL https://raw.githubusercontent.com/vwarner1411/bootstrap/main/scripts/bootstrap.sh | bash
```

### Supported environment variables

- `PROFILE=desktop|server` (default `desktop`)
- `REPO_URL` (defaults to `https://github.com/vwarner1411/bootstrap.git`)
- `REPO_BRANCH` (default `main`)
- `CHEZMOI_REPO` (default `https://github.com/vwarner1411/dotfiles.git`)
- `WORKDIR` (default `$HOME/.local/share/bootstrap`)
- `ANSIBLE_EXTRA_VARS` (optional raw `--extra-vars` payload)

Example:

```bash
PROFILE=desktop CHEZMOI_REPO=https://github.com/vwarner1411/dotfiles.git \
  bash -c "$(curl -fsSL https://raw.githubusercontent.com/vwarner1411/bootstrap/main/scripts/bootstrap.sh)"
```

Re-running bootstrap is expected and safe; it upgrades/reconciles tools and reapplies dotfiles.

## Profiles

- `desktop`:
  - Full terminal UX stack and desktop-oriented CLI tooling.
- `server`:
  - Skips `powershell`, `ghostty`, `starship`, and `yt-dlp`.
  - Installs `open-vm-tools` on Debian-family hosts.
  - Stages `~/server-prep.sh` for post-provision hardening.

## What Gets Installed

### macOS (Homebrew formulas)

`yt-dlp`, `aria2`, `ffmpeg`, `node`, `chezmoi`, `zsh-autocomplete`, `zsh-syntax-highlighting`, `zsh-autosuggestions`, `coreutils`, `curl`, `git`, `jq`, `gnupg`, `mosh`, `lynx`, `ncdu`, `rsync`, `tree`, `wget`, `btop`, `starship`, `lsd`, `yazi`, `fzf`, `ripgrep`, `tealdeer`, `fastfetch`, `neovim`, `ansible`, `powershell`, `bat`, `fd`, `tmux`, `zoxide`, `mise`.

### macOS (Homebrew casks)

`ghostty`, `font-hack-nerd-font`.

### Debian/Ubuntu core packages (`apt`)

`apt-transport-https`, `aria2`, `build-essential`, `ca-certificates`, `curl`, `git`, `gnupg`, `lynx`, `mosh`, `ncdu`, `neovim`, `nfs-common`, `plocate`, `python3`, `python3-pip`, `python3-venv`, `rsync`, `software-properties-common`, `ssh`, `tree`, `wget`, `zsh`, `ddate`, `sysstat`, `iotop`, `iftop`, `unzip`, `fontconfig`, `fonts-hack`, `pipx`, `bat`, `fd-find`, `tmux`, `zoxide`.

Plus Linux task prerequisites: `ncurses-term`, `xz-utils`, `bzip2`, `tar`.

### Debian/Ubuntu tools installed from upstream releases

- `powershell`
- `btop`
- `lsd`
- `fzf`
- `fastfetch`
- `starship`
- `yazi`
- `yt-dlp`
- `tealdeer`
- `ripgrep`
- `mise`
- Hack Nerd Font Mono (latest Nerd Fonts release)

Additional Linux behavior:

- Attempts `apt install ghostty` when available in host repos.
- Ensures `bat` and `fd` compatibility symlinks (`batcat -> bat`, `fdfind -> fd`).
- Creates a Linux `tldr` compatibility command by linking `tldr` to `tealdeer`.

## Package Replacements and Defaults

The bootstrap now standardizes on the following terminal tooling choices:

- `lsd` is the supported `ls` replacement (not `eza`).
- `tealdeer` is the supported TLDR client (not `tldr` package).
- `ghostty` is the default terminal target.
- Hack Nerd Font is the default font baseline.

## Shell and Prompt Setup

- Installs Oh My Zsh.
- Installs Zsh plugins:
  - `autoupdate`
  - `zsh-autosuggestions`
  - `zsh-completions`
  - `zsh-syntax-highlighting`
- Installs Starship Zsh completions when desktop profile and Starship are present.

## Dotfiles Apply Flow

After Ansible completes, bootstrap:

- Initializes or updates `chezmoi` state from `CHEZMOI_REPO`.
- Applies dotfiles with force semantics.
- Warms command help cache:
  - `tealdeer --update` when available.
  - Falls back to `tldr --update` if tealdeer is not present.

## Server Prep Script

When `PROFILE=server`, bootstrap stages:

- `~/.local/share/bootstrap/server_prep/server_prep.yml`
- `~/.local/share/bootstrap/server_prep/templates/server-prep-netplan.yaml.j2`
- `~/.local/share/bootstrap/server_prep/server-prep.sh`
- Symlink: `~/server-prep.sh`

Run it after bootstrap to harden a server template:

```bash
sudo ~/server-prep.sh
```

It prompts for hostname and static network details, then performs cleanup/hardening and reboots.

## Project Layout

```text
├── ansible.cfg
├── inventory/hosts.yml
├── playbooks/
│   ├── bootstrap.yml
│   ├── server_prep.yml
│   └── templates/server-prep-netplan.yaml.j2
├── requirements.yml
├── roles/
│   ├── common_core/
│   ├── linux_cli/
│   ├── macos_cli/
│   ├── shell_extras/
│   └── desktop_tools/
├── scripts/
│   ├── bootstrap.sh
│   └── server-prep.sh
└── tests/
    └── smoke.sh
```

## Run Manually

```bash
cd ~/src/bootstrap
ansible-galaxy collection install -r requirements.yml --force
ansible-playbook playbooks/bootstrap.yml --extra-vars "profile=desktop" --ask-become-pass
```

Server profile:

```bash
ansible-playbook playbooks/bootstrap.yml --extra-vars "profile=server" --ask-become-pass
```

## Tests

Run smoke checks before committing:

```bash
./tests/smoke.sh
```

Current smoke checks include:

- `ansible-playbook --syntax-check`
- `ansible-lint` (when installed)
- `shellcheck` on bootstrap script

## Roadmap

- Arch inventory/group support
- Expanded e2e coverage
- Optional GUI bundles via tags

## License

MIT
