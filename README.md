```
boxkit is a helper tool for building development environment by using distrobox.

Usage: DISTROBOX_CONTAINER_NAME=<distrobox container name> [DISTROBOX_HOME_NAME=<distrobox custom home directory >] [BOX_SCRIPT_NAME=<helper script name>] [DISTROBOX_IMAGE_NAME=<distrobox image>] ./boxkit

Required parameter
  DISTROBOX_CONTAINER_NAME

Optional parameters
  DISTROBOX_HOME_NAME  (default: .distrobox/home)
  BOX_SCRIPT_NAME      (default: box)
  DISTROBOX_IMAGE_NAME (default: docker.io/library/archlinux:latest)
```

# Quick start
curl https://raw.githubusercontent.com/mtwtkman/boxkit/main/boxkit | DISTROBOX_CONTAINER_NAME=distrobox_container_name sh -s
