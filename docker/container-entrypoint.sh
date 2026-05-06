#!/usr/bin/env bash

set -u

appimage_path='/opt/claude-desktop.AppImage'
app_root=''

drop_to_host_user() {
	local uid="${CLAUDE_HOST_UID:-}"
	local gid="${CLAUDE_HOST_GID:-}"

	[[ $(id -u) == 0 && -n $uid && -n $gid ]] || return 0

	if ! getent group "$gid" >/dev/null 2>&1; then
		printf 'claude:x:%s:\n' "$gid" >> /etc/group || return 1
	fi

	if ! getent passwd "$uid" >/dev/null 2>&1; then
		printf 'claude:x:%s:%s:Claude Desktop:%s:/usr/bin/bash\n' \
			"$uid" "$gid" "$HOME" >> /etc/passwd || return 1
	fi

	exec setpriv --reuid "$uid" --regid "$gid" --clear-groups "$0" "$@"
}

drop_to_host_user "$@" || exit 1

mkdir -p "$XDG_RUNTIME_DIR" || exit 1
chmod 700 "$XDG_RUNTIME_DIR" || exit 1

prepare_appimage_root() {
	local extract_parent="$XDG_RUNTIME_DIR/appimage-extract"
	local extracted_root="$extract_parent/squashfs-root"
	local lib_dir

	rm -rf "$extract_parent" || return 1
	mkdir -p "$extract_parent" || return 1
	(
		cd "$extract_parent" || exit 1
		"$appimage_path" --appimage-extract >/dev/null
	) || return 1

	app_root="$extracted_root"
	lib_dir="$app_root/usr/lib/claude-desktop"

	# Use the repo launcher inside Docker so wrapper-only fixes, such as
	# password-store selection, apply without rebuilding the AppImage.
	if [[ -d $lib_dir ]]; then
		[[ -f /work/scripts/launcher-common.sh ]] \
			&& cp /work/scripts/launcher-common.sh "$lib_dir/launcher-common.sh"
		[[ -f /work/scripts/doctor.sh ]] \
			&& cp /work/scripts/doctor.sh "$lib_dir/doctor.sh"
	fi
}

run_app() {
	if command -v dbus-run-session >/dev/null 2>&1; then
		exec dbus-run-session -- "$app_root/AppRun" "$@"
	fi

	exec "$app_root/AppRun" "$@"
}

prepare_appimage_root || exit 1

if [[ ${1:-} == '--doctor' ]]; then
	run_app "$@"
fi

window_exists() {
	local root_props win_class win
	local -a windows=()

	root_props=$(xprop -root _NET_CLIENT_LIST 2>/dev/null) || return 1
	mapfile -t windows < <(grep -oE '0x[0-9a-fA-F]+' <<< "$root_props")
	for win in "${windows[@]}"; do
		win_class=$(xprop -id "$win" WM_CLASS 2>/dev/null) \
			|| continue
		if [[ $win_class == *Claude* || $win_class == *claude* ]]; then
			return 0
		fi
	done

	return 1
}

watch_window_lifecycle() {
	local app_pid="$1"
	local seen_window=false
	local missing_ticks=0

	# Give Electron enough time to create the first BrowserWindow.
	sleep 3

	while kill -0 "$app_pid" 2>/dev/null; do
		if window_exists; then
			seen_window=true
			missing_ticks=0
		elif [[ $seen_window == true ]]; then
			((missing_ticks++))
			if ((missing_ticks >= 3)); then
				echo 'Claude window closed; stopping Docker runtime'
				kill "$app_pid" 2>/dev/null || true
				sleep 2
				kill -KILL "$app_pid" 2>/dev/null || true
				return 0
			fi
		fi
		sleep 1
	done
}

run_app "$@" &
app_pid=$!

watch_window_lifecycle "$app_pid" &
watchdog_pid=$!

wait "$app_pid"
exit_code=$?

kill "$watchdog_pid" 2>/dev/null || true
wait "$watchdog_pid" 2>/dev/null || true

exit "$exit_code"
