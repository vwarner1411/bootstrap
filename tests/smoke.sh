#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "[tests] Running ansible-playbook syntax check"
ansible-playbook --syntax-check "${ROOT_DIR}/playbooks/bootstrap.yml"

echo "[tests] Running ansible-lint (if available)"
if command -v ansible-lint >/dev/null 2>&1; then
  ansible-lint "${ROOT_DIR}/playbooks/bootstrap.yml"
else
  echo "[tests] ansible-lint not installed; skipping" >&2
fi

echo "[tests] Running shellcheck on scripts"
if command -v shellcheck >/dev/null 2>&1; then
  shellcheck "${ROOT_DIR}/scripts/bootstrap.sh"
else
  echo "[tests] shellcheck not installed; skipping" >&2
fi

echo "[tests] Smoke test complete"
