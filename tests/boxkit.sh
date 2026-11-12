#!/usr/bin/env bash
set -euo pipefail
repo="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
tmp="$(mktemp -d)"
trap 'rm -rf -- "$tmp"' EXIT
mkdir -p "$tmp/bin" "$tmp/project"
cat > "$tmp/bin/distrobox" <<'MOCK'
#!/bin/bash
if [ "${1:-}" = list ]; then printf 'ID | NAME | STATUS\n'; fi
MOCK
chmod +x "$tmp/bin/distrobox"
export PATH="$tmp/bin:$PATH"
export BOX_ENTRYPOINT_NAME="$tmp/project"
export DISTROBOX_CONTAINER_NAME="boxkit-ci"
cd "$tmp/project"
bash "$repo/boxkit"
test -f distrobox.ini
test -x box
mkdir -p .distrobox/home
printf 'keep me\n' > .distrobox/home/preserved
if bash "$repo/boxkit"; then
  echo 'FAIL: existing generated files were overwritten' >&2
  exit 1
fi
grep -qx 'keep me' .distrobox/home/preserved
! grep -q 'DISTROBOX_HOST_HOME.*\.ssh' box
grep -q 'MI_PROFILE=container' box
# Exercise the opt-in agent forwarding with a real UNIX socket.
python3 -c 'import socket,sys,time; s=socket.socket(socket.AF_UNIX); s.bind(sys.argv[1]); s.listen(1); time.sleep(30)' "$tmp/agent.sock" &
agent_pid=$!
trap 'kill "$agent_pid" 2>/dev/null || :; rm -rf -- "$tmp"' EXIT
for attempt in {1..50}; do
  [ -S "$tmp/agent.sock" ] && break
  sleep 0.1
done
test -S "$tmp/agent.sock"
export BOX_ENTRYPOINT_NAME="$tmp/agent-project"
mkdir -p "$BOX_ENTRYPOINT_NAME"
BOX_SSH_AGENT_SOCKET="$tmp/agent.sock" bash "$repo/boxkit"
grep -F -- "additional_flags=\"--volume $tmp/agent.sock:/run/boxkit-ssh-agent.sock --env SSH_AUTH_SOCK=/run/boxkit-ssh-agent.sock\"" "$BOX_ENTRYPOINT_NAME/distrobox.ini"
if BOX_ENTRYPOINT_NAME="$tmp/missing-project" BOX_SSH_AGENT_SOCKET="$tmp/missing.sock" bash "$repo/boxkit"; then
  echo 'FAIL: nonexistent agent socket accepted' >&2
  exit 1
fi
if BOX_ENTRYPOINT_NAME="$tmp/relative-project" BOX_SSH_AGENT_SOCKET="relative.sock" bash "$repo/boxkit"; then
  echo 'FAIL: relative agent socket accepted' >&2
  exit 1
fi
echo 'Boxkit regression tests passed'
