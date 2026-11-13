# Testing

## Testing

```sh
bash -n boxkit
bash tests/boxkit.sh
```

The Bash tests use a Podman CLI mock. Real rootless Podman, GUI, socket renewal, GPU device access and networking require separate host integration testing.
