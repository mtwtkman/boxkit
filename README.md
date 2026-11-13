# Boxkit

A small, single-file Bash development-container manager backed by **rootless Podman**. Boxkit invokes the container engine CLI directly and does not require Distrobox. `engine = podman` is explicitly written into the configuration; additional engines may be implemented later.

## Quick start

Download the script to a local file (the generator self-copies, so **`curl | bash` is not supported**):

```sh
curl -fsSL https://raw.githubusercontent.com/mtwtkman/boxkit/main/boxkit -o /tmp/boxkit
bash /tmp/boxkit init
./box enter
```

`boxkit init` writes **only `boxkit.ini` and `./box`**. It also creates the private state and HOME directories. It does not generate a Containerfile, install Podman, or overwrite existing files. The executable `./box` is a copy of the same script (no nested generated heredoc, compilation, or runtime download). Podman is required when running the container, not for scaffolding.

## CLI

| Command | Behavior |
| --- | --- |
| `./box enter` or `./box e` | Create/start and enter container; initialize once per instance |
| `./box enter -r` | Explicitly recreate; preserves independent HOME |
| `./box exec COMMAND...` | Run a command inside a running container |
| `./box stop` | Stop container |
| `./box rm` | Remove container (does not delete HOME) |
| `./box list` | List Boxkit-managed containers |

Do not invoke `./box init` to provision an existing container. Provisioning runs automatically on first enter.

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

Repeated `publish` and `mount` entries are accepted. Network publishes are bound to host loopback (127.0.0.1). `network.mode = none` disables the network and disallows publishes. The project's directory is mounted read/write at `/workspace`, and the independent HOME is mounted at `/home/dev`. Source paths are resolved on the host relative to the project; do not mount untrusted host paths. Settings are parsed as data and never sourced as shell.

The default image is Arch Linux (`docker.io/library/archlinux:latest`). The first entry installs basic development prerequisites (bash, git, curl, SSH client, certificate bundle, and sudo) using the image's package manager. Arch, Debian/Ubuntu, Alpine and Fedora-like package managers are supported; unsupported images need a supported package manager or customized preparation. `./box enter` requires network access for initial packages and Mi unless packages are already cached.

## Sudo inside rootless containers

On initial provisioning, Boxkit installs `sudo` and configures passwordless sudo **only for the mapped development user**. For example, `sudo pacman -Syu gh` works from an ordinary `./box enter` session. The `box_setup.sh` hook continues to run as the development user; use `sudo` there when root privileges are needed.

Rootless Podman remains enabled (`--userns=keep-id`): container root is not host root. However, sudo requires setuid transitions, so Boxkit does **not** set `no-new-privileges` for newly created containers. This slightly weakens containment against privilege escalation *within the container*; do not run untrusted code or mount sensitive host resources writable. The passwordless rule is container-local, and the normal host user does not acquire host sudo rights.

An existing initialized container is not re-provisioned by updating `./box` alone. To enable sudo, recreate with `./box enter -r` after backing up any changes stored exclusively in the container writable layer. The project HOME is preserved.

## Host session D-Bus for Podman

Rootless Podman/crun may contact the host's systemd user manager while starting a container. An inherited stale `DBUS_SESSION_BUS_ADDRESS` (for example a temporary `/tmp/dbus-...` address) may cause `crun: sd-bus call: Process org.freedesktop.systemd1 exited with status 1`. Boxkit now normalizes **the host-side environment of its own process and Podman descendants** to `unix:path=$XDG_RUNTIME_DIR/bus` when that Unix socket exists. It does not alter the parent shell environment or require changes to the generated `./box` script by hand.

This fix is separate from `dbus_session = true`, which controls access to the host session bus **inside** a container. If `$XDG_RUNTIME_DIR/bus` is missing, Boxkit leaves the inherited address unchanged; inspect `systemctl --user is-system-running`, `XDG_RUNTIME_DIR` and the session bus state if Podman still fails.

## Terminal colors and host shell appearance

On every `./box enter` and `./box exec`, Boxkit forwards the host's
`TERM`, `COLORTERM`, `NO_COLOR`, `CLICOLOR`, `CLICOLOR_FORCE`, and
`LS_COLORS` if set. This preserves terminal color capabilities and common
color preferences when entering from foot/tmux or another terminal. These
settings are passed at execution time rather than baked into the container,
so changing tmux sessions does **not** require `./box enter -r`.

The container must provide the terminfo definition named by `TERM` (for
example, `infocmp tmux-256color`). Application-specific settings such as
`FZF_DEFAULT_OPTS`, Neovim themes and the prompt remain under the
container's shell/configuration management. `NO_COLOR=1` is forwarded
intentionally: some applications disable color when it is set.

## Host integration

- **SSH agent**: `SSH_AUTH_SOCK` is detected on the host, or override with `BOX_SSH_AGENT_SOCKET`. No private SSH key directories are mounted. Processes inside the container can request signatures from the agent, so only use this with trusted projects.
- **Wayland**: requires an available host `WAYLAND_DISPLAY` socket; basic clipboard operations use Wayland. D-Bus and X11 are not automatically shared. Set `wayland = false` for headless sessions. Wayland grants the GUI program compositor-provided privileges.
- **Session D-Bus**: `dbus_session = true` (default for newly initialized projects) detects the host session bus at `$XDG_RUNTIME_DIR/bus`, preferring a valid explicit `unix:path=` address, and bind-mounts it as `/home/dev/.boxkit-runtime/bus`. The container receives `DBUS_SESSION_BUS_ADDRESS=unix:path=/home/dev/.boxkit-runtime/bus`, independent of host paths, and `XDG_RUNTIME_DIR=/home/dev/.boxkit-runtime`. If no session bus is available, boxkit warns and leaves the integration disabled. This grants container processes access to the host user session bus, including any services reachable through it. **Set `dbus_session = false` for untrusted projects or when session bus access is unnecessary.** Existing `boxkit.ini` files without this setting use the same default, so explicitly disable it if required.
- **GPU**: optional `gpu = true` adds `/dev/dri` and keeps supplementary groups. The container still needs suitable userspace drivers.
- **Volumes**: explicit read-only/read-write bind mounts. GPU and GUI are independent options.
- **Port publishing**: `publish = host-port:container-port`, exposed only via host loopback.

Boxkit records a fingerprint including the configuration and SSH-agent, Wayland, and D-Bus socket inode identities. If the agent, Wayland or D-Bus socket is replaced, `enter` refuses the old mount and tells you to run `./box enter -r`. Recreating a running container is never automatic. A missing SSH agent or D-Bus session socket is allowed with a warning, but changing its availability requires explicit recreation. This is particularly relevant after a host logout/login or session bus restart.


## OCI-independent host browser bridge

The optional `[integration] host_open = true` mounts a dedicated Unix-socket
directory into the container. It does **not** expose Podman control or host
shell execution. Absolute HTTP(S) URLs and local `file://` URIs are accepted. It works with
`dbus_session = false`, because the host listener runs in the host session.

Install the host listener and user service on the Linux host:

```sh
install -Dm755 host/boxkit-open-server ~/.local/bin/boxkit-open-server
install -Dm644 host/boxkit-open.service ~/.config/systemd/user/boxkit-open.service
systemctl --user daemon-reload
systemctl --user enable --now boxkit-open.service
```

Set `host_open = true` under `[integration]` in `boxkit.ini`.
Copy `localbin/xdg-open` into the container's PATH (for example, through
Mi's managed localbin), then recreate the container using `./box enter -r`.
The container needs Python 3, installed by the standard Boxkit bootstrap.
Try `xdg-open https://example.com` or `xdg-open file:///workspace/README.md` from inside the container.

The socket lives at `$XDG_RUNTIME_DIR/boxkit-open/xdg-open.sock` on the
host and `/home/dev/.boxkit-runtime/open/xdg-open.sock` in the container.
The directory is mounted rather than the socket inode, so service restarts
do not require container recreation. File URIs under `/workspace` and `/home/dev` are translated to the
corresponding host paths. The host listener independently resolves symlinks
and only opens files under the host user's HOME by default. If the project
resides outside HOME, explicitly add its host root to the **host-controlled**
`BOXKIT_OPEN_FILE_ROOTS` environment variable in the systemd user service
override, then restart the service. Do not use a broad root such as `/`.
A compromised container with this integration enabled can request arbitrary
HTTP(S) URLs and approved local files in the host browser. Custom URI
schemes and file paths outside these roots are intentionally unsupported.

The host listener inherits its user service environment and attempts to
recover the active sway/Firefox session D-Bus address from host processes.
If the session uses a different browser, set `BROWSER` and optionally
`DESKTOPAPP` in the user service environment.

## Initial provisioning

On first entry, Boxkit prompts for Mi; specify `BOX_PROVISIONER=mi` or `BOX_PROVISIONER=none` in noninteractive use. Mi uses `MI_PROFILE=container`. A trusted, project-local `box_setup.sh` runs inside the container, after Mi, as a Bash subprocess from `/workspace`. It does not have to be executable. Set `MI_REPO_PATH` to a checkout path **visible inside the container**, e.g. `/workspace/mi`. `BOX_MI_SETUP_URL` can override the setup script URL.

Successful setup is tracked by the actual container ID in `.boxkit/state/initialized`. Failed setup is retried on the next entry. Container recreation reruns setup; write idempotent setup scripts. HOME survives recreation, but changes made only in the container's writable layer do not.

## Migrating from Distrobox

**No in-place migration is performed.** Existing `distrobox.ini`, `.distrobox/home` and Distrobox containers remain untouched.

1. Back up your old HOME and check which configuration and files you want to preserve.
2. Create a new `boxkit.ini` and `./box` using `boxkit init` in a clean project directory, or carefully copy the generated files into the existing project.
3. If migrating the old HOME, copy files into `.boxkit/home` while the old container is stopped; review ownership and SSH/secret files.
4. Confirm Wayland, Git, agent forwarding and project setup with `BOX_PROVISIONER=none ./box enter` first.
5. Delete the old Distrobox container yourself only after verifying the new one.

Do not reuse the same container name with a different engine without reviewing conflicts. Container changes requiring recreation use `./box enter -r`, which preserves `.boxkit/home`.

## Testing

```sh
bash -n boxkit
bash tests/boxkit.sh
```

The Bash tests use a Podman CLI mock. Real rootless Podman, GUI, socket renewal, GPU device access and networking require separate host integration testing.

## Updating existing projects

A project created with an older `./box` keeps its old embedded code. To apply this update, stop the container, back up the existing `./box`, and replace it with the latest `boxkit` script, then change the `image` field in `boxkit.ini` if you want Arch Linux. The default image only applies to newly generated INI files. Configuration or socket mount changes require `./box enter -r` to recreate the container; this preserves `.boxkit/home` but not image-layer changes. If you require host D-Bus, set `dbus_session = true` under `[integration]`; to keep isolation, set it to `false`.
