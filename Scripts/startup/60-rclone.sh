#!/usr/bin/env bash

set -euo pipefail

readonly INSTALL_DIR="/volume1/homes/Hannibal/bin"
readonly RCLONE="${INSTALL_DIR}/rclone"

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

case "$(uname -s)" in
Linux)
	os="linux"
	;;
*)
	error "Unsupported operating system: $(uname -s)"
	exit 1
	;;
esac

case "$(uname -m)" in
x86_64 | amd64)
	arch="amd64"
	;;
aarch64 | arm64)
	arch="arm64"
	;;
*)
	error "Unsupported architecture: $(uname -m)"
	exit 1
	;;
esac

mkdir -p "$INSTALL_DIR"

log "Checking latest rclone version"

latest_version=$(
	curl \
		--fail \
		--silent \
		--show-error \
		"https://downloads.rclone.org/version.txt"
)

installed_version=""

if [[ -x "$RCLONE" ]]; then
	installed_version=$("$RCLONE" version | head -n1)
fi

if [[ "$installed_version" == "$latest_version" ]]; then
	log "$latest_version is already installed"
else
	if [[ -n "$installed_version" ]]; then
		log "Updating rclone from $installed_version to $latest_version"
	else
		log "Installing $latest_version"
	fi

	tmp_dir=$(mktemp -d)

	archive="rclone-current-${os}-${arch}.zip"

	curl \
		--fail \
		--silent \
		--show-error \
		--location \
		"https://downloads.rclone.org/${archive}" \
		--output "${tmp_dir}/${archive}"

	log "Extracting rclone archive using $EXTRACTOR"

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

	binary=$(
		find "$tmp_dir" \
			-type f \
			-name rclone \
			-print \
			-quit
	)

	if [[ -z "$binary" ]]; then
		error "rclone binary not found in downloaded archive"
		exit 1
	fi

	install \
		-m 0755 \
		"$binary" \
		"$RCLONE"

	installed_version=$("$RCLONE" version | head -n1)

	log "$installed_version installed successfully"
fi

ln -sfn "$RCLONE" /usr/local/bin/rclone

log "rclone is available at /usr/local/bin/rclone"
