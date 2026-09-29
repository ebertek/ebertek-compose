#!/usr/bin/env bash

set -euo pipefail

readonly HOST_IFACE="macvlan1-host"

readonly PARENT="enp86s0"
readonly GW_ADDR4="10.4.20.1/32"
readonly HOST_RANGE4="10.4.20.0/23"

readonly DOCKER_RANGE4="10.4.21.0/25"
readonly HOST_ADDR4="10.4.21.1/32"
readonly DNS_ADDR4="10.4.21.34"

readonly DOCKER_RANGE6="fd0e:be00:da00:20:421::/80"
readonly HOST_ADDR6="fd0e:be00:da00:20:421::1/128"

log() {
	printf '[%s] %s\n' "$(date '+%Y-%m-%dT%H:%M:%S%z')" "$*"
}

error() {
	printf '[%s] ERROR: %s\n' "$(date '+%Y-%m-%dT%H:%M:%S%z')" "$*" >&2
}

log "Waiting for parent interface ${PARENT}"

for _ in {1..30}; do
	if ip link show "$PARENT" >/dev/null 2>&1; then
		state=$(ip -o link show "$PARENT" | awk '{print $9}')

		if [[ "$state" == "UP" || "$state" == "LOWER_UP" ]]; then
			break
		fi
	fi

	sleep 1
done

if ! ip link show "$PARENT" >/dev/null 2>&1; then
	error "Parent interface ${PARENT} does not exist"
	exit 1
fi

state=$(ip -o link show "$PARENT" | awk '{print $9}')

if [[ "$state" != "UP" && "$state" != "LOWER_UP" ]]; then
	error "Parent interface ${PARENT} did not become operational"
	exit 1
fi

log "Configuring host macvlan interface ${HOST_IFACE}"

if ! ip link show "$HOST_IFACE" >/dev/null 2>&1; then
	log "Creating ${HOST_IFACE}"

	ip link add \
		"$HOST_IFACE" \
		link "$PARENT" \
		type macvlan \
		mode bridge
fi

ip link set "$HOST_IFACE" up

log "Configuring IPv4"

ip -4 addr flush dev "$HOST_IFACE"
ip -4 addr add "$HOST_ADDR4" dev "$HOST_IFACE"

ip -4 route del default dev "$HOST_IFACE" 2>/dev/null || true
ip -4 route del "$HOST_RANGE4" dev "$HOST_IFACE" 2>/dev/null || true
ip -4 route del "$GW_ADDR4" dev "$HOST_IFACE" 2>/dev/null || true
ip -4 route del "${HOST_ADDR4%/*}/32" dev "$PARENT" 2>/dev/null || true

ip -4 route del "${DNS_ADDR4}/32" dev "$PARENT" 2>/dev/null || true
ip -4 route replace \
	"${DNS_ADDR4}/32" \
	dev "$HOST_IFACE" \
	src "${HOST_ADDR4%/*}"

ip -4 route replace \
	"$DOCKER_RANGE4" \
	dev "$HOST_IFACE" \
	src "${HOST_ADDR4%/*}"

log "Applying ARP settings"

sysctl -w net.ipv4.conf.all.arp_ignore=1
sysctl -w net.ipv4.conf.all.arp_announce=2
sysctl -w "net.ipv4.conf.${PARENT}.arp_ignore=1"
sysctl -w "net.ipv4.conf.${PARENT}.arp_announce=2"
sysctl -w "net.ipv4.conf.${HOST_IFACE}.arp_ignore=1"
sysctl -w "net.ipv4.conf.${HOST_IFACE}.arp_announce=2"

log "Disabling IPv6 autoconfiguration on ${HOST_IFACE}"

sysctl -w "net.ipv6.conf.${HOST_IFACE}.autoconf=0"
sysctl -w "net.ipv6.conf.${HOST_IFACE}.accept_ra=0"

log "Configuring IPv6"

ip -6 addr flush dev "$HOST_IFACE" scope global
ip -6 addr add "$HOST_ADDR6" dev "$HOST_IFACE"
ip -6 route replace "$DOCKER_RANGE6" dev "$HOST_IFACE"

log "Host macvlan interface ${HOST_IFACE} configured successfully"
