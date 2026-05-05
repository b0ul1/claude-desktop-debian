#!/usr/bin/env bash

set -u

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "$script_dir/../.." && pwd)"
bin_dir="${HOME}/.local/bin"
apps_dir="${XDG_DATA_HOME:-$HOME/.local/share}/applications"
icon_dir="${XDG_DATA_HOME:-$HOME/.local/share}/icons/hicolor/256x256/apps"
wrapper_path="$bin_dir/claude-desktop"
desktop_path="$apps_dir/claude-desktop-docker.desktop"
icon_path="$icon_dir/claude-desktop.png"

mkdir -p "$bin_dir" "$apps_dir" "$icon_dir" || exit 1

cat > "$wrapper_path" << EOF
#!/usr/bin/env bash
exec "$repo_root/scripts/docker/run-appimage.sh" "\$@"
EOF
chmod +x "$wrapper_path" || exit 1

if [[ -f "$repo_root/build/claude_6_256x256x32.png" ]]; then
	cp "$repo_root/build/claude_6_256x256x32.png" "$icon_path" || exit 1
fi

cat > "$desktop_path" << EOF
[Desktop Entry]
Name=Claude Desktop (Docker)
Comment=Claude Desktop AppImage launched in Docker
Exec=$wrapper_path %u
Icon=claude-desktop
Type=Application
Terminal=false
Categories=Network;Utility;
MimeType=x-scheme-handler/claude;
StartupWMClass=Claude
EOF

if command -v update-desktop-database >/dev/null 2>&1; then
	update-desktop-database "$apps_dir" >/dev/null 2>&1 || true
fi

echo "Installed launcher: $wrapper_path"
echo "Installed desktop entry: $desktop_path"
[[ -f $icon_path ]] && echo "Installed icon: $icon_path"
