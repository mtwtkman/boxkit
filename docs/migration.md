# Migrating from Distrobox

## Migrating from Distrobox

**No in-place migration is performed.** Existing `distrobox.ini`, `.distrobox/home` and Distrobox containers remain untouched.

1. Back up your old HOME and check which configuration and files you want to preserve.
2. Create a new `boxkit.ini` and `./box` using `boxkit init` in a clean project directory, or carefully copy the generated files into the existing project.
3. If migrating the old HOME, copy files into `.boxkit/home` while the old container is stopped; review ownership and SSH/secret files.
4. Confirm Wayland, Git, agent forwarding and project setup with `BOX_PROVISIONER=none ./box enter` first.
5. Delete the old Distrobox container yourself only after verifying the new one.

Do not reuse the same container name with a different engine without reviewing conflicts. Container changes requiring recreation use `./box enter -r`, which preserves `.boxkit/home`.
