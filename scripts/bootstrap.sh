#!/usr/bin/env bash
set -euo pipefail

REPO_URL="${REPO_URL:-https://github.com/vwarner1411/zshell.git}"
REPO_BRANCH="${REPO_BRANCH:-bootstrap}"
CHEZMOI_REPO="${CHEZMOI_REPO:-https://github.com/vwarner1411/dotfiles.git}"
WORKDIR="${WORKDIR:-$HOME/.local/share/zshell}"
PROFILE="${PROFILE:-desktop}"

TARGET_USER="${TARGET_USER_OVERRIDE:-}"
TARGET_HOME="${TARGET_HOME_OVERRIDE:-}"

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

detect_target_context() {
  if [ -n "$TARGET_USER" ] && [ -n "$TARGET_HOME" ]; then
    return
  fi

  local detected_user detected_home
  detected_user="${TARGET_USER_OVERRIDE:-${SUDO_USER:-${USER:-$(id -un)}}}"
  TARGET_USER="$detected_user"

  if [ -n "${TARGET_HOME_OVERRIDE:-}" ]; then
    TARGET_HOME="$TARGET_HOME_OVERRIDE"
    return
  fi

  if command_exists python3; then
    detected_home="$(python3 - "$TARGET_USER" <<'PY'
import os, pwd, sys
user = sys.argv[1]
if not user:
    print("", end="")
else:
    try:
        print(pwd.getpwnam(user).pw_dir, end="")
    except KeyError:
        print("", end="")
PY
    )"
  else
    detected_home=""
  fi

  if [ -z "$detected_home" ] && command_exists getent; then
    detected_home="$(getent passwd "$TARGET_USER" 2>/dev/null | cut -d: -f6 || true)"
  fi

  if [ -z "$detected_home" ]; then
    if [ "$TARGET_USER" = "root" ]; then
      detected_home="/root"
    else
      detected_home="/home/$TARGET_USER"
    fi
  fi

  TARGET_HOME="$detected_home"
}

run_as_target() {
  detect_target_context
  if [ "$(id -un)" = "$TARGET_USER" ]; then
    "$@"
    return
  fi

  if command_exists sudo; then
    sudo -u "$TARGET_USER" -- "$@"
  else
    local cmd
    cmd=$(printf '%q ' "$@")
    cmd=${cmd% }
    su - "$TARGET_USER" -c "$cmd"
  fi
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
  detect_target_context

  if run_as_target sh -c "command -v chezmoi >/dev/null 2>&1"; then
    log "chezmoi already installed for ${TARGET_USER}"
  else
    log "Installing chezmoi for ${TARGET_USER}"
    run_as_target mkdir -p "$TARGET_HOME/.local/bin"
    if ! run_as_target sh -c "curl -fsLS get.chezmoi.io | sh -s -- -b \"\$HOME/.local/bin\""; then
      err "chezmoi installation failed"
      exit 1
    fi
  fi

  export PATH="$TARGET_HOME/.local/bin:$PATH"

  run_as_target sh -c "touch \"\$HOME/.profile\""
  run_as_target sh -c "grep -qs 'export PATH=\"\$HOME/.local/bin:\$PATH\"' \"\$HOME/.profile\" || printf '\n# Added by zshell bootstrap\nexport PATH=\"\$HOME/.local/bin:\$PATH\"\n' >> \"\$HOME/.profile\""

  if [ -x "$TARGET_HOME/.local/bin/chezmoi" ]; then
    if [ -w /usr/local/bin ]; then
      ln -sf "$TARGET_HOME/.local/bin/chezmoi" /usr/local/bin/chezmoi || true
    elif command_exists sudo; then
      sudo mkdir -p /usr/local/bin || true
      sudo ln -sf "$TARGET_HOME/.local/bin/chezmoi" /usr/local/bin/chezmoi || true
    fi
  fi
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
  detect_target_context
  local chez_cmd init_cmd init_repo repo_path_literal
  chez_cmd="export PATH=\"\$HOME/.local/bin:\$PATH\";"
  chez_cmd+=" if chezmoi git -- status >/dev/null 2>&1; then"
  chez_cmd+="   echo '[chezmoi] Applying existing state' >&2;"
  chez_cmd+="   chezmoi git -- pull --ff-only || true;"
  chez_cmd+="   chezmoi apply;"
  chez_cmd+=" else"
  init_repo="$CHEZMOI_REPO"
  if [[ "$init_repo" == file://* ]]; then
    init_repo="${init_repo#file://}"
  fi
  if [[ "$init_repo" == /* || "$init_repo" == ./* || "$init_repo" == ../* || "$init_repo" == ~* ]]; then
    repo_path_literal=$(printf '%q' "$init_repo")
    init_cmd="chezmoi init --apply --source ${repo_path_literal}"
  else
    repo_path_literal=$(printf '%q' "$CHEZMOI_REPO")
    init_cmd="chezmoi init --apply ${repo_path_literal}"
  fi
  chez_cmd+="   echo '[chezmoi] Initializing from $CHEZMOI_REPO' >&2;"
  chez_cmd+="   $init_cmd;"
  chez_cmd+=" fi"
  run_as_target bash -lc "$chez_cmd"
}

install_collections() {
  log "Installing Ansible collections"
  ensure_directory "$WORKDIR/collections"
  ansible-galaxy collection install -r "$WORKDIR/requirements.yml" --force -p "$WORKDIR/collections"
}

run_playbook() {
  pushd "$WORKDIR" >/dev/null
  detect_target_context
  local extra_vars
  extra_vars="profile=${PROFILE} shell_user=${TARGET_USER} shell_home=${TARGET_HOME}"
  local cmd=(ansible-playbook playbooks/bootstrap.yml --extra-vars "$extra_vars")
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
