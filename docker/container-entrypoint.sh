#!/usr/bin/env bash

set -u

appimage_path='/opt/claude-desktop.AppImage'

mkdir -p "$XDG_RUNTIME_DIR" || exit 1
chmod 700 "$XDG_RUNTIME_DIR" || exit 1

if [[ ${1:-} == '--doctor' ]]; then
	exec "$appimage_path" "$@"
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

"$appimage_path" "$@" &
app_pid=$!

watch_window_lifecycle "$app_pid" &
watchdog_pid=$!

wait "$app_pid"
exit_code=$?

kill "$watchdog_pid" 2>/dev/null || true
wait "$watchdog_pid" 2>/dev/null || true

exit "$exit_code"
