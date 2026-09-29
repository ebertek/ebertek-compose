#!/bin/sh
set -eu

log() {
	printf '[%s] %s\n' "$(date '+%Y-%m-%dT%H:%M:%S%z')" "$*"
}

error() {
	printf '[%s] ERROR: %s\n' "$(date '+%Y-%m-%dT%H:%M:%S%z')" "$*" >&2
}

log "Ensuring /dev/net/tun exists"

if [ ! -c /dev/net/tun ]; then
	if [ ! -d /dev/net ]; then
		log "Creating /dev/net"
		mkdir -m 0755 /dev/net
	fi

	log "Creating /dev/net/tun"
	mknod /dev/net/tun c 10 200
	chmod 0755 /dev/net/tun
else
	log "/dev/net/tun already exists"
fi

if lsmod | grep -q '^tun[[:space:]]'; then
	log "tun kernel module already loaded"
else
	if [ ! -f /lib/modules/tun.ko ]; then
		error "tun kernel module not found: /lib/modules/tun.ko"
		exit 1
	fi

	log "Loading tun kernel module"
	insmod /lib/modules/tun.ko
fi

log "TUN setup completed successfully"
