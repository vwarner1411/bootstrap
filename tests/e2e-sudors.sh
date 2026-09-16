#!/usr/bin/env bash
# End-to-end privilege escalation check against sudo-rs, as a non-root user.
#
# This is the configuration that reaches production but that no other job
# covers: the Linux e2e jobs run as root in containers, so they never enter
# arrange_become at all, and macos-e2e only exercises original sudo. Run inside
# an ubuntu:26.04 container by .github/workflows/ci.yml.
#
# Tool installation is deliberately out of scope here; ubuntu-e2e and debian-e2e
# cover that. This runs bootstrap's real run_playbook against a minimal playbook
# so the check stays fast while still proving escalation end to end.
set -euo pipefail

REPO_DIR="${REPO_DIR:-/workspace}"
TEST_USER="${TEST_USER:-tester}"
TEST_PASSWORD="${TEST_PASSWORD:-bootstrap-test-pw}"
WORK="/home/${TEST_USER}/escalation"
OUT="/tmp/escalation-output.log"
PROOF="/root/escalation-proof"

log() { printf '\n[e2e-sudors] %s\n' "$*"; }
fail() { printf '\n[e2e-sudors] FAIL: %s\n' "$*" >&2; exit 1; }

export DEBIAN_FRONTEND=noninteractive

log "Installing packages"
apt-get update -qq
apt-get install -y -qq --no-install-recommends \
  sudo-rs ansible-core python3 ca-certificates >/dev/null

log "Confirming sudo-rs is the sudo under test"
update-alternatives --set sudo /usr/bin/sudo-rs >/dev/null 2>&1 || true
sudo --version | head -n 1
if ! sudo --version | head -n 1 | grep -qi 'sudo-rs'; then
  fail "expected sudo-rs to be the default sudo; this test proves nothing otherwise"
fi

log "Creating password-authenticated sudo user ${TEST_USER}"
useradd -m -s /bin/bash "$TEST_USER"
printf '%s:%s\n' "$TEST_USER" "$TEST_PASSWORD" | chpasswd
usermod -aG sudo "$TEST_USER"

log "Staging a playbook whose only task requires root"
mkdir -p "$WORK/playbooks"
cat > "$WORK/playbooks/bootstrap.yml" <<'YML'
- name: Escalation check
  hosts: localhost
  connection: local
  gather_facts: false
  become: true
  tasks:
    - name: Write a file only root may create
      ansible.builtin.copy:
        dest: /root/escalation-proof
        content: "escalated\n"
        mode: "0600"
YML
chown -R "${TEST_USER}:${TEST_USER}" "$WORK"

cat > /tmp/run-escalation.sh <<EOF
#!/usr/bin/env bash
set -euo pipefail
export BOOTSTRAP_SOURCE_ONLY=1
export WORKDIR="${WORK}"
export PROFILE=server
# shellcheck disable=SC1090
source "${REPO_DIR}/scripts/bootstrap.sh"
run_playbook
EOF
chmod 0755 /tmp/run-escalation.sh

log "Running escalation as ${TEST_USER} on a pty"
rc=0
TEST_SUDO_PASSWORD="$TEST_PASSWORD" TEST_OUTPUT="$OUT" \
  python3 "${REPO_DIR}/tests/pty_run.py" \
  su - "$TEST_USER" -c "bash /tmp/run-escalation.sh" || rc=$?

log "Checking results (run exited ${rc})"

if grep -q "BECOME password" "$OUT"; then
  fail "Ansible prompted for a become password; it would hit the sudo-rs prompt bug"
fi
if ! grep -q "Granted ${TEST_USER} passwordless sudo" "$OUT"; then
  fail "the temporary sudoers grant was never installed, so a different path was taken"
fi
if [ "$rc" -ne 0 ]; then
  fail "escalation run exited ${rc}"
fi
if [ ! -f "$PROOF" ]; then
  fail "playbook did not escalate; ${PROOF} was never created"
fi
if [ "$(stat -c %U "$PROOF")" != "root" ]; then
  fail "${PROOF} is not owned by root, so become did not reach root"
fi

leftover="$(find /etc/sudoers.d -name '99-bootstrap-*' 2>/dev/null || true)"
if [ -n "$leftover" ]; then
  fail "sudoers grant left behind after the run: ${leftover}"
fi

log "PASS: grant installed, Ansible escalated to root, grant removed afterwards"
