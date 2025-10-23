#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "[tests] Installing required collections"
mkdir -p "${ROOT_DIR}/collections"
ansible-galaxy collection install -r "${ROOT_DIR}/requirements.yml" --force -p "${ROOT_DIR}/collections" >/dev/null

echo "[tests] Running ansible-playbook syntax check"
ansible-playbook --syntax-check "${ROOT_DIR}/playbooks/bootstrap.yml"

echo "[tests] Running ansible-lint (if available)"
if command -v ansible-lint >/dev/null 2>&1; then
  cli_version="$(ansible --version 2>/dev/null | head -n1 | sed -E 's/.* ([0-9]+(\\.[0-9]+)*)$/\\1/')"
  py_version="$(python3 - <<'PY'
import ansible
print(getattr(ansible, '__version__', ''), end='')
PY
)"
  if [ -n "${cli_version}" ] && [ -n "${py_version}" ] && [ "${cli_version}" != "${py_version}" ]; then
    echo "[tests] ansible-lint skipped: CLI version ${cli_version} differs from python module ${py_version}" >&2
  else
    ansible-lint "${ROOT_DIR}/playbooks/bootstrap.yml"
  fi
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
import os
import sys
import urllib.error
import urllib.request

url = "https://api.github.com/repos/PowerShell/PowerShell/releases/latest"
headers = {
    "Accept": "application/vnd.github+json",
    "User-Agent": "zshell-smoke"
}
token = os.getenv("GITHUB_TOKEN")
if token:
    headers["Authorization"] = f"Bearer {token}"

req = urllib.request.Request(url, headers=headers)
try:
    with urllib.request.urlopen(req) as resp:
        data = json.load(resp)
except urllib.error.HTTPError as exc:  # pragma: no cover
    if exc.code == 403:
        print("[tests] Warning: GitHub API rate limit hit, skipping PowerShell asset check", file=sys.stderr)
        sys.exit(0)
    raise

assets = data.get("assets", [])
asset = next((a for a in assets if a.get("name", "").endswith("linux-x64.tar.gz")), None)
if not asset:
    raise SystemExit("No PowerShell linux-x64 asset found in latest release")
if not asset.get("browser_download_url"):
    raise SystemExit("PowerShell asset missing download URL")
print(asset["browser_download_url"])
PY

echo "[tests] Smoke test complete"
