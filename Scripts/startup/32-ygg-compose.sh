#!/usr/bin/env bash
#
# Manage all allowed Ygg Docker Compose stacks on Pleiades.
#
# Compose configurations are sourced from Komodo's managed Git checkout.
# Komodo-generated .env files are ignored so that COMPOSE_PROFILES=nfs
# cannot activate NFS-dependent services before the NFS readiness check.
#
# Usage:
#   32-ygg-compose.sh up-core
#   32-ygg-compose.sh stop-core
#   32-ygg-compose.sh up-nfs
#   32-ygg-compose.sh stop-nfs
#   32-ygg-compose.sh list
#   32-ygg-compose.sh list-nfs

set -Eeuo pipefail

readonly BASE_DIR="/volume2/docker/komodo/periphery/repos/ygg-compose"

readonly -a STACKS=(
	"ygg-arr"
	"ygg-birdnet"
	"ygg-core"
	"ygg-download"
	"ygg-gramps"
	"ygg-hass"
	"ygg-home"
	"ygg-immich"
	"ygg-mon"
	"ygg-other"
)

readonly -a NFS_PATHS=(
	"/volume1/Downloads"
	"/volume1/photo"
	"/volume1/video"
)

log() {
	printf '%s\n' "$*"
}

warn() {
	printf 'WARN: %s\n' "$*" >&2
}

die() {
	printf 'ERROR: %s\n' "$*" >&2
	exit 1
}

#
# Prevent Docker Compose from reading Komodo-generated .env files.
#
# Those files are root-owned (0600) and contain COMPOSE_PROFILES=nfs.
# Allowing Compose to read them would:
#
#   1. Fail when this script runs as the docker user.
#   2. Enable NFS-profile services during up-core.
#
# Explicit --profile nfs arguments still work.
#
compose() {
	COMPOSE_DISABLE_ENV_FILE=1 \
		COMPOSE_PROFILES='' \
		docker compose "$@"
}

require_commands() {
	local -a required_commands=(
		"docker"
		"findmnt"
		"grep"
		"python3"
		"stat"
		"timeout"
	)

	local command_name

	for command_name in "${required_commands[@]}"; do
		command -v "${command_name}" >/dev/null 2>&1 ||
			die "required command not found: ${command_name}"
	done
}

#
# Validate the entire checkout before performing any Compose operations.
#
# This prevents a partially completed startup caused by a missing
# repository directory or Compose file.
#
validate_checkout() {
	local stack
	local compose_file

	[[ -d "${BASE_DIR}" ]] ||
		die "Komodo checkout is not available: ${BASE_DIR}"

	for stack in "${STACKS[@]}"; do
		compose_file="${BASE_DIR}/${stack}/compose.yaml"

		[[ -f "${compose_file}" ]] ||
			die "missing compose file: ${compose_file}"

		[[ -r "${compose_file}" ]] ||
			die "compose file is not readable: ${compose_file}"
	done
}

compose_dirs() {
	local stack

	for stack in "${STACKS[@]}"; do
		printf '%s\n' "${BASE_DIR}/${stack}"
	done
}

compose_dirs_reverse() {
	local index

	for ((index = ${#STACKS[@]} - 1; index >= 0; index--)); do
		printf '%s\n' "${BASE_DIR}/${STACKS[index]}"
	done
}

#
# Discover services explicitly assigned to the nfs profile.
#
# Called from within the relevant Compose directory.
#
nfs_services() {
	compose --profile nfs config --format json |
		python3 -c '
import json
import sys

data = json.load(sys.stdin)
services = data.get("services", {})

for name, service in services.items():
    if "nfs" in service.get("profiles", []):
        print(name)
'
}

#
# Populate the caller's services array.
#
# Command substitution is used instead of mapfile with process
# substitution so that failures in nfs_services are propagated.
#
get_nfs_services() {
	local dir="$1"
	local output

	services=()

	output="$(
		cd "${dir}" &&
			nfs_services
	)" || die "failed to detect NFS services in: ${dir}"

	if [[ -n "${output}" ]]; then
		mapfile -t services <<<"${output}"
	fi
}

wait_for_nfs() {
	local path
	local fstypes
	local nfs_fstype

	for path in "${NFS_PATHS[@]}"; do
		log "==> Checking NFS mount: ${path}"

		#
		# Accessing the path triggers x-systemd.automount.
		#
		# If the NAS/network is unavailable, fail this invocation
		# so systemd's Restart=on-failure can retry it later.
		#
		if ! timeout 30 stat "${path}/." >/dev/null 2>&1; then
			die "NFS path is not reachable: ${path}"
		fi

		#
		# With x-systemd.automount, findmnt may report multiple
		# filesystem layers for the same path, for example:
		#
		#   autofs
		#   nfs4
		#
		# Accept the path if any reported filesystem type is
		# nfs or nfs4.
		#
		fstypes="$(findmnt -T "${path}" -n -o FSTYPE 2>/dev/null || true)"

		nfs_fstype="$(
			printf '%s\n' "${fstypes}" |
				grep -m1 -xE 'nfs|nfs4' ||
				true
		)"

		if [[ -z "${nfs_fstype}" ]]; then
			die "path is not mounted via NFS: ${path} (fstype=${fstypes:-none})"
		fi

		log "==> NFS mount available: ${path} (${nfs_fstype})"
	done

	log "==> All NFS mounts are available"
}

#
# Start default/non-profiled services across all stacks.
#
# COMPOSE_PROFILES is explicitly cleared by compose(), so
# Komodo's nfs profile cannot be activated during this phase.
#
run_compose_up_core() {
	local dir

	while IFS= read -r dir; do
		log "==> Core up: ${dir}"

		(
			cd "${dir}" || exit 1
			compose up -d
		)
	done < <(compose_dirs)
}

#
# Stop default/non-profiled services in reverse stack order.
#
run_compose_stop_core() {
	local dir

	while IFS= read -r dir; do
		log "==> Core stop: ${dir}"

		(
			cd "${dir}" || exit 1
			compose stop
		)
	done < <(compose_dirs_reverse)
}

#
# Start NFS-profile services only after verifying all NFS mounts.
#
# Explicit service names prevent unrelated default services from
# being included merely because the nfs profile is enabled.
#
run_compose_up_nfs() {
	local dir
	local -a services=()

	wait_for_nfs

	while IFS= read -r dir; do
		get_nfs_services "${dir}"

		if [[ "${#services[@]}" -eq 0 ]]; then
			log "==> NFS up: ${dir} has no nfs-profile services, skipping"
			continue
		fi

		log "==> NFS up: ${dir}: ${services[*]}"

		(
			cd "${dir}" || exit 1
			compose --profile nfs up -d "${services[@]}"
		)
	done < <(compose_dirs)
}

#
# Stop NFS-profile services in reverse stack order.
#
run_compose_stop_nfs() {
	local dir
	local -a services=()

	while IFS= read -r dir; do
		get_nfs_services "${dir}"

		if [[ "${#services[@]}" -eq 0 ]]; then
			log "==> NFS stop: ${dir} has no nfs-profile services, skipping"
			continue
		fi

		log "==> NFS stop: ${dir}: ${services[*]}"

		(
			cd "${dir}" || exit 1
			compose --profile nfs stop "${services[@]}"
		)
	done < <(compose_dirs_reverse)
}

list_nfs_services() {
	local dir
	local stack_name
	local -a services=()

	while IFS= read -r dir; do
		get_nfs_services "${dir}"

		if [[ "${#services[@]}" -gt 0 ]]; then
			stack_name="${dir#"${BASE_DIR}"/}"
			log "${stack_name}: ${services[*]}"
		fi
	done < <(compose_dirs)
}

usage() {
	cat <<EOF
Usage: $(basename "$0") {up-core|stop-core|up-nfs|stop-nfs|list|list-nfs}

Commands:
  up-core    Start all default/non-profiled Compose services.
  stop-core  Stop all default/non-profiled Compose services.
  up-nfs     Verify NFS mounts, then start all services with profiles: ["nfs"].
  stop-nfs   Stop all services with profiles: ["nfs"].
  list       List allowlisted Compose stack directories.
  list-nfs   List detected nfs-profile services per stack.

Compose checkout:
  ${BASE_DIR}

Environment:
  Automatic .env loading is disabled.
  COMPOSE_PROFILES is cleared unless --profile nfs is explicitly used.
EOF
}

main() {
	local command="${1:-}"

	require_commands

	case "${command}" in
	up-core)
		validate_checkout
		run_compose_up_core
		;;
	stop-core)
		validate_checkout
		run_compose_stop_core
		;;
	up-nfs)
		validate_checkout
		run_compose_up_nfs
		;;
	stop-nfs)
		validate_checkout
		run_compose_stop_nfs
		;;
	list)
		validate_checkout
		compose_dirs
		;;
	list-nfs)
		validate_checkout
		list_nfs_services
		;;
	-h | --help | help)
		usage
		;;
	*)
		usage >&2
		exit 2
		;;
	esac
}

main "$@"
