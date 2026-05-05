# Docker AppImage Runtime

This runtime is for local development on hosts where installing desktop
dependencies directly is undesirable.

Build the local AppImage first:

```bash
docker run --rm -v "$PWD:/work" -w /work archlinux:latest \
  bash -lc 'pacman -Syu --noconfirm base-devel nodejs npm python p7zip wget icoutils imagemagick file git && ./build.sh --build appimage --clean no'
```

Install the host launcher and desktop entry:

```bash
scripts/docker/install-local-launcher.sh
```

Then launch through Docker:

```bash
claude-desktop
claude-desktop --doctor
```

The wrapper uses X11 (`DISPLAY` + `/tmp/.X11-unix`) and
`APPIMAGE_EXTRACT_AND_RUN=1`, so the AppImage does not require FUSE inside
the container. It also watches the X11 window list and stops the AppImage
process after the Claude window is closed, allowing Docker to remove the
container. Runtime state is stored under:

- `~/.local/share/claude-desktop-docker/home`
- `~/.cache/claude-desktop-docker`
