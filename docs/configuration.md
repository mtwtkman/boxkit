# Configuration

## Configuration

```ini
[container]
name = example-dev
engine = podman
image = docker.io/library/archlinux:latest
home = .boxkit/home

[integration]
ssh_agent = true
wayland = true
dbus_session = true
host_open = false
gpu = false

[network]
mode = private
# publish = 8080:8080

[mounts]
# mount = ./data|/data|rw
# mount = ~/.config/nvim|/home/dev/.config/nvim|ro
# mount = ${XDG_RUNTIME_DIR}/pulse|/run/host-pulse|ro

[packages]
additional = fd fzf neovim ripgrep make gcc

[setup]
# hook = echo "Initial setup"

[engine_args]
# create_arg = --hostname=haskell-dev
# create_arg = --env=EXAMPLE=value
```

The optional `[packages] additional` key accepts whitespace-separated package names. The list is installed by the image's package manager as root at first initialization (and on recreation), together with Boxkit's basic bootstrap dependencies. Package names differ by distribution, so use the names of packages from the selected image; use `box_setup.sh` for more complex installation.

`[setup] hook` may be repeated. Hooks execute as the development user inside the container in their listed order, after optional Mi provisioning and before `box_setup.sh`, on **first initialization per container instance**, not on every entry. Hooks run in separate Bash processes: exporting an environment variable in a hook does not persist into later entries or into another hook. For persistent environment use an image setting or `[engine_args] create_arg = --env=NAME=value` (the standard XDG and SSH-agent variables are already managed by Boxkit). Hooks execute arbitrary shell commands: only use trusted project settings.

`[engine_args] create_arg` may be repeated; each entry is **one Podman create CLI argument**, e.g. `--hostname=haskell-dev`, `--env=FOO=bar`, `--cap-add=NET_ADMIN`. Use `--option=value` syntax for options with values; whitespace-separated CLI fragments are deliberately not parsed, sourced, or evaluated. These are **Podman-specific** escape-hatch flags and may override isolation assumptions; use built-in integration/mount/network keys when available. Changing them requires explicit `./box enter -r`.

Repeated `publish` and `mount` entries are accepted. Network publishes are bound to host loopback (127.0.0.1). `network.mode = none` disables the network and disallows publishes. The project's directory is mounted read/write at `/workspace`, and the independent HOME is mounted at `/home/dev`. Source paths are resolved on the host relative to the project; do not mount untrusted host paths. Mount sources support the host environment variables `$HOME`, `${HOME}`, `$XDG_RUNTIME_DIR`, and `${XDG_RUNTIME_DIR}` (and the existing `~` syntax). Only these names are expanded; no shell commands or arbitrary variables are evaluated. If `XDG_RUNTIME_DIR` is referenced but unset or empty, Boxkit fails with an explicit error. Changing mounts requires `./box enter -r`. Settings are parsed as data and never sourced as shell.

The default image is Arch Linux (`docker.io/library/archlinux:latest`). The first entry installs basic development prerequisites (bash, git, curl, SSH client, certificate bundle, and sudo) using the image's package manager. Arch, Debian/Ubuntu, Alpine and Fedora-like package managers are supported; unsupported images need a supported package manager or customized preparation. `./box enter` requires network access for initial packages and Mi unless packages are already cached.
