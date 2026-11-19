# Getting started

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

## Updating existing projects

A project created with an older `./box` keeps its old embedded code. To apply this update, stop the container, back up the existing `./box`, and replace it with the latest `boxkit` script, then change the `image` field in `boxkit.ini` if you want Arch Linux. The default image only applies to newly generated INI files. Configuration or socket mount changes require `./box enter -r` to recreate the container; this preserves `.boxkit/home` but not image-layer changes. If you require host D-Bus, set `dbus_session = true` under `[integration]`; to keep isolation, set it to `false`.
