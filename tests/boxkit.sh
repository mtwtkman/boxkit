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
# Verify explicit Mi provisioning with a local checkout.
mkdir -p "$tmp/mock-mi"
cat > "$tmp/mock-mi/mi" <<'MOCK'
#!/usr/bin/env bash
printf '%s:%s\n' "${MI_PROFILE:-}" "$*" > "$BOX_TEST_MI_LOG"
MOCK
chmod +x "$tmp/mock-mi/mi"
export BOX_TEST_MI_LOG="$tmp/mi-invocation"
export CONTAINER_ID=boxkit-ci
export XDG_CONFIG_HOME="$tmp/project/.distrobox/home/.config"
mkdir -p "$XDG_CONFIG_HOME"
cd "$tmp/project"
BOX_CONTAINER_INSTANCE=initial-test BOX_PROVISIONER=mi MI_REPO_PATH="$tmp/mock-mi" bash ./box _init
grep -qx 'container:deploy' "$BOX_TEST_MI_LOG"
test -f .distrobox/home/.bashrc

# Unsupported provisioners must fail without completing initialization.
export XDG_CONFIG_HOME="$tmp/invalid-project/.config"
mkdir -p "$XDG_CONFIG_HOME" "$tmp/invalid-project"
cd "$tmp/invalid-project"
BOX_ENTRYPOINT_NAME="$tmp/invalid-project" bash "$repo/boxkit"
if BOX_CONTAINER_INSTANCE=invalid-test BOX_PROVISIONER=unknown bash ./box _init; then
  echo 'FAIL: unknown provisioner accepted' >&2
  exit 1
fi
test ! -e .distrobox/home/.bashrc
# Host enter must initialize once, and subsequent enters must not reprovision.
cat > "$tmp/bin/distrobox" <<'MOCK'
#!/usr/bin/env bash
case "${1:-}" in
  list)
    printf 'ID | NAME | STATUS | IMAGE\n'
    if [ -f "$BOX_TEST_CONTAINER_ID_FILE" ]; then
      printf '%s | boxkit-ci | Up | archlinux\n' "$(cat "$BOX_TEST_CONTAINER_ID_FILE")"
      printf 'other | boxkit-ci-extra | Up | archlinux\n'
    fi
    ;;
  assemble)
    case "${2:-}" in
      rm) rm -f "$BOX_TEST_CONTAINER_ID_FILE" ;;
      create)
        count=0
        [ -f "$BOX_TEST_COUNTER" ] && count="$(cat "$BOX_TEST_COUNTER")"
        count=$((count + 1))
        printf '%s\n' "$count" > "$BOX_TEST_COUNTER"
        printf 'instance-%s\n' "$count" > "$BOX_TEST_CONTAINER_ID_FILE"
        ;;
    esac
    ;;
  enter)
    printf '%s\n' "$*" >> "$BOX_TEST_ENTER_LOG"
    while [ "$#" -gt 0 ] && [ "$1" != -- ]; do shift; done
    shift
    if [ "${1:-}" = /usr/bin/env ]; then
      shift
      while [ "$#" -gt 0 ] && [[ "$1" == *=* ]]; do export "$1"; shift; done
      CONTAINER_ID=boxkit-ci "$@"
    fi
    ;;
esac
MOCK
chmod +x "$tmp/bin/distrobox"
export BOX_TEST_ENTER_LOG="$tmp/enter-invocations"
export BOX_TEST_CONTAINER_ID_FILE="$tmp/container-id"
export BOX_TEST_COUNTER="$tmp/container-count"
export HOME="$tmp/host-home"
mkdir -p "$HOME"
unset CONTAINER_ID
rm -f -- "$tmp/project/.distrobox/initialized"
# Project setup is optional, runs from the project directory and needs no executable bit.
cat > "$tmp/project/box_setup.sh" <<'SETUP'
#!/usr/bin/env bash
printf '%s\n' "$PWD" >> "$BOX_TEST_SETUP_LOG"
SETUP
export BOX_TEST_SETUP_LOG="$tmp/setup-invocations"
cd "$tmp/project"
BOX_PROVISIONER=none bash ./box e
test "$(cat .distrobox/initialized)" = instance-1
test -f .distrobox/home/.bashrc
test "$(wc -l < "$BOX_TEST_SETUP_LOG")" -eq 1
test "$(tail -n 1 "$BOX_TEST_SETUP_LOG")" = "$tmp/project"
test "$(grep -c '/usr/bin/env' "$BOX_TEST_ENTER_LOG")" -eq 1
BOX_PROVISIONER=none bash ./box e
test "$(grep -c '/usr/bin/env' "$BOX_TEST_ENTER_LOG")" -eq 1
test "$(wc -l < "$BOX_TEST_SETUP_LOG")" -eq 1
# Recreate changes the container ID and must rerun initialization.
BOX_PROVISIONER=none bash ./box e -r
test "$(cat .distrobox/initialized)" = instance-2
test "$(wc -l < "$BOX_TEST_SETUP_LOG")" -eq 2
test "$(grep -c '/usr/bin/env' "$BOX_TEST_ENTER_LOG")" -eq 2
# Reusing a name after external replacement must not reuse the stale marker.
printf 'external-instance\n' > "$BOX_TEST_CONTAINER_ID_FILE"
BOX_PROVISIONER=none bash ./box e
test "$(cat .distrobox/initialized)" = external-instance
test "$(wc -l < "$BOX_TEST_SETUP_LOG")" -eq 3
test "$(grep -c '/usr/bin/env' "$BOX_TEST_ENTER_LOG")" -eq 3
# Failed setup must leave the instance uninitialized and retry on next enter.
cat > box_setup.sh <<'SETUP'
#!/usr/bin/env bash
if [ -f "$BOX_TEST_SETUP_FAIL_FLAG" ]; then exit 27; fi
printf 'ok\n' >> "$BOX_TEST_SETUP_RETRY_LOG"
SETUP
export BOX_TEST_SETUP_FAIL_FLAG="$tmp/setup-fail"
export BOX_TEST_SETUP_RETRY_LOG="$tmp/setup-retries"
touch "$BOX_TEST_SETUP_FAIL_FLAG"
printf 'failed-instance\n' > "$BOX_TEST_CONTAINER_ID_FILE"
if BOX_PROVISIONER=none bash ./box e; then
  echo 'FAIL: failing box_setup.sh was accepted' >&2
  exit 1
fi
test "$(cat .distrobox/initialized)" = external-instance
rm -f "$BOX_TEST_SETUP_FAIL_FLAG"
BOX_PROVISIONER=none bash ./box e
test "$(cat .distrobox/initialized)" = failed-instance
test "$(wc -l < "$BOX_TEST_SETUP_RETRY_LOG")" -eq 1
# Broken setup symlink must fail rather than silently skip.
ln -sf "$tmp/missing-setup" box_setup.sh
printf 'broken-instance\n' > "$BOX_TEST_CONTAINER_ID_FILE"
if BOX_PROVISIONER=none bash ./box e; then
  echo 'FAIL: broken setup symlink was accepted' >&2
  exit 1
fi
test "$(cat .distrobox/initialized)" = failed-instance
rm -f box_setup.sh
BOX_PROVISIONER=none bash ./box e
test "$(cat .distrobox/initialized)" = broken-instance
if bash ./box i; then
  echo 'FAIL: legacy init command still accepted' >&2
  exit 1
fi

echo 'Boxkit regression tests passed'
