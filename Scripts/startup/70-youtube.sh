#!/bin/bash
set -e

BIN_DIR="/var/services/homes/Hannibal/bin"

mkdir -p "$BIN_DIR"

# yt-dlp
curl -L \
	https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp \
	-o "$BIN_DIR/yt-dlp"

chmod 755 "$BIN_DIR/yt-dlp"

cp "$BIN_DIR/yt-dlp" \
	/volume2/docker/tmm/data/addons/yt-dlp

chown docker:users /volume2/docker/tmm/data/addons/yt-dlp
chmod 770 /volume2/docker/tmm/data/addons/yt-dlp

# Deno
curl -L \
	https://github.com/denoland/deno/releases/latest/download/deno-x86_64-unknown-linux-gnu.zip \
	-o "$BIN_DIR/deno.zip"

unzip -o "$BIN_DIR/deno.zip" -d "$BIN_DIR"
rm "$BIN_DIR/deno.zip"

chmod 755 "$BIN_DIR/deno"

# Make Deno globally available
ln -sf "$BIN_DIR/deno" /usr/local/bin/deno
