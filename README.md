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

	BOX_INIT_POST_HOOK
		Colon separated commands after box initialization.
		You can pass any commands like BOX_INIT_POST_HOOK='ls;pwd;'.
		This options' value elements are permitted of combination of '<command>' and '<prefix>:<value>'.
		There are two types <prefix> , 'r' or 'l'. Detail is below.
			- 'r' prefix presents 'remote'. r:<url> retrieve contents using curl from <url> and applies as is as command.
			- 'l' prefix presents 'local'. l:<path> retrieve contents from local file <path> and applies as is as command.
			For instance, BOX_INIT_POST_HOOK='ls;pwd;r:https://something/scaffolding/ghcup;l:../setup-mise' means 'After box initialization, I do 'ls', 'pwd', 'Retrieve commands from https://something/scaffolding/ghcup', 'Retrieve from ./setup-mise'.
		default: Do nothing
```

# Quick start
1. Run `curl https://raw.githubusercontent.com/mtwtkman/boxkit/main/boxkit | bash -s`
1. Run `./box e`
1. Run `./box i`
1. Run `. ~/.bashrc` or Re-enter the conatiner
