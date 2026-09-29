#!/usr/bin/env bash

set -euo pipefail

readonly DOCKER_NET="macvlan1"

readonly PARENT="enp86s0"

readonly DOCKER_SUBNET4="10.4.20.0/23"
readonly DOCKER_GATEWAY4="10.4.20.1"
readonly DOCKER_RANGE4="10.4.21.0/25"
readonly HOST_ADDR4="10.4.21.1/32"

readonly DOCKER_SUBNET6="fd0e:be00:da00:20::/64"
readonly DOCKER_GATEWAY6="fd0e:be00:da00:20::1"
readonly DOCKER_RANGE6="fd0e:be00:da00:20:421::/80"
readonly HOST_ADDR6="fd0e:be00:da00:20:421::1/128"

log() {
	printf '[%s] %s\n' "$(date '+%Y-%m-%dT%H:%M:%S%z')" "$*"
}

error() {
	printf '[%s] ERROR: %s\n' "$(date '+%Y-%m-%dT%H:%M:%S%z')" "$*" >&2
}

log "Waiting for Docker daemon"

for _ in {1..30}; do
	if docker info >/dev/null 2>&1; then
		break
	fi

	sleep 1
done

if ! docker info >/dev/null 2>&1; then
	error "Docker daemon is not available"
	exit 1
fi

if docker network inspect "$DOCKER_NET" >/dev/null 2>&1; then
	log "Docker macvlan network ${DOCKER_NET} already exists"
else
	log "Creating Docker macvlan network ${DOCKER_NET}"

	docker network create \
		--driver macvlan \
		--subnet="$DOCKER_SUBNET4" \
		--gateway="$DOCKER_GATEWAY4" \
		--ip-range="$DOCKER_RANGE4" \
		--aux-address="host=${HOST_ADDR4%/*}" \
		--ipv6 \
		--subnet="$DOCKER_SUBNET6" \
		--gateway="$DOCKER_GATEWAY6" \
		--ip-range="$DOCKER_RANGE6" \
		--aux-address="host=${HOST_ADDR6%/*}" \
		--opt parent="$PARENT" \
		"$DOCKER_NET"
fi

log "Docker macvlan network ${DOCKER_NET} is ready"
