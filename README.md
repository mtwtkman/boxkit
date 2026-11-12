# Boxkit
```
boxkit is a helper tool for building development environment by using distrobox.

USAGE:
	[OPTIONS] ./boxkit

OPTIONS:
	DISTROBOX_CONTAINER_NAME
		A name of your development container created by distrobox.
		If it wan't set then boxkit prompt will ask you it.

	BOX_ENTRYPOINT_NAME
		The entrypoint of result objects created by boxkit.
		This value is regarded as relative path under from a project root.
		default: <Project root path>

	DISTROBOX_HOME_NAME
		A name of custom home directory name for your development container.
		default: ${BOX_ENTRYPOINT_NAME}/.distrobox/home

	BOX_SCRIPT_NAME
		The script name of the thin wrapper for distrobox.
		default: ${BOX_ENTRYPOINT_NAME}/box

	DISTROBOX_IMAGE_NAME
		What image for creating your development container image.
		default: Up to your distrobox config

```

# Quick start
1. Run `curl https://raw.githubusercontent.com/mtwtkman/boxkit/main/boxkit | bash -s`
1. Run `./box e`
1. On first `./box e`, confirm whether to provision Mi; initialization then runs automatically before the interactive shell starts.
1. On subsequent `./box e` runs, initialization is skipped.

## Distrobox and Mi integration

Boxkit creates a project-local container HOME. It does not automatically link
host SSH credentials or Git/Neovim configuration into that HOME.

Mi provisioning is optional. On first `./box enter`, Boxkit prompts whether to use Mi. Answer `y` to provision Mi or `N` to skip. To avoid the prompt in automation, specify the choice explicitly:

```bash
BOX_PROVISIONER=mi ./box enter
# or
BOX_PROVISIONER=none ./box enter
```

This downloads the Mi setup script and runs it with `MI_PROFILE=container`,
deploying Git and OpenCode configuration by default. It requires `curl` and
`git` in the container, and a Mi version that supports container setup.

For an existing local checkout accessible at the same path inside the container instead of downloading the setup script:

```bash
BOX_PROVISIONER=mi MI_REPO_PATH=/path/to/mi ./box enter
```

To review and pin a particular setup script, set `BOX_MI_SETUP_URL` to a
trusted immutable URL. Do not point it at an unreviewed script. With no `BOX_PROVISIONER`, the first interactive enter asks for confirmation.
A successful initialization records the container instance ID in `.distrobox/initialized` in the project directory; later entries skip it only while the container ID matches. Recreating or externally replacing the container triggers initialization again. Failed initialization leaves it unmarked so the next enter retries. The old `./box init` command is no longer supported. Existing installations created with an older Boxkit version do not have the marker and will initialize once when migrated.
Install `fzf` and `ripgrep` using the container package manager; they are
also listed in the generated manifest.

**Safety:** Re-running the Boxkit generator refuses to overwrite existing
manifest/wrapper files. The container HOME is not removed by the generator or
container recreation. Only a trusted project-local `box_setup.sh` is executed;
there is no remote post-hook execution. Distrobox is host-integrated, not
a strict security sandbox. Review mounts and credentials separately.

Run regression tests with `bash tests/boxkit.sh`.

## Project-local initialization: `box_setup.sh`

Place an optional `box_setup.sh` next to the generated `./box` script.
On the first `./box enter` for a container instance, Boxkit initializes Mi
(if selected), generates the container shell configuration, and then runs
`bash ./box_setup.sh` **inside the container** with the script's directory
as the working directory. The script does not need to be executable.

```bash
# ./box_setup.sh
#!/usr/bin/env bash
set -euo pipefail
echo "Setting up this project"
```

If the file is absent, setup is skipped. If it fails, initialization is not
marked complete; the next `./box enter` retries the initialization, including
the script. It also runs again when the container is recreated or replaced,
but not on ordinary subsequent entries to the same initialized container.
Ensure the script is safe to retry and use only trusted project files.
Boxkit runs it as a subprocess rather than sourcing it, so variables and
functions defined in the script do not persist in the Boxkit shell.

The legacy `BOX_INIT_POST_HOOK` syntax and remote/local command prefixes
have been removed. The single-file `curl | bash` generator and generated
heredoc remain unchanged.

## Optional SSH agent forwarding

Boxkit can expose a host-managed SSH agent to disposable containers without
copying private keys or linking the host `.ssh` directory. This is opt-in.

On the host, start an agent at a **stable absolute socket path** (example):

```bash
mkdir -p "$HOME/.ssh"
eval "$(ssh-agent -a "$HOME/.ssh/boxkit-agent.sock" -s)"
ssh-add "$HOME/.ssh/id_ed25519"
```

By default, `./box enter` detects the host `SSH_AUTH_SOCK` when it creates a container. No explicit Boxkit setting is required. For a dedicated stable socket, set `SSH_AUTH_SOCK` on the host before entering:

```bash
export SSH_AUTH_SOCK="$HOME/.ssh/boxkit-agent.sock"
./box enter
ssh-add -l
```

On first `./box enter`, Boxkit updates the manifest with a bind mount from the host agent socket to
`/run/boxkit-ssh-agent.sock` and sets the container's `SSH_AUTH_SOCK` to
that path. The socket is detected at **container creation time**. When no agent is available, Boxkit warns and proceeds without forwarding. A new container can reuse the same
host agent socket across projects, provided each project's manifest opts in.

**Lifecycle:** If the host agent is restarted and its socket is replaced,
a running container's bind mount can point to the old socket inode. Recreate
the container to refresh the mount. Use a login-session service to maintain
the stable socket path; the example above is for manual setup only. For an existing container without forwarding, recreate it explicitly to apply the updated mount configuration.

**Security:** Processes in a container with socket access can request SSH
signatures using loaded host keys. Agent forwarding does not isolate
authentication authority. Never mount the private key directory. Restrict
forwarding to trusted containers and consider `ssh-add -c` confirmation or
time-limited keys.
