# Configuration

## Configuration

```ini
[container]
# Unique Podman container name.
name = example-dev
# Container engine (only podman is supported).
engine = podman
# OCI image used to create the container.
image = docker.io/library/archlinux:latest
# Persistent container HOME, relative to the project; kept on recreation.
home = .boxkit/home

[integration]
# Forward host SSH agent; permits signing with agent-held credentials.
ssh_agent = true
# Share host Wayland socket for GUI applications.
wayland = true
# Share host D-Bus session (including mako notifications).
dbus_session = true
# Share host PulseAudio/pipewire-pulse socket; may allow microphone capture.
audio = true
# Host browser/xdg-open bridge; disabled unless explicitly enabled.
host_open = false
# Share /dev/dri GPU devices.
gpu = false

[network]
# private = isolated container networking; host = host network; none = disabled.
mode = private
# Publish host-loopback port to container port; repeat if needed.
# publish = 8080:8080

[mounts]
# Host source|container destination|ro-or-rw; repeat if needed.
# Sources: project-relative, ~, $HOME or $XDG_RUNTIME_DIR.
# mount = ./data|/data|rw
# mount = ~/.config/nvim|/home/dev/.config/nvim|ro

[packages]
# Additional packages installed at first initialization/recreation.
# Arch bootstrap already installs libnotify and libpulse clients.
additional = wl-clipboard fd fzf git neovim ripgrep make gcc

[setup]
# Optional shell hook as container user at first initialization; repeatable.
# Each hook runs separately before box_setup.sh.
# hook = echo 'Initial setup'

[engine_args]
# Optional one-token Podman create flags; repeat as --option=value.
# create_arg = --hostname=haskell-dev
# create_arg = --env=EXAMPLE=value
```

The optional `[packages] additional` key accepts whitespace-separated package names. The list is installed by the image's package manager as root at first initialization (and on recreation), together with Boxkit's basic bootstrap dependencies. Package names differ by distribution, so use the names of packages from the selected image; use `box_setup.sh` for more complex installation.

`[setup] hook` may be repeated. Hooks execute as the development user inside the container in their listed order, after optional Mi provisioning and before `box_setup.sh`, on **first initialization per container instance**, not on every entry. Hooks run in separate Bash processes: exporting an environment variable in a hook does not persist into later entries or into another hook. For persistent environment use an image setting or `[engine_args] create_arg = --env=NAME=value` (the standard XDG and SSH-agent variables are already managed by Boxkit). Hooks execute arbitrary shell commands: only use trusted project settings.

`[engine_args] create_arg` may be repeated; each entry is **one Podman create CLI argument**, e.g. `--hostname=haskell-dev`, `--env=FOO=bar`, `--cap-add=NET_ADMIN`. Use `--option=value` syntax for options with values; whitespace-separated CLI fragments are deliberately not parsed, sourced, or evaluated. These are **Podman-specific** escape-hatch flags and may override isolation assumptions; use built-in integration/mount/network keys when available. Changing them requires explicit `./box enter -r`.

`[integration] audio = true` (the default, including legacy INI files without the key) detects the host's `$XDG_RUNTIME_DIR/pulse/native` socket, mounts it in the container, and sets `PULSE_SERVER` for PulseAudio-compatible clients (including `pipewire-pulse`). If unavailable, Boxkit warns and skips the audio integration. Set `audio = false` to disable it. This shares the host audio server, potentially enabling both playback and microphone capture; the mount's read/write flag does not restrict the server's operations. Host notifications (including mako) use the existing `dbus_session = true` option, not an additional notification mount. A changed audio socket requires `./box enter -r`.

Repeated `publish` and `mount` entries are accepted. `network.mode = private` (the default) uses an isolated Podman network and permits `publish` mappings bound to host loopback (127.0.0.1). `network.mode = host` uses `--network host`, sharing the host network namespace (including host loopback and listening ports), so no `publish` mappings are allowed. `network.mode = none` disables the network and also disallows publishes. Host network mode reduces network isolation; select it only for trusted containers. The project's directory is mounted read/write at `/workspace`, and the independent HOME is mounted at `/home/dev`. Source paths are resolved on the host relative to the project; do not mount untrusted host paths. Mount sources support the host environment variables `$HOME`, `${HOME}`, `$XDG_RUNTIME_DIR`, and `${XDG_RUNTIME_DIR}` (and the existing `~` syntax). Only these names are expanded; no shell commands or arbitrary variables are evaluated. If `XDG_RUNTIME_DIR` is referenced but unset or empty, Boxkit fails with an explicit error. Changing mounts requires `./box enter -r`. Settings are parsed as data and never sourced as shell.

The default image is Arch Linux (`docker.io/library/archlinux:latest`). The first entry installs basic development prerequisites (bash, git, curl, SSH client, certificate bundle, and sudo) using the image's package manager. Arch, Debian/Ubuntu, Alpine and Fedora-like package managers are supported; unsupported images need a supported package manager or customized preparation. `./box enter` requires network access for initial packages and Mi unless packages are already cached.


On Arch Linux, the baseline bootstrap installs `libnotify` (`notify-send`) and `libpulse` (`pactl` / `paplay`) whether or not their host integrations are enabled. The host services themselves (mako and PipeWire/PulseAudio) are not installed in the container. Event sound themes and `canberra-gtk-play` remain optional. Other distributions retain the existing bootstrap behavior.
