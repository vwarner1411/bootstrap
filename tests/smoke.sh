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

echo "[tests] Checking PowerShell release metadata"
python3 - <<'PY'
import json
import sys
import urllib.request

url = "https://api.github.com/repos/PowerShell/PowerShell/releases/latest"
with urllib.request.urlopen(url) as resp:
    data = json.load(resp)

assets = data.get("assets", [])
asset = next((a for a in assets if a.get("name", "").endswith("linux-x64.tar.gz")), None)
if not asset:
    raise SystemExit("No PowerShell linux-x64 asset found in latest release")
if not asset.get("browser_download_url"):
    raise SystemExit("PowerShell asset missing download URL")
print(asset["browser_download_url"])
PY

echo "[tests] Smoke test complete"
