# Boxkit

A lightweight Bash development-container manager built on rootless Podman. No Distrobox dependency.

## Quick start

```sh
curl -fsSL https://raw.githubusercontent.com/mtwtkman/boxkit/main/boxkit -o /tmp/boxkit
bash /tmp/boxkit init
./box enter
```

## Usage

```text
./box enter          Create, start, or enter a container
./box enter -r       Recreate the container (preserves Boxkit HOME)
./box exec CMD...    Execute a command inside the container
./box stop           Stop the container
./box rm             Remove the container (preserves Boxkit HOME)
./box list           List managed containers
```

## Documentation

- [Getting started and updating projects](docs/getting-started.md)
- [Configuration](docs/configuration.md)
- [Provisioning and sudo](docs/provisioning.md)
- [Host integrations](docs/integrations.md)
- [Host URL and file opener](docs/host-open.md)
- [Migrating from Distrobox](docs/migration.md)
- [Testing](docs/testing.md)
