#!/usr/bin/env bash
set -euo pipefail

REPO_URL="${REPO_URL:-https://github.com/vwarner1411/zshell.git}"
REPO_BRANCH="${REPO_BRANCH:-bootstrap}"
CHEZMOI_REPO="${CHEZMOI_REPO:-https://github.com/vwarner1411/dotfiles.git}"
WORKDIR="${WORKDIR:-$HOME/.local/share/zshell}"
PROFILE="${PROFILE:-desktop}"

# ensure local bin is first so freshly installed tools are visible
export PATH="$HOME/.local/bin:$PATH"

log() {
  printf "\033[1;32m[bootstrap]\033[0m %s\n" "$*" >&2
}

err() {
  printf "\033[1;31m[bootstrap]\033[0m %s\n" "$*" >&2
}

command_exists() {
  command -v "$1" >/dev/null 2>&1
}

ensure_directory() {
  mkdir -p "$1"
}

detect_os() {
  case "$(uname -s)" in
    Darwin) echo "macos" ;;
    Linux)
      if [ -f /etc/os-release ]; then
        # shellcheck disable=SC1091
        # shellcheck source=/etc/os-release
        . /etc/os-release
        echo "${ID:-linux}"
      else
        echo "linux"
      fi
      ;;
    *) echo "unsupported" ;;
  esac
}

ensure_prereqs_linux() {
  log "Installing prerequisite packages with apt"
  sudo apt-get update -y
  sudo apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    git \
    python3 \
    python3-pip \
    python3-venv \
    software-properties-common
}

github_latest_tag() {
  local repo="$1"
  python3 - "$repo" <<'PY'
import json
import sys
import urllib.request

repo = sys.argv[1]
url = f"https://api.github.com/repos/{repo}/releases/latest"
req = urllib.request.Request(url, headers={
    "Accept": "application/vnd.github+json",
    "User-Agent": "zshell-bootstrap"
})
with urllib.request.urlopen(req) as resp:
    data = json.load(resp)
tag = data.get("tag_name", "")
if not tag:
    raise SystemExit("unable to determine latest release tag")
print(tag)
PY
}

ensure_prereqs_macos() {
  if ! command_exists xcode-select; then
    err "Developer tools (xcode-select) not available; install manually before running."
    exit 1
  fi
  if ! command_exists brew; then
    log "Installing Homebrew"
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    if [ -d /opt/homebrew/bin ]; then
      eval "$(/opt/homebrew/bin/brew shellenv)"
    fi
  else
    eval "$(/opt/homebrew/bin/brew shellenv 2>/dev/null || true)"
  fi
  log "Ensuring brew prerequisites"
  brew update
  brew install git curl ansible python || true
}

ensure_ansible_linux() {
  local latest_tag
  latest_tag="$(github_latest_tag "ansible/ansible" | tr -d '\n')"
  local latest_clean="${latest_tag#v}"
  local current_version=""
  if command_exists ansible; then
    current_version="$(ansible --version 2>/dev/null | awk 'NR==1 {print $2}' | sed 's/^v//')"
  fi
  if [ -n "$current_version" ] && [ "$current_version" = "$latest_clean" ]; then
    log "Ansible ${latest_clean} already installed"
    return
  fi

  local venv_dir="$HOME/.local/share/ansible-venv"
  local bin_dir="$HOME/.local/bin"
  ensure_directory "$bin_dir"
  ensure_directory "$venv_dir"

  if [ ! -e "$venv_dir/bin/python" ]; then
    python3 -m venv "$venv_dir"
  fi

  "$venv_dir/bin/python" -m pip install --upgrade pip setuptools wheel
  "$venv_dir/bin/python" -m pip install --upgrade "https://github.com/ansible/ansible/archive/refs/tags/${latest_tag}.tar.gz"

  for tool in ansible ansible-playbook ansible-galaxy ansible-config; do
    ln -sf "$venv_dir/bin/$tool" "$bin_dir/$tool"
  done

  log "Installed Ansible ${latest_clean} from GitHub releases"
}

ensure_ansible_macos() {
  if ! command_exists ansible; then
    log "Installing Ansible with Homebrew"
    brew install ansible
  else
    log "Upgrading Ansible with Homebrew"
    brew upgrade ansible || true
  fi
}

ensure_chezmoi() {
  if command_exists chezmoi; then
    log "chezmoi already installed"
    return
  fi
  log "Installing chezmoi from upstream script"
  if ! sh -c "$(curl -fsLS get.chezmoi.io)" -- -b "$HOME/.local/bin"; then
    err "chezmoi installation failed"
    exit 1
  fi
  export PATH="$HOME/.local/bin:$PATH"
}

clone_repo() {
  if command_exists git; then
    local current_root
    current_root="$(pwd)"
    git config --global --add safe.directory "$WORKDIR" || true
    git config --global --add safe.directory "$current_root" || true
    git config --global --add safe.directory "$current_root/.git" || true
  fi
  ensure_directory "$(dirname "$WORKDIR")"
  if [ -d "$WORKDIR/.git" ]; then
    log "Updating repository in $WORKDIR"
    git -C "$WORKDIR" fetch origin
    git -C "$WORKDIR" checkout "$REPO_BRANCH"
    git -C "$WORKDIR" pull --ff-only origin "$REPO_BRANCH"
  else
    log "Cloning repository to $WORKDIR"
    git clone --branch "$REPO_BRANCH" "$REPO_URL" "$WORKDIR"
  fi
}

run_chezmoi() {
  if chezmoi source-path >/dev/null 2>&1; then
    log "Applying existing chezmoi state"
    if chezmoi git -- status >/dev/null 2>&1; then
      chezmoi git -- pull --ff-only || true
    fi
    chezmoi apply
  else
    log "Initializing chezmoi from $CHEZMOI_REPO"
    chezmoi init --apply "$CHEZMOI_REPO"
  fi
}

install_collections() {
  log "Installing Ansible collections"
  ansible-galaxy collection install -r "$WORKDIR/requirements.yml" --force
}

run_playbook() {
  pushd "$WORKDIR" >/dev/null
  local cmd=(ansible-playbook playbooks/bootstrap.yml --extra-vars "profile=${PROFILE}")
  if [ "$EUID" -ne 0 ] && [ -t 0 ]; then
    cmd+=(--ask-become-pass)
  fi
  log "Running Ansible playbook"
  "${cmd[@]}"
  popd >/dev/null
}

main() {
  local os_id
  os_id=$(detect_os)
  case "$os_id" in
    macos)
      ensure_prereqs_macos
      ensure_ansible_macos
      ;;
    ubuntu|debian|linux)
      ensure_prereqs_linux
      ensure_ansible_linux
      ;;
    *)
      err "Unsupported operating system: $os_id"
      exit 1
      ;;
  esac
  ensure_chezmoi
  clone_repo
  run_chezmoi
  install_collections
  run_playbook
  log "Bootstrap completed successfully"
}

main "$@"
