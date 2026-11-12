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
image = docker.io/library/debian:13
home = .boxkit/home

[integration]
ssh_agent = true
wayland = true
gpu = false

[network]
mode = private
# publish = 8080:8080

[mounts]
# mount = ./data|/data|rw
# mount = ~/.config/nvim|/home/dev/.config/nvim|ro
```

Repeated `publish` and `mount` entries are accepted. Network publishes are bound to host loopback (127.0.0.1). `network.mode = none` disables the network and disallows publishes. The project's directory is mounted read/write at `/workspace`, and the independent HOME is mounted at `/home/dev`. Source paths are resolved on the host relative to the project; do not mount untrusted host paths. Settings are parsed as data and never sourced as shell.

The default image is Debian 13. The first entry installs basic development prerequisites (bash, git, curl, SSH client and certificate bundle) using the image's package manager. Arch, Debian/Ubuntu, Alpine and Fedora-like package managers are supported; unsupported images need a supported package manager or customized preparation. `./box enter` requires network access for initial packages and Mi unless packages are already cached.

## Host integration

- **SSH agent**: `SSH_AUTH_SOCK` is detected on the host, or override with `BOX_SSH_AGENT_SOCKET`. No private SSH key directories are mounted. Processes inside the container can request signatures from the agent, so only use this with trusted projects.
- **Wayland**: requires an available host `WAYLAND_DISPLAY` socket; basic clipboard operations use Wayland. D-Bus and X11 are not automatically shared. Set `wayland = false` for headless sessions. Wayland grants the GUI program compositor-provided privileges.
- **GPU**: optional `gpu = true` adds `/dev/dri` and keeps supplementary groups. The container still needs suitable userspace drivers.
- **Volumes**: explicit read-only/read-write bind mounts. GPU and GUI are independent options.
- **Port publishing**: `publish = host-port:container-port`, exposed only via host loopback.

Boxkit records a fingerprint including the configuration and socket inode identities. If the agent or Wayland socket is replaced, `enter` refuses the old mount and tells you to run `./box enter -r`. Recreating a running container is never automatic. A missing SSH agent is allowed with a warning, but changing its availability requires explicit recreation.

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
