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
echo 'Boxkit regression tests passed'
