# Host integrations

## Host integration

- **SSH agent**: `SSH_AUTH_SOCK` is detected on the host, or override with `BOX_SSH_AGENT_SOCKET`. No private SSH key directories are mounted. Processes inside the container can request signatures from the agent, so only use this with trusted projects.
- **Wayland**: requires an available host `WAYLAND_DISPLAY` socket; basic clipboard operations use Wayland. D-Bus and X11 are not automatically shared. Set `wayland = false` for headless sessions. Wayland grants the GUI program compositor-provided privileges.
- **Session D-Bus**: `dbus_session = true` (default for newly initialized projects) detects the host session bus at `$XDG_RUNTIME_DIR/bus`, preferring a valid explicit `unix:path=` address, and bind-mounts it as `/home/dev/.boxkit-runtime/bus`. The container receives `DBUS_SESSION_BUS_ADDRESS=unix:path=/home/dev/.boxkit-runtime/bus`, independent of host paths, and `XDG_RUNTIME_DIR=/home/dev/.boxkit-runtime`. If no session bus is available, boxkit warns and leaves the integration disabled. This grants container processes access to the host user session bus, including any services reachable through it. **Set `dbus_session = false` for untrusted projects or when session bus access is unnecessary.** Existing `boxkit.ini` files without this setting use the same default, so explicitly disable it if required.
- **GPU**: optional `gpu = true` adds `/dev/dri` and keeps supplementary groups. The container still needs suitable userspace drivers.
- **Volumes**: explicit read-only/read-write bind mounts. GPU and GUI are independent options.
- **Port publishing**: `publish = host-port:container-port`, exposed only via host loopback.

Boxkit records a fingerprint including the configuration and SSH-agent, Wayland, and D-Bus socket inode identities. If the agent, Wayland or D-Bus socket is replaced, `enter` refuses the old mount and tells you to run `./box enter -r`. Recreating a running container is never automatic. A missing SSH agent or D-Bus session socket is allowed with a warning, but changing its availability requires explicit recreation. This is particularly relevant after a host logout/login or session bus restart.

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
