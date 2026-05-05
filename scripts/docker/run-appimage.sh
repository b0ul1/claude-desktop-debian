#!/usr/bin/env bash

set -u

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "$script_dir/../.." && pwd)"
image_name="${CLAUDE_DESKTOP_DOCKER_IMAGE:-claude-desktop-appimage-runtime:local}"
container_name="${CLAUDE_DESKTOP_DOCKER_CONTAINER:-claude-desktop}"
container_home="${XDG_DATA_HOME:-$HOME/.local/share}/claude-desktop-docker/home"
container_cache="${XDG_CACHE_HOME:-$HOME/.cache}/claude-desktop-docker"

find_appimage() {
	find "$repo_root" -maxdepth 2 -type f \
		-name 'claude-desktop-*.AppImage' \
		! -name '*.zsync' \
		-printf '%T@ %p\n' \
		| sort -nr \
		| awk 'NR == 1 { sub(/^[^ ]+ /, ""); print }'
}

ensure_image() {
	if docker image inspect "$image_name" >/dev/null 2>&1; then
		return 0
	fi

	docker build \
		-t "$image_name" \
		-f "$repo_root/docker/appimage-runtime.Dockerfile" \
		"$repo_root"
}

cleanup_existing_containers() {
	local line id name

	# Remove older unnamed containers from previous wrapper versions.
	while IFS= read -r line; do
		[[ -n $line ]] || continue
		id="${line%% *}"
		name="${line#* }"
		[[ $name == "$container_name" ]] && continue
		docker stop "$id" >/dev/null 2>&1 || true
	done < <(
		docker ps --filter "ancestor=$image_name" \
			--format '{{.ID}} {{.Names}}' 2>/dev/null || true
	)

	if docker ps -a --format '{{.Names}}' \
		| grep -Fxq "$container_name"; then
		docker stop "$container_name" >/dev/null 2>&1 || true
		docker rm "$container_name" >/dev/null 2>&1 || true
	fi
}

appimage_path="$(find_appimage)"
if [[ -z $appimage_path ]]; then
	echo 'No claude-desktop AppImage found in the repository.' >&2
	echo 'Build one first with:' >&2
	echo "  docker run --rm -v '$repo_root:/work' -w /work archlinux:latest bash -lc 'pacman -Syu --noconfirm base-devel nodejs npm python p7zip wget icoutils imagemagick file git && ./build.sh --build appimage --clean no'" >&2
	exit 1
fi

if [[ -z ${DISPLAY:-} ]]; then
	echo 'DISPLAY is not set; cannot open the graphical interface.' >&2
	exit 1
fi

ensure_image || exit 1
mkdir -p "$container_home" "$container_cache" || exit 1
cleanup_existing_containers

docker_args=(
	run
	--rm
	--name "$container_name"
	--hostname claude-desktop-docker
	--ipc host
	--user "$(id -u):$(id -g)"
	-e "DISPLAY=$DISPLAY"
	-e "HOME=/home/claude"
	-e "XDG_CACHE_HOME=/home/claude/.cache"
	-e "XDG_CONFIG_HOME=/home/claude/.config"
	-e "XDG_DATA_HOME=/home/claude/.local/share"
	-e "XDG_RUNTIME_DIR=/tmp/runtime-claude"
	-e APPIMAGE_EXTRACT_AND_RUN=1
	-e CLAUDE_USE_WAYLAND=0
	-e GDK_DISABLE_SHM=1
	-e QT_X11_NO_MITSHM=1
	-v /tmp/.X11-unix:/tmp/.X11-unix:rw
	-v "$container_home:/home/claude"
	-v "$container_cache:/home/claude/.cache"
	-v "$repo_root:/work:ro"
	-v "$appimage_path:/opt/claude-desktop.AppImage:ro"
	--workdir /home/claude
)

if [[ -n ${XAUTHORITY:-} && -f $XAUTHORITY ]]; then
	docker_args+=(
		-e XAUTHORITY=/tmp/.docker.xauth
		-v "$XAUTHORITY:/tmp/.docker.xauth:ro"
	)
fi

if [[ -e /dev/dri ]]; then
	docker_args+=(--device /dev/dri)
fi

exec docker "${docker_args[@]}" "$image_name" \
	bash -lc 'mkdir -p "$XDG_RUNTIME_DIR" && chmod 700 "$XDG_RUNTIME_DIR" && exec /opt/claude-desktop.AppImage "$@"' \
	claude-desktop "$@"
