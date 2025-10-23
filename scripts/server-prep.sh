#!/usr/bin/env bash
set -euo pipefail

ORIGINAL_HOME="${SERVER_PREP_HOME:-$HOME}"
ORIGINAL_USER="${SERVER_PREP_USER:-$(id -un)}"
ANSIBLE_BIN_RESOLVED="${SERVER_PREP_ANSIBLE_BIN:-}"

if [[ -z "$ANSIBLE_BIN_RESOLVED" ]]; then
  if ! ANSIBLE_BIN_RESOLVED="$(command -v ansible-playbook 2>/dev/null)"; then
    echo "[server-prep] ansible-playbook not found in PATH." >&2
    exit 1
  fi
fi

SCRIPT_DIR="${ORIGINAL_HOME}/.local/share/chezmoi/scripts/server_prep"
PLAYBOOK="${SCRIPT_DIR}/server_prep.yml"

if [[ ! -f "$PLAYBOOK" ]]; then
  echo "[server-prep] Playbook not found at ${PLAYBOOK}" >&2
  exit 1
fi

if [[ "${SERVER_PREP_REEXEC:-0}" != "1" && "$EUID" -ne 0 ]]; then
  exec sudo SERVER_PREP_REEXEC=1 \
            SERVER_PREP_HOME="$ORIGINAL_HOME" \
            SERVER_PREP_USER="$ORIGINAL_USER" \
            SERVER_PREP_ANSIBLE_BIN="$ANSIBLE_BIN_RESOLVED" \
            "$0" "$@"
fi

if [[ "$EUID" -ne 0 ]]; then
  echo "[server-prep] Unable to obtain root privileges." >&2
  exit 1
fi

exec "$ANSIBLE_BIN_RESOLVED" "$PLAYBOOK" \
  --extra-vars "server_prep_user_home=${ORIGINAL_HOME} server_prep_user=${ORIGINAL_USER}" "$@"
