# Host URL and file opener

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
