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
		default: /home/mtwtkman/work/boxkit

	DISTROBOX_HOME_NAME
		A name of custom home directory name for your development container.
		default: $BOX_ENTRYPOINT_NAME/.distrobox/home

	BOX_SCRIPT_NAME
		The script name of thin wrapper for distrobox.
		default: $BOX_ENTRYPOINT_NAME/box

	DISTROBOX_IMAGE_NAME
		What image for creating your development container image.
		default: Up to your distrobox config
```

# Quick start
curl https://raw.githubusercontent.com/mtwtkman/boxkit/main/boxkit | DISTROBOX_CONTAINER_NAME=distrobox_container_name sh -s
