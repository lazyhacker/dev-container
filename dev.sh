#!/bin/bash

# --- Configuration ---
# Sanitize directory name for a valid container name
DIR_NAME=$(basename "$(pwd)" | tr '[:upper:]' '[:lower:]' | tr -cd '[:alnum:]-')
CONTAINER_NAME="dev-${DIR_NAME}"

# Make the image name specific to this directory
IMAGE_NAME="fedora-dev-${DIR_NAME}"
CONTAINERFILE=""
USE_CACHE=false

# --- Functions ---

check_dependencies() {
    if ! command -v podman &> /dev/null; then
        echo "Error: podman is not installed. sudo dnf install podman"
        exit 1
    fi
}

show_help() {
    echo "Usage: $(basename "$0") [OPTION]"
    echo "  -r, --rebuild        Wipe project container and rebuild shared image."
    echo "  -f, --file <path>    Use an alternative Containerfile for the build."
    echo "  -s, --stop           Stop THIS project's container."
    echo "  -w, --wipe           Tear down THIS project's container."
    echo "  -l, --list           List all active dev environments."
    echo "  -c, --cache          Use project-specific persistent go-cache."
    exit 0
}

list_envs() {
    echo "Active Dev Environments:"
    podman ps -a --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" | grep "dev-"
    exit 0
}

rebuild_all() {
    echo "--- Initiating Rebuild for: ${IMAGE_NAME} ---"
    
    # 1. Stop and remove the existing container to unlock the image
    podman rm -f "${CONTAINER_NAME}" 2>/dev/null

    # 2. Prepare the build arguments array
    # This prevents shell quoting issues and makes adding optional flags cleaner
    BUILD_ARGS=(
        "--squash"
        "--build-arg" "USER_NAME=${USER}"
        "--build-arg" "USER_UID=$(id -u)"
        "--build-arg" "USER_GID=$(id -g)"
        "--build-arg" "CACHEBUST=$(date +%s)"
        "-t" "${IMAGE_NAME}"
    )

    # 3. Check if a specific Containerfile was provided via the -f flag
    if [ -n "$CONTAINERFILE" ]; then
        if [ -f "$CONTAINERFILE" ]; then
            BUILD_ARGS+=("-f" "$CONTAINERFILE")
            echo "Using custom Containerfile: $CONTAINERFILE"
        else
            echo "Error: Containerfile '$CONTAINERFILE' not found."
            exit 1
        fi
    fi

    # 4. Execute the build
    # We pass the BUILD_ARGS array and set the context to the current directory (.)
    podman build "${BUILD_ARGS[@]}" .

    # 5. Cleanup
    # Prunes only dangling images to keep your storage tidy
    podman image prune -f
    
    echo "--- Rebuild of ${IMAGE_NAME} Complete ---"
}

# --- Parsing ---
check_dependencies

while [[ "$#" -gt 0 ]]; do
    case "$1" in
        -r|--rebuild) REBUILD=true ;;
        -f|--file)    shift; CONTAINERFILE="$1" ;;
        -s|--stop)    podman stop "${CONTAINER_NAME}" 2>/dev/null; exit 0 ;;
        -w|--wipe)    podman rm -f "${CONTAINER_NAME}" 2>/dev/null; podman image prune -f; exit 0 ;;
        -l|--list)    list_envs ;;
        -c|--cache)   USE_CACHE=true ;;
        -h|--help)    show_help ;;
        *) echo "Unknown option: $1"; show_help ;;
    esac
    shift
done

if [ "$REBUILD" = true ]; then
    rebuild_all
fi

# --- Lifecycle ---

# Check if project container exists
if [ -n "$(podman ps -aq -f name=${CONTAINER_NAME})" ]; then
    if [ -z "$(podman ps -q -f name=${CONTAINER_NAME})" ]; then
        echo "Starting ${CONTAINER_NAME}..."
        podman start "${CONTAINER_NAME}"
    fi
else
    # New Project Setup
    echo "Setting up new environment for: ${DIR_NAME}"

    echo -n "Host port to map to [Default 9001]: "
    read -r PORT_IN
    HOST_PORT="${PORT_IN:-9001}"

    CACHE_MAPPING=""
    if [ "$USE_CACHE" = true ]; then
        CACHE_MAPPING="-v go-cache-${DIR_NAME}:/home/${USER}/go:Z"
    fi

    podman run -d \
        --name "${CONTAINER_NAME}" \
        --userns=keep-id \
        -v "$(pwd):/home/${USER}/project:Z" \
        ${CACHE_MAPPING} \
        -p "${HOST_PORT}:9001" \
        "${IMAGE_NAME}" sleep infinity
fi

# --- Tmux Entry ---
podman exec -it -u "${USER}" "${CONTAINER_NAME}" /bin/bash -c "
    tmux has-session -t dev 2>/dev/null || tmux -u new-session -d -s dev
    tmux -u attach-session -t dev
"
