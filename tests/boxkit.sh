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
[[ ! -e Containerfile ]]
if bash "$repo/boxkit" init; then echo 'unexpected overwrite' >&2; exit 1; fi
mkdir -p .boxkit/home
printf 'keep\n' > .boxkit/home/preserved
echo 'invalid_setting = true' >> boxkit.ini
if bash ./box list 2>/dev/null; then echo 'invalid INI accepted' >&2; exit 1; fi
sed -i '/invalid_setting = true/d' boxkit.ini
sed -i 's/wayland = true/wayland = false/' boxkit.ini
cat > "$tmp/bin/podman" <<'MOCK'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$*" >> "$BOX_TEST_LOG"
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
export BOX_TEST_ID="$tmp/container-id"
export BOX_TEST_STATUS="$tmp/container-status"
export BOX_PROVISIONER=none
./box enter
[[ -f .boxkit/state/initialized ]]
grep -q 'create --name' "$BOX_TEST_LOG"
grep -q -- '--userns=keep-id' "$BOX_TEST_LOG"
grep -q -- '--mount type=bind,src=' "$BOX_TEST_LOG"
grep -q ' /bin/bash /workspace/box _init' "$BOX_TEST_LOG"
count="$(grep -c ' /bin/bash /workspace/box _init' "$BOX_TEST_LOG")"
./box enter
[[ "$(grep -c ' /bin/bash /workspace/box _init' "$BOX_TEST_LOG")" == "$count" ]]
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
