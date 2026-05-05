#!/usr/bin/env bats
#
# Tests for AppImage packaging decisions that are hard to exercise without
# a full release artifact.
#

SCRIPT_DIR="$(cd "$(dirname "${BATS_TEST_FILENAME}")" && pwd)"
APPIMAGE_SCRIPT="$SCRIPT_DIR/../scripts/packaging/appimage.sh"

@test "appimage packaging downloads the current appimagetool release" {
	run grep -F \
		'https://github.com/AppImage/appimagetool/releases/download/continuous/' \
		"$APPIMAGE_SCRIPT"
	[[ $status -eq 0 ]]

	run grep -F \
		'https://github.com/AppImage/AppImageKit/releases/download/continuous/' \
		"$APPIMAGE_SCRIPT"
	[[ $status -ne 0 ]]
}

@test "appimage packaging maps Debian arches to AppImage runtime arches" {
	run grep -F "amd64) appimage_arch='x86_64'" "$APPIMAGE_SCRIPT"
	[[ $status -eq 0 ]]

	run grep -F "arm64) appimage_arch='aarch64'" "$APPIMAGE_SCRIPT"
	[[ $status -eq 0 ]]

	run grep -F "export ARCH=\"\$appimage_arch\"" "$APPIMAGE_SCRIPT"
	[[ $status -eq 0 ]]
}

@test "appimage packaging can run appimagetool on FUSE-less builders" {
	run grep -F "APPIMAGE_EXTRACT_AND_RUN=1 \"\$appimagetool_path\"" \
		"$APPIMAGE_SCRIPT"
	[[ $status -eq 0 ]]

	run grep -F "run_appimagetool \"\$appdir_path\" \"\$output_path\"" \
		"$APPIMAGE_SCRIPT"
	[[ $status -eq 0 ]]
}
