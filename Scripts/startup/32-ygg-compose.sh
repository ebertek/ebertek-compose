#!/usr/bin/env bash
#
# Manage all allowed Ygg Docker Compose stacks on Pleiades.
#
# Usage:
#   ygg-compose.sh up-core
#   ygg-compose.sh stop-core
#   ygg-compose.sh up-nfs
#   ygg-compose.sh stop-nfs
#   ygg-compose.sh list
#   ygg-compose.sh list-nfs

set -Eeuo pipefail

readonly BASE_DIR="/home/docker/ygg-compose"

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

require_commands() {
  local -a required_commands=(
    "docker"
    "python3"
  )

  local command_name
  for command_name in "${required_commands[@]}"; do
    command -v "${command_name}" >/dev/null 2>&1 \
      || die "required command not found: ${command_name}"
  done
}

compose_dirs() {
  local stack
  local compose_file

  for stack in "${STACKS[@]}"; do
    compose_file="${BASE_DIR}/${stack}/compose.yaml"

    if [[ -f "${compose_file}" ]]; then
      printf '%s\n' "${BASE_DIR}/${stack}"
    else
      warn "missing compose file for stack: ${stack}"
    fi
  done
}

compose_dirs_reverse() {
  local index
  local stack
  local compose_file

  for ((index = ${#STACKS[@]} - 1; index >= 0; index--)); do
    stack="${STACKS[index]}"
    compose_file="${BASE_DIR}/${stack}/compose.yaml"

    if [[ -f "${compose_file}" ]]; then
      printf '%s\n' "${BASE_DIR}/${stack}"
    fi
  done
}

nfs_services() {
  docker compose --profile nfs config --format json \
    | python3 -c '
import json
import sys

data = json.load(sys.stdin)
services = data.get("services", {})

for name, service in services.items():
    if "nfs" in service.get("profiles", []):
        print(name)
'
}

run_compose_up_core() {
  local dir

  while IFS= read -r dir; do
    log "==> Core up: ${dir}"

    (
      cd "${dir}" || exit 1
      docker compose up -d
    )
  done < <(compose_dirs)
}

run_compose_stop_core() {
  local dir

  while IFS= read -r dir; do
    log "==> Core stop: ${dir}"

    (
      cd "${dir}" || exit 1
      docker compose stop
    )
  done < <(compose_dirs_reverse)
}

run_compose_up_nfs() {
  local dir
  local -a services=()

  while IFS= read -r dir; do
    mapfile -t services < <(
      cd "${dir}" && nfs_services
    )

    if [[ "${#services[@]}" -eq 0 ]]; then
      log "==> NFS up: ${dir} has no nfs-profile services, skipping"
      continue
    fi

    log "==> NFS up: ${dir}: ${services[*]}"

    (
      cd "${dir}" || exit 1
      docker compose --profile nfs up -d "${services[@]}"
    )
  done < <(compose_dirs)
}

run_compose_stop_nfs() {
  local dir
  local -a services=()

  while IFS= read -r dir; do
    mapfile -t services < <(
      cd "${dir}" && nfs_services
    )

    if [[ "${#services[@]}" -eq 0 ]]; then
      log "==> NFS stop: ${dir} has no nfs-profile services, skipping"
      continue
    fi

    log "==> NFS stop: ${dir}: ${services[*]}"

    (
      cd "${dir}" || exit 1
      docker compose --profile nfs stop "${services[@]}"
    )
  done < <(compose_dirs_reverse)
}

list_nfs_services() {
  local dir
  local stack_name
  local -a services=()

  while IFS= read -r dir; do
    mapfile -t services < <(
      cd "${dir}" && nfs_services
    )

    if [[ "${#services[@]}" -gt 0 ]]; then
      stack_name="${dir#${BASE_DIR}/}"
      log "${stack_name}: ${services[*]}"
    fi
  done < <(compose_dirs)
}

usage() {
  cat <<'EOF'
Usage: ygg-compose.sh {up-core|stop-core|up-nfs|stop-nfs|list|list-nfs}

Commands:
  up-core    Start all default/non-profiled Compose services.
  stop-core  Stop all default/non-profiled Compose services.
  up-nfs     Start all services with profiles: ["nfs"].
  stop-nfs   Stop all services with profiles: ["nfs"].
  list       List allowlisted Compose stack directories.
  list-nfs   List detected nfs-profile services per stack.
EOF
}

main() {
  local command="${1:-}"

  require_commands

  case "${command}" in
    up-core)
      run_compose_up_core
      ;;
    stop-core)
      run_compose_stop_core
      ;;
    up-nfs)
      run_compose_up_nfs
      ;;
    stop-nfs)
      run_compose_stop_nfs
      ;;
    list)
      compose_dirs
      ;;
    list-nfs)
      list_nfs_services
      ;;
    -h|--help|help)
      usage
      ;;
    *)
      usage >&2
      exit 2
      ;;
  esac
}

main "$@"
