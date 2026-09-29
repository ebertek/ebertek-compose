#!/bin/bash

set -euo pipefail

settings=(
	"fs.inotify.max_user_watches=524288"
	"net.core.somaxconn=65535"
	"net.ipv4.conf.all.src_valid_mark=1"
	"net.ipv4.ping_group_range=0 65535"
	"net.ipv6.conf.all.accept_ra=2"
	"net.ipv6.conf.default.accept_ra=2"
	"vm.overcommit_memory=1"
)

log() {
	printf '[%s] %s\n' "$(date '+%Y-%m-%dT%H:%M:%S%z')" "$*"
}

log "Applying sysctl settings"

for setting in "${settings[@]}"; do
	key=${setting%%=*}
	value=${setting#*=}
	current=$(sysctl -n "$key")

	log "${key}: ${current} -> ${value}"
	sysctl -w "${key}=${value}"
done

log "sysctl settings applied successfully"
