# Bootstrap Environment

Reusable bootstrap for macOS desktops and Debian-based workstations (Ubuntu today, Debian/Arch next). The repo delivers:

- A single `curl` entrypoint that installs prerequisites, syncs `chezmoi` dotfiles, and applies Ansible roles.
- Ansible playbooks/roles for idempotent package management without Homebrew on Linux.
- Tests to guard syntax, linting, and shell quality.

## Quick Start

Interactive shells (TTY) will prompt for sudo when needed.
On macOS, run bootstrap as your normal user (do not prepend `sudo`).

```bash
curl -fsSL https://raw.githubusercontent.com/vwarner1411/bootstrap/main/scripts/bootstrap.sh | bash
```

Environment variables:

- `PROFILE=server|desktop` (default `desktop`)
- `REPO_BRANCH` (defaults to `main`)
- `CHEZMOI_REPO` (defaults to `https://github.com/vwarner1411/dotfiles.git`)
- `ANSIBLE_EXTRA_VARS` (optional raw `--extra-vars` payload for advanced overrides)

The `server` profile skips desktop niceties (`powershell`, `kitty`, `starship`, `yt-dlp`) while still installing the core CLI stack.

Example one-liners:

```bash
# Desktop workstation
PROFILE=desktop CHEZMOI_REPO=https://github.com/vwarner1411/dotfiles.git \
  bash -c "$(curl -fsSL https://raw.githubusercontent.com/vwarner1411/bootstrap/main/scripts/bootstrap.sh)"

# Server baseline
PROFILE=server CHEZMOI_REPO=https://github.com/vwarner1411/dotfiles.git \
  bash -c "$(curl -fsSL https://raw.githubusercontent.com/vwarner1411/bootstrap/main/scripts/bootstrap.sh)"
```

Re-run the same command any time to upgrade packages and reapply dotfiles.

## Server Prep Script

When the server profile is bootstrapped, a helper script `~/server-prep.sh` is staged (with the playbook stored under `~/.local/share/bootstrap/server_prep/`). Run it manually to harden a VM before turning it into a template—it prompts for hostname and static networking, disables cloud-init, refreshes SSH host keys, applies the requested sysctl values, scrubs logs/history, and reboots when finished.

```bash
sudo ~/server-prep.sh
```

> Supported on Ubuntu Server 22.04/24.04. The playbook will ask for the new hostname, IP details, and confirmation before rebooting.

## What Gets Installed

| Area                | macOS (Homebrew)                              | Ubuntu/Debian (apt/manual)                                        |
|---------------------|-----------------------------------------------|-------------------------------------------------------------------|
| Core CLI            | git, curl, wget, rsync, jq, gpg, ncdu, tree, lynx, ripgrep | Same set using `apt`/manual install (ripgrep built from source), plus python3/pip, build-essential, sysstat |
| Shell tooling       | zsh, Oh My Zsh, autosuggestions, completions  | zsh via apt, plugins cloned from GitHub (oh-my-zsh, autosuggestions, autoupdate, completions, syntax-highlighting) |
| Prompt/UX           | starship, fastfetch, lsd, yazi, fzf, btop, kitty | Latest GitHub releases for starship, fastfetch, lsd, yazi, fzf, btop, kitty |
| Development         | neovim, ansible, Powershell, yt-dlp           | Latest GitHub releases for Ansible CLI, PowerShell, yt-dlp        |
| Dotfiles            | Managed via `chezmoi init --apply`            | Same dotfiles source                                              |

Linux nodes never rely on Homebrew; developer tooling comes straight from GitHub releases (apt is only used for core OS/build dependencies).

## Project Layout

```
├── ansible.cfg
├── inventory/hosts.yml
├── playbooks/bootstrap.yml
├── requirements.yml
├── roles/
│   ├── common_core/        # shared baseline
│   ├── linux_cli/          # GitHub releases + minimal apt build deps
│   ├── macos_cli/          # Homebrew formulas/casks
│   ├── shell_extras/       # oh-my-zsh and plugins
│   └── desktop_tools/      # desktop-only extras
├── scripts/bootstrap.sh    # curl-able entrypoint
└── tests/smoke.sh          # syntax/lint/shellcheck
```

## Running Manually

```bash
# assumes repo cloned to ~/src/bootstrap
cd ~/src/bootstrap
ansible-galaxy collection install -r requirements.yml --force
ansible-playbook playbooks/bootstrap.yml --extra-vars "profile=desktop" --ask-become-pass
```

Switch to server profile:

```bash
ansible-playbook playbooks/bootstrap.yml --extra-vars "profile=server" --ask-become-pass
```

## Tests

Use the smoke script to validate changes before committing:

```bash
./tests/smoke.sh
```

- `ansible-playbook --syntax-check`
- `ansible-lint` (if present)
- `shellcheck` for the bootstrap script

Add Molecule or CI workflows later without changing the bootstrap flow.

## Roadmap

- Debian + Arch inventory groups
- Additional Molecule scenarios
- Optional GUI packages gated by tags
- Cached release lookup for air-gapped installs

## License

MIT – reuse and adapt as needed. Pull requests welcome.
