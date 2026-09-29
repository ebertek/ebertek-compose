#!/usr/bin/env bash

set -euo pipefail

readonly BIN_DIR="/volume1/homes/Hannibal/bin"
readonly YT_DLP="${BIN_DIR}/yt-dlp"
readonly DENO="${BIN_DIR}/deno"

readonly TMM_DATA_DIR="/volume2/docker/tmm/data"
readonly TMM_ADDONS_DIR="${TMM_DATA_DIR}/addons"
readonly TMM_YT_DLP="${TMM_ADDONS_DIR}/yt-dlp"

tmp_dir=""

log() {
	printf '[%s] %s\n' "$(date '+%Y-%m-%dT%H:%M:%S%z')" "$*"
}

error() {
	printf '[%s] ERROR: %s\n' "$(date '+%Y-%m-%dT%H:%M:%S%z')" "$*" >&2
}

cleanup() {
	if [[ -n "$tmp_dir" ]]; then
		rm -rf "$tmp_dir"
	fi
}

trap cleanup EXIT

command -v curl >/dev/null 2>&1 || {
	error "curl is not installed"
	exit 1
}

if command -v unzip >/dev/null 2>&1; then
	readonly EXTRACTOR="unzip"
elif command -v 7z >/dev/null 2>&1; then
	readonly EXTRACTOR="7z"
else
	error "Neither unzip nor 7z is available"
	exit 1
fi

case "$(uname -m)" in
x86_64 | amd64)
	deno_arch="x86_64"
	;;
aarch64 | arm64)
	deno_arch="aarch64"
	;;
*)
	error "Unsupported architecture: $(uname -m)"
	exit 1
	;;
esac

mkdir -p "$BIN_DIR"

log "Updating yt-dlp"

curl \
	--fail \
	--silent \
	--show-error \
	--location \
	"https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp" \
	--output "$YT_DLP"

chmod 0755 "$YT_DLP"

log "yt-dlp version: $("$YT_DLP" --version)"

if [[ ! -d "$TMM_DATA_DIR" ]]; then
	error "TinyMediaManager data directory not found: $TMM_DATA_DIR"
	exit 1
fi

mkdir -p "$TMM_ADDONS_DIR"

cp "$YT_DLP" "$TMM_YT_DLP"
chown docker:users "$TMM_YT_DLP"
chmod 0770 "$TMM_YT_DLP"

log "Updated TinyMediaManager yt-dlp addon"

log "Updating Deno"

tmp_dir=$(mktemp -d)

archive="deno-${deno_arch}-unknown-linux-gnu.zip"

curl \
	--fail \
	--silent \
	--show-error \
	--location \
	"https://github.com/denoland/deno/releases/latest/download/${archive}" \
	--output "${tmp_dir}/${archive}"

log "Extracting Deno archive using $EXTRACTOR"

case "$EXTRACTOR" in
unzip)
	unzip \
		-q \
		"${tmp_dir}/${archive}" \
		-d "$tmp_dir"
	;;
7z)
	7z x \
		-y \
		"${tmp_dir}/${archive}" \
		"-o${tmp_dir}" \
		>/dev/null
	;;
esac

if [[ ! -f "${tmp_dir}/deno" ]]; then
	error "deno binary not found in downloaded archive"
	exit 1
fi

install \
	-m 0755 \
	"${tmp_dir}/deno" \
	"$DENO"

ln -sfn "$YT_DLP" /usr/local/bin/yt-dlp
ln -sfn "$DENO" /usr/local/bin/deno

log "Deno version: $("$DENO" --version | head -n1)"
log "YouTube tools updated successfully"
