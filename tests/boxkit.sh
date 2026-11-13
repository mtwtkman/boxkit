#!/usr/bin/env bash
set -euo pipefail
repo="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
tmp="$(mktemp -d)"
trap 'rm -rf -- "$tmp"' EXIT
mkdir -p "$tmp/project" "$tmp/bin"
export PATH="$tmp/bin:$PATH"
export HOME="$tmp/host-home"
mkdir -p "$HOME"
cd "$tmp/project"
bash "$repo/boxkit" init
[[ -f boxkit.ini && -x box ]]
bash -n box
grep -q '^engine = podman$' boxkit.ini
grep -q '^image = docker.io/library/archlinux:latest$' boxkit.ini
grep -q '^dbus_session = true$' boxkit.ini
[[ ! -e Containerfile ]]
if bash "$repo/boxkit" init; then echo 'unexpected overwrite' >&2; exit 1; fi
mkdir -p .boxkit/home
printf 'keep\n' > .boxkit/home/preserved
echo 'invalid_setting = true' >> boxkit.ini
if bash ./box list 2>/dev/null; then echo 'invalid INI accepted' >&2; exit 1; fi
sed -i '/invalid_setting = true/d' boxkit.ini
sed -i 's/wayland = true/wayland = false/' boxkit.ini
cat >> boxkit.ini <<'CONFIG'

[packages]
additional = fd fzf neovim ripgrep make gcc

[setup]
hook = echo 'Project initialization'

[engine_args]
create_arg = --hostname=haskell-dev
create_arg = --env=EXAMPLE=value
CONFIG

# Provide a real host D-Bus socket for the integration tests.
mkdir -p "$tmp/runtime"
python3 -c 'import socket,sys,time; s=socket.socket(socket.AF_UNIX); s.bind(sys.argv[1]); s.listen(1); time.sleep(90)' "$tmp/runtime/bus" &
bus_pid=$!
trap 'kill "$bus_pid" 2>/dev/null || :; rm -rf -- "$tmp"' EXIT
for attempt in {1..60}; do
  [[ -S "$tmp/runtime/bus" ]] && break
  sleep 0.05
done
[[ -S "$tmp/runtime/bus" ]]
export XDG_RUNTIME_DIR="$tmp/runtime"
# Host address is intentionally different: container must never inherit it.
export DBUS_SESSION_BUS_ADDRESS="unix:path=$tmp/stale-session-bus"

cat > "$tmp/bin/podman" <<'MOCK'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$*" >> "$BOX_TEST_LOG"
printf '%s\n' "${DBUS_SESSION_BUS_ADDRESS:-unset}" >> "$BOX_TEST_HOST_DBUS_LOG"
case "${1:-}" in
  create)
    printf 'container-instance-%s\n' "$(date +%s%N)" > "$BOX_TEST_ID"
    printf 'running=false\n' > "$BOX_TEST_STATUS"
    ;;
  container)
    [[ "${2:-}" == inspect ]] || exit 2
    [[ -f "$BOX_TEST_ID" ]] || exit 1
    if [[ "$*" == *'{{.Id}}'* ]]; then cat "$BOX_TEST_ID"; else
      if grep -q '^running=true$' "$BOX_TEST_STATUS"; then echo true; else echo false; fi
    fi
    ;;
  start) printf 'running=true\n' > "$BOX_TEST_STATUS";;
  stop) printf 'running=false\n' > "$BOX_TEST_STATUS";;
  rm) rm -f "$BOX_TEST_ID" "$BOX_TEST_STATUS";;
  ps) echo 'NAMES STATUS IMAGE';;
  exec)
    # Validate every shell payload exactly as Podman will pass it. Checking
    # only the outer boxkit Bash syntax misses errors inside -c strings.
    args=("$@")
    for ((i=0; i<${#args[@]}; i++)); do
      if [[ "${args[i]}" == /bin/sh && "${args[i+1]:-}" == -c ]]; then
        /bin/sh -n -c "${args[i+2]}" || exit 1
      fi
    done
    if [[ "$*" == *' /bin/bash /workspace/box _init'* ]]; then
      for arg in "$@"; do
        if [[ "$arg" == BOX_CONTAINER_INSTANCE=* ]]; then
          printf '%s\n' "${arg#BOX_CONTAINER_INSTANCE=}" > .boxkit/state/initialized
        fi
      done
    fi
    ;;
esac
MOCK
chmod +x "$tmp/bin/podman"
export BOX_TEST_LOG="$tmp/podman-log"
export BOX_TEST_HOST_DBUS_LOG="$tmp/podman-host-dbus-log"
export BOX_TEST_ID="$tmp/container-id"
export BOX_TEST_STATUS="$tmp/container-status"
export BOX_PROVISIONER=none
./box enter
[[ -f .boxkit/state/initialized ]]
# Every interactive entry must source .bashrc (bash -i, not login-only bash -l).
grep -Fq -- ' /bin/bash -i' "$BOX_TEST_LOG"
grep -Fq 'box_name="${BOXKIT_NAME:-${HOSTNAME:-box}}"' box
# The generated shell preset must not require the optional hostname executable.
! grep -Fq 'box_name="${CONTAINER_ID:-$(hostname)}"' box
# The Podman CLI must receive the canonical host session bus, not the stale value.
grep -Fxq "unix:path=$tmp/runtime/bus" "$BOX_TEST_HOST_DBUS_LOG"
! grep -Fq "unix:path=$tmp/stale-session-bus" "$BOX_TEST_HOST_DBUS_LOG"
grep -q 'create --name' "$BOX_TEST_LOG"
grep -Fq -- '--env BOXKIT_NAME=project-dev' "$BOX_TEST_LOG"

grep -Fq -- '--hostname=haskell-dev' "$BOX_TEST_LOG"
grep -Fq -- '--env=EXAMPLE=value' "$BOX_TEST_LOG"
grep -Fq -- 'fd fzf neovim ripgrep make gcc' "$BOX_TEST_LOG"
# The Arch bootstrap must fully upgrade before installing new packages.
# Synchronizing only (-Sy) causes OpenSSL SONAME conflicts in older images.
grep -Fq -- 'pacman -Syu --noconfirm --needed bash git curl ca-certificates openssh' "$BOX_TEST_LOG"
if grep -Eq 'pacman -Sy( |$)' "$BOX_TEST_LOG"; then
  echo 'FAIL: Arch bootstrap performs a partial upgrade' >&2
  exit 1
fi

grep -q 'docker.io/library/archlinux:latest' "$BOX_TEST_LOG"
grep -Fq -- '--env DBUS_SESSION_BUS_ADDRESS=unix:path=/home/dev/.boxkit-runtime/bus' "$BOX_TEST_LOG"
grep -Fq -- "src=$tmp/runtime/bus,dst=/home/dev/.boxkit-runtime/bus" "$BOX_TEST_LOG"
grep -Fq -- '--env XDG_RUNTIME_DIR=/home/dev/.boxkit-runtime' "$BOX_TEST_LOG"
grep -q -- '--userns=keep-id' "$BOX_TEST_LOG"
grep -q -- '--mount type=bind,src=' "$BOX_TEST_LOG"
grep -q ' /bin/bash /workspace/box _init' "$BOX_TEST_LOG"
count="$(grep -c ' /bin/bash /workspace/box _init' "$BOX_TEST_LOG")"
./box enter
[[ "$(grep -c ' /bin/bash /workspace/box _init' "$BOX_TEST_LOG")" == "$count" ]]
# Stopping and restarting the same container should not require recreation.
./box stop
./box enter
[[ "$(grep -c ' /bin/bash /workspace/box _init' "$BOX_TEST_LOG")" == "$count" ]]
# A new bus socket inode requires explicit recreation so no stale socket is used.
kill "$bus_pid" 2>/dev/null || :
wait "$bus_pid" 2>/dev/null || :
# Keep the previous socket inode allocated to avoid nondeterministic reuse.
mv "$tmp/runtime/bus" "$tmp/runtime/bus-old"
python3 -c 'import socket,sys,time; s=socket.socket(socket.AF_UNIX); s.bind(sys.argv[1]); s.listen(1); time.sleep(90)' "$tmp/runtime/bus" &
bus_pid=$!
for attempt in {1..60}; do [[ -S "$tmp/runtime/bus" ]] && break; sleep 0.05; done
if ./box enter 2>/dev/null; then echo 'replaced bus socket accepted without recreation' >&2; exit 1; fi
./box enter -r
grep -Fq -- '--env DBUS_SESSION_BUS_ADDRESS=unix:path=/home/dev/.boxkit-runtime/bus' "$BOX_TEST_LOG"
# Shell syntax is not interpreted in create_arg values.
sed -i 's/create_arg = --hostname=haskell-dev/create_arg = hostname=haskell-dev/' boxkit.ini
if ./box list 2>/dev/null; then echo 'invalid create_arg accepted' >&2; exit 1; fi
sed -i 's/create_arg = hostname=haskell-dev/create_arg = --hostname=haskell-dev/' boxkit.ini
./box exec git --version
grep -q 'git --version' "$BOX_TEST_LOG"
./box stop
grep -q '^running=false$' "$BOX_TEST_STATUS"
sed -i 's/gpu = false/gpu = true/' boxkit.ini
if ./box enter 2>/dev/null; then echo 'changed settings accepted without recreation' >&2; exit 1; fi
sed -i 's/gpu = true/gpu = false/' boxkit.ini
./box enter -r
grep -qx 'keep' .boxkit/home/preserved
./box rm
[[ ! -f "$BOX_TEST_ID" ]]
grep -qx 'keep' .boxkit/home/preserved
echo 'Boxkit regression tests passed'
