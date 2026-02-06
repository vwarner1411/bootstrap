#!/usr/bin/env bash
set -euo pipefail

DEFAULT_REPO_URL="https://github.com/vwarner1411/bootstrap.git"
REPO_URL="${REPO_URL:-}"
REPO_BRANCH="${REPO_BRANCH:-}"
if [ -z "$REPO_URL" ]; then
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  if command -v git >/dev/null 2>&1 && git -C "$SCRIPT_DIR" rev-parse --show-toplevel >/dev/null 2>&1; then
    LOCAL_REPO_ROOT="$(git -C "$SCRIPT_DIR" rev-parse --show-toplevel)"
    REPO_URL="file://${LOCAL_REPO_ROOT}"
    if [ -z "$REPO_BRANCH" ]; then
      REPO_BRANCH="$(git -C "$LOCAL_REPO_ROOT" rev-parse --abbrev-ref HEAD)"
    fi
  else
    REPO_URL="$DEFAULT_REPO_URL"
  fi
fi
REPO_BRANCH="${REPO_BRANCH:-main}"
CHEZMOI_REPO="${CHEZMOI_REPO:-https://github.com/vwarner1411/dotfiles.git}"
WORKDIR="${WORKDIR:-$HOME/.local/share/bootstrap}"
PROFILE="${PROFILE:-desktop}"
ANSIBLE_EXTRA_VARS="${ANSIBLE_EXTRA_VARS:-}"

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
    "User-Agent": "bootstrap-installer"
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
  local brew_bin=""
  if ! command_exists xcode-select; then
    err "Developer tools (xcode-select) not available; install manually before running."
    exit 1
  fi
  if ! command_exists brew; then
    log "Installing Homebrew"
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  fi

  brew_bin="$(command -v brew || true)"
  if [ -z "$brew_bin" ] && [ -x /opt/homebrew/bin/brew ]; then
    brew_bin="/opt/homebrew/bin/brew"
  fi
  if [ -z "$brew_bin" ] && [ -x /usr/local/bin/brew ]; then
    brew_bin="/usr/local/bin/brew"
  fi
  if [ -z "$brew_bin" ]; then
    err "Homebrew not found after installation attempt."
    exit 1
  fi

  eval "$("$brew_bin" shellenv)"
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
  run_as_target sh -c "grep -qs 'export PATH=\"\$HOME/.local/bin:\$PATH\"' \"\$HOME/.profile\" || printf '\n# Added by bootstrap script\nexport PATH=\"\$HOME/.local/bin:\$PATH\"\n' >> \"\$HOME/.profile\""

  if [ -x "$TARGET_HOME/.local/bin/chezmoi" ]; then
    if [ -w /usr/local/bin ]; then
      ln -sf "$TARGET_HOME/.local/bin/chezmoi" /usr/local/bin/chezmoi || true
    elif command_exists sudo; then
      sudo mkdir -p /usr/local/bin || true
      sudo ln -sf "$TARGET_HOME/.local/bin/chezmoi" /usr/local/bin/chezmoi || true
    fi
  fi
}

configure_chezmoi_profile() {
  detect_target_context
  local profile_value="${PROFILE:-desktop}"
  local config_dir="$TARGET_HOME/.config/chezmoi"
  local config_file="$config_dir/chezmoi.toml"

  run_as_target mkdir -p "$config_dir"

  run_as_target python3 - "$config_file" "$profile_value" <<'PY'
import sys
from collections import OrderedDict
from pathlib import Path

path = Path(sys.argv[1])
profile = sys.argv[2]

def load_toml(text):
    if not text.strip():
        return {}
    try:
        import tomllib  # Python 3.11+
        return tomllib.loads(text)
    except ModuleNotFoundError:
        try:
            import tomli
            return tomli.loads(text)
        except ModuleNotFoundError:
            return {}
    except Exception:
        return {}

def ensure_ordered(mapping):
    ordered = OrderedDict()
    for key, value in mapping.items():
        if isinstance(value, dict):
            ordered[key] = ensure_ordered(value)
        else:
            ordered[key] = value
    return ordered

scalars = OrderedDict()
sections = OrderedDict()

if path.exists():
    existing = load_toml(path.read_text(encoding="utf-8"))
    if isinstance(existing, dict):
        existing = ensure_ordered(existing)
        for key, value in existing.items():
            if isinstance(value, dict):
                sections[key] = ensure_ordered(value)
            else:
                scalars[key] = value

data_section = sections.get("data")
if not isinstance(data_section, dict):
    data_section = OrderedDict()
sections["data"] = data_section
data_section["bootstrap_profile"] = profile

def format_value(value):
    if isinstance(value, str):
        escaped = (
            value.replace("\\", "\\\\")
                 .replace("\"", "\\\"")
        )
        return f"\"{escaped}\""
    if isinstance(value, bool):
        return "true" if value else "false"
    if isinstance(value, (int, float)):
        return str(value)
    if isinstance(value, list):
        return "[ " + ", ".join(format_value(item) for item in value) + " ]"
    if value is None:
        return "\"\""
    return format_value(str(value))

lines = []
for key, value in scalars.items():
    lines.append(f"{key} = {format_value(value)}")
    lines.append("")

for section, values in sections.items():
    lines.append(f"[{section}]")
    for key, value in values.items():
        lines.append(f"{key} = {format_value(value)}")
    lines.append("")

result = "\n".join(lines).strip()
if result:
    result += "\n"
path.write_text(result, encoding="utf-8")
PY
}

clone_repo() {
  local source_repo_path=""
  if [[ "$REPO_URL" == file://* ]]; then
    source_repo_path="${REPO_URL#file://}"
  fi

  if [ -n "$source_repo_path" ] && [ -d "$source_repo_path" ]; then
    local source_real workdir_real
    source_real="$(cd "$source_repo_path" && pwd -P)"
    ensure_directory "$WORKDIR"
    workdir_real="$(cd "$WORKDIR" && pwd -P)"

    if [ "$source_real" != "$workdir_real" ]; then
      log "Syncing local working tree from $source_real to $workdir_real"
      rsync -a --delete --exclude ".git/" "$source_real"/ "$workdir_real"/
    else
      log "WORKDIR matches source repository; using current tree in place"
    fi
    return
  fi

  if command_exists git; then
    local current_root
    current_root="$(pwd)"
    git config --global --add safe.directory "$WORKDIR" || true
    git config --global --add safe.directory "$current_root" || true
    git config --global --add safe.directory "$current_root/.git" || true
  fi
  ensure_directory "$(dirname "$WORKDIR")"
  if [ -d "$WORKDIR/.git" ]; then
    local origin_url
    origin_url="$(git -C "$WORKDIR" remote get-url origin 2>/dev/null || true)"
    if [ "$origin_url" != "$REPO_URL" ]; then
      log "Updating bootstrap origin remote to $REPO_URL"
      git -C "$WORKDIR" remote set-url origin "$REPO_URL"
    fi
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
  chez_cmd+="   echo '[chezmoi] Updating existing state' >&2;"
  chez_cmd+="   branch=\"\$(chezmoi git -- rev-parse --abbrev-ref HEAD 2>/dev/null || echo '')\";"
  chez_cmd+="   upstream=\"\$(chezmoi git -- rev-parse --abbrev-ref '@{upstream}' 2>/dev/null || echo '')\";"
  chez_cmd+="   status=\"\$(chezmoi git -- status --porcelain 2>/dev/null)\";"
  chez_cmd+="   chezmoi git -- fetch origin >/dev/null 2>&1 || true;"
  chez_cmd+="   if [ -n \"\$status\" ]; then"
  chez_cmd+="     echo '[chezmoi] Discarding local changes to sync with upstream' >&2;"
  chez_cmd+="   fi;"
  chez_cmd+="   if [ -n \"\$upstream\" ]; then"
  chez_cmd+="     chezmoi git -- reset --hard \"\$upstream\" >/dev/null 2>&1 || true;"
  chez_cmd+="   elif [ -n \"\$branch\" ] && chezmoi git -- show-ref --verify --quiet \"refs/remotes/origin/\${branch}\"; then"
  chez_cmd+="     chezmoi git -- reset --hard \"origin/\${branch}\" >/dev/null 2>&1 || true;"
  chez_cmd+="   else"
  chez_cmd+="     chezmoi git -- reset --hard >/dev/null 2>&1 || true;"
  chez_cmd+="   fi;"
  chez_cmd+="   if ! chezmoi update --apply --force; then"
  chez_cmd+="     echo '[chezmoi] update failed; attempting direct apply' >&2;"
  chez_cmd+="     chezmoi apply --force;"
  chez_cmd+="   fi;"
  chez_cmd+=" else"
  init_repo="$CHEZMOI_REPO"
  if [[ "$init_repo" == file://* ]]; then
    init_repo="${init_repo#file://}"
  fi
  if [[ "$init_repo" == /* || "$init_repo" == ./* || "$init_repo" == ../* || "$init_repo" == ~* ]]; then
    repo_path_literal=$(printf '%q' "$init_repo")
    init_cmd="chezmoi init --apply --force --source ${repo_path_literal}"
  else
    repo_path_literal=$(printf '%q' "$CHEZMOI_REPO")
    init_cmd="chezmoi init --apply --force ${repo_path_literal}"
  fi
  chez_cmd+="   echo '[chezmoi] Initializing from $CHEZMOI_REPO' >&2;"
  chez_cmd+="   $init_cmd;"
  chez_cmd+=" fi"
  run_as_target bash -lc "$chez_cmd"
}

stage_server_prep_assets() {
  if [ "${PROFILE:-desktop}" != "server" ]; then
    return
  fi
  detect_target_context
  local prep_dir="$TARGET_HOME/.local/share/bootstrap/server_prep"
  local old_prep_dir="$TARGET_HOME/.local/share/chezmoi/scripts/server_prep"
  local old_target_dir="$TARGET_HOME/scripts/server_prep"
  local old_target_script="$TARGET_HOME/scripts/server-prep.sh"
  if run_as_target test -d "$old_prep_dir"; then
    run_as_target rm -rf "$old_prep_dir"
  fi
  if run_as_target test -d "$old_target_dir"; then
    run_as_target rm -rf "$old_target_dir"
  fi
  if run_as_target test -e "$old_target_script"; then
    run_as_target rm -f "$old_target_script"
  fi
  run_as_target mkdir -p "$prep_dir/templates"
  run_as_target install -m 0644 "$WORKDIR/playbooks/server_prep.yml" "$prep_dir/server_prep.yml"
  run_as_target install -m 0644 "$WORKDIR/playbooks/templates/server-prep-netplan.yaml.j2" "$prep_dir/templates/server-prep-netplan.yaml.j2"
  run_as_target install -m 0755 "$WORKDIR/scripts/server-prep.sh" "$prep_dir/server-prep.sh"
  run_as_target ln -sf "$prep_dir/server-prep.sh" "$TARGET_HOME/server-prep.sh"
  log "Staged server prep playbook at $prep_dir"
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
  if [ -n "$ANSIBLE_EXTRA_VARS" ]; then
    cmd+=(--extra-vars "$ANSIBLE_EXTRA_VARS")
  fi
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
  detect_target_context
  if [ "$os_id" = "macos" ] && [ "$TARGET_USER" = "root" ]; then
    err "On macOS, run bootstrap as a regular user (not root)."
    exit 1
  fi
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
  configure_chezmoi_profile
  clone_repo
  install_collections
  run_playbook
  run_chezmoi
  stage_server_prep_assets
  log "Bootstrap completed successfully"
}

main "$@"
