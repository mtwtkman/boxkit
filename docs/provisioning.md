# Provisioning and sudo

## Initial provisioning

On first entry, Boxkit prompts for Mi; specify `BOX_PROVISIONER=mi` or `BOX_PROVISIONER=none` in noninteractive use. Mi uses `MI_PROFILE=container`. A trusted, project-local `box_setup.sh` runs inside the container, after Mi, as a Bash subprocess from `/workspace`. It does not have to be executable. Set `MI_REPO_PATH` to a checkout path **visible inside the container**, e.g. `/workspace/mi`. `BOX_MI_SETUP_URL` can override the setup script URL.

Successful setup is tracked by the actual container ID in `.boxkit/state/initialized`. Failed setup is retried on the next entry. Container recreation reruns setup; write idempotent setup scripts. HOME survives recreation, but changes made only in the container's writable layer do not.

## Sudo inside rootless containers

On initial provisioning, Boxkit installs `sudo` and configures passwordless sudo **only for the mapped development user**. For example, `sudo pacman -Syu gh` works from an ordinary `./box enter` session. The `box_setup.sh` hook continues to run as the development user; use `sudo` there when root privileges are needed.

Rootless Podman remains enabled (`--userns=keep-id`): container root is not host root. However, sudo requires setuid transitions, so Boxkit does **not** set `no-new-privileges` for newly created containers. This slightly weakens containment against privilege escalation *within the container*; do not run untrusted code or mount sensitive host resources writable. The passwordless rule is container-local, and the normal host user does not acquire host sudo rights.

An existing initialized container is not re-provisioned by updating `./box` alone. To enable sudo, recreate with `./box enter -r` after backing up any changes stored exclusively in the container writable layer. The project HOME is preserved.
