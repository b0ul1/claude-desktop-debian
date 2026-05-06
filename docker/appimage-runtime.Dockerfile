FROM archlinux:latest

RUN pacman -Syu --noconfirm \
	alsa-lib \
	at-spi2-core \
	bubblewrap \
	dbus \
	desktop-file-utils \
	fontconfig \
	gtk3 \
	hicolor-icon-theme \
	libdrm \
	libnotify \
	libsecret \
	libx11 \
	libxcb \
	libxcomposite \
	libxdamage \
	libxext \
	libxfixes \
	libxkbcommon \
	libxrandr \
	libxrender \
	libxss \
	libxtst \
	mesa \
	nss \
	xdg-utils \
	xorg-xprop \
	git \
	&& pacman -Scc --noconfirm

ENV ELECTRON_DISABLE_SECURITY_WARNINGS=1
WORKDIR /work
