Containerized Local Dev Environment
===================================

This is my bash script to create a container with my development tools for
my projects.  It assumes the source for the project is the directory that this
script is executed so it will mount it to the container, put me inside the
container's tmux session.  `dev.sh` will manage the lifecycle of the
project containers. It handles building the image, starting/stopping containers,
and automatically attaching you to a tmux session.

This allows me to not pollute my host system with different tools and also
isolate the tools in the container to only be able to access the source
directory.

Overview
--------

### Containerfile

The container sets up the following:

-	Base OS: Uses the latest Fedora image.
-	Tooling: Installs git, tmux, vim-enhanced, gcc, and jq.
-	Personalization: Pulls the lazyhacker dotfiles and sets them up automatically.
-	Vim Setup: Configures Vundle and runs a headless PluginInstall so Vim is ready with all plugins on first launch.
-	User Mapping: Dynamically creates a user inside the container that matches your host's UID and GID to prevent permission issues with mounted files.

Containerfile-go

-	Go Language: Installs Go version 1.26.1.

Containerfile-claude

- Claude Code and its dependencies.

Getting Started
---------------

### Prerequisites

-	Podman: Ensure Podman is installed on your host (e.g., sudo dnf install podman).
-	Dotfiles: The Containerfile is currently configured to clone https://github.com/lazyhacker/dotfiles.git. Update this URL in the Containerfile to point to your own repository if desired.

### Setup

1.	Copy Files: Place dev.sh and Containerfile in the root of your Go project directory.
2.	Permissions: Make the script executable: chmod +x dev.sh
3.	Initial Build: To create the base image and your project's container for the first time, you must run:

`./dev.sh --rebuild`

The script will build the container image, prompt you for a host port to map to (defaults to 9001), and drop you into a tmux session.

Development Workflow
--------------------

### Working on Multiple Projects

The system is designed to allow you to jump between different codebases seamlessly:

-	Folder-based Isolation: Each project gets its own container named dev-[folder-name]. You can run ./dev.sh in multiple project folders simultaneously.
-	Persistent Work: Your project directory on the host is mounted to /home/${USER}/project inside the container. Changes are synced instantly.
-	Tmux Persistence: Re-running ./dev.sh re-attaches you to your existing session, keeping your editor state and running processes intact even if you close your terminal.

### Commands & Flags

| Option        | Description                                                                               |
|---------------|-------------------------------------------------------------------------------------------|
| -r, --rebuild | Required for first-time setup. Wipes the project container and rebuilds the shared image. |
| -s, --stop    | Stops the current project's container.                                                    |
| -w, --wipe    | Removes the container and prunes unused image layers.                                     |
| -l, --list    | Shows all active dev- containers currently running.                                       |
| -c, --cache   | Enables a persistent Go cache volume to speed up builds.                                  |

### Ad-hoc Package Installation

If you need a tool (like npm) temporarily without rebuilding your entire environment, use podman exec as root from your host machine:

Example: Installing Node.js for a specific project Replace <folder-name> with your directory name

`podman exec -u root dev-<folder-name> dnf install -y nodejs`

Note: Changes made this way are lost if you --wipe or --rebuild the container. To make them permanent, add them to the Containerfile.

### Troubleshooting

If your dotfiles change or you update the Containerfile, use the --rebuild flag. It uses a CACHEBUST argument to ensure that git clone operations are re-executed rather than relying on cached container layers.
