#!/usr/bin/env bash

set -euo pipefail

readonly PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"

readonly LOG_FILE="/var/log/update-nftset.log"

readonly NFT_FAMILY="inet"
readonly NFT_TABLE="tnt_blacklist"
readonly IPV4_SET="blacklist"
readonly IPV6_SET="blacklist6"
readonly INPUT_CHAIN="input"

readonly IPV4_URL="https://iplists.firehol.org/files/firehol_level3.netset"
readonly IPV6_URL="https://iplists.firehol.org/files/firehol_level3_ipv6.netset"

readonly NFTABLES_DIR="/etc/nftables"
readonly NFTABLES_CONF="${NFTABLES_DIR}/tnt-blacklist.nft"
readonly NFTABLES_MAIN="/etc/sysconfig/nftables.conf"
readonly LOGROTATE_CONF="/etc/logrotate.d/nftset"

tmp_ipv4=""
tmp_ipv6=""

cleanup() {
	[[ -n "$tmp_ipv4" ]] && rm -f "$tmp_ipv4"
	[[ -n "$tmp_ipv6" ]] && rm -f "$tmp_ipv6"
}

trap cleanup EXIT

exec >>"$LOG_FILE" 2>&1

log() {
	printf '%s %s\n' "$(date '+%F %T')" "$*"
}

die() {
	log "ERROR: $*"
	exit 1
}

write_persistent_config() {
	mkdir -p "$NFTABLES_DIR"

	cat >"$NFTABLES_CONF" <<'EOF'
table inet tnt_blacklist {
	set blacklist {
		type ipv4_addr
		flags interval
		comment "Auto-managed blacklist of banned IPv4 addresses"
	}

	set blacklist6 {
		type ipv6_addr
		flags interval
		comment "Auto-managed blacklist of banned IPv6 addresses"
	}

	chain input {
		type filter hook input priority filter; policy accept;
		ip saddr @blacklist counter drop
		ip6 saddr @blacklist6 counter drop
	}
}
EOF

	mkdir -p "$(dirname "$NFTABLES_MAIN")"
	touch "$NFTABLES_MAIN"

	if ! grep -Fqx 'include "/etc/nftables/tnt-blacklist.nft"' "$NFTABLES_MAIN"; then
		printf '%s\n' 'include "/etc/nftables/tnt-blacklist.nft"' >>"$NFTABLES_MAIN"
		log "Added ${NFTABLES_CONF} include to ${NFTABLES_MAIN}"
	fi
}

ensure_nftables_objects() {
	local changed=false

	if ! nft list table "$NFT_FAMILY" "$NFT_TABLE" >/dev/null 2>&1; then
		log "Creating nftables table ${NFT_FAMILY} ${NFT_TABLE}"
		nft add table "$NFT_FAMILY" "$NFT_TABLE"
		changed=true
	fi

	if ! nft list set "$NFT_FAMILY" "$NFT_TABLE" "$IPV4_SET" >/dev/null 2>&1; then
		log "Creating IPv4 set ${IPV4_SET}"

		nft -f - <<EOF
add set ${NFT_FAMILY} ${NFT_TABLE} ${IPV4_SET} {
	type ipv4_addr
	flags interval
	comment "Auto-managed blacklist of banned IPv4 addresses"
}
EOF
		changed=true
	fi

	if ! nft list set "$NFT_FAMILY" "$NFT_TABLE" "$IPV6_SET" >/dev/null 2>&1; then
		log "Creating IPv6 set ${IPV6_SET}"

		nft -f - <<EOF
add set ${NFT_FAMILY} ${NFT_TABLE} ${IPV6_SET} {
	type ipv6_addr
	flags interval
	comment "Auto-managed blacklist of banned IPv6 addresses"
}
EOF
		changed=true
	fi

	if ! nft list chain "$NFT_FAMILY" "$NFT_TABLE" "$INPUT_CHAIN" >/dev/null 2>&1; then
		log "Creating blacklist input chain"

		nft -f - <<EOF
add chain ${NFT_FAMILY} ${NFT_TABLE} ${INPUT_CHAIN} {
	type filter hook input priority filter
	policy accept
}
EOF
		changed=true
	fi

	if ! nft list chain "$NFT_FAMILY" "$NFT_TABLE" "$INPUT_CHAIN" |
		grep -Fq "ip saddr @${IPV4_SET}"; then
		log "Adding IPv4 blacklist rule"
		nft add rule "$NFT_FAMILY" "$NFT_TABLE" "$INPUT_CHAIN" \
			ip saddr "@${IPV4_SET}" counter drop
		changed=true
	fi

	if ! nft list chain "$NFT_FAMILY" "$NFT_TABLE" "$INPUT_CHAIN" |
		grep -Fq "ip6 saddr @${IPV6_SET}"; then
		log "Adding IPv6 blacklist rule"
		nft add rule "$NFT_FAMILY" "$NFT_TABLE" "$INPUT_CHAIN" \
			ip6 saddr "@${IPV6_SET}" counter drop
		changed=true
	fi

	if [[ "$changed" == true ]]; then
		write_persistent_config

		if command -v systemctl >/dev/null 2>&1; then
			if ! systemctl enable nftables --quiet; then
				log "WARNING: Failed to enable nftables.service"
			fi

			if ! systemctl start nftables --quiet; then
				log "WARNING: Failed to start nftables.service"
			fi
		fi
	fi
}

download_list() {
	local url=$1
	local destination=$2
	local description=$3

	log "Downloading ${description}"

	if ! curl \
		--fail \
		--silent \
		--show-error \
		--location \
		--connect-timeout 10 \
		--max-time 30 \
		"$url" |
		awk '!/^[[:space:]]*#/ && NF' >"$destination"; then
		return 1
	fi

	if [[ ! -s "$destination" ]]; then
		return 1
	fi

	sort -u "$destination" -o "$destination"
}

update_set() {
	local set_name=$1
	local source_file=$2
	local description=$3
	local count

	count=$(wc -l <"$source_file")
	log "Updating ${description} with ${count} entries"

	if ! {
		printf 'flush set %s %s %s\n' \
			"$NFT_FAMILY" \
			"$NFT_TABLE" \
			"$set_name"

		printf 'add element %s %s %s { ' \
			"$NFT_FAMILY" \
			"$NFT_TABLE" \
			"$set_name"

		paste -sd, "$source_file"

		printf ' }\n'
	} | nft -f -; then
		log "ERROR: Failed to update ${description}; existing set left unchanged"
		return 1
	fi

	log "${description} update complete (${count} entries loaded)"
}

ensure_logrotate() {
	if [[ -f "$LOGROTATE_CONF" ]]; then
		return
	fi

	cat >"$LOGROTATE_CONF" <<'EOF'
/var/log/update-nftset.log {
	weekly
	rotate 4
	compress
	missingok
	notifempty
}
EOF

	log "Created logrotate configuration"
}

main() {
	if ((EUID != 0)); then
		die "This script must be run as root"
	fi

	command -v nft >/dev/null 2>&1 || die "nft is not installed"
	command -v curl >/dev/null 2>&1 || die "curl is not installed"

	log "========== Starting nftables blacklist update =========="

	ensure_nftables_objects

	tmp_ipv4=$(mktemp /tmp/nft-blacklist-ipv4.XXXXXX)
	tmp_ipv6=$(mktemp /tmp/nft-blacklist-ipv6.XXXXXX)

	if download_list "$IPV4_URL" "$tmp_ipv4" "IPv4 blacklist"; then
		update_set "$IPV4_SET" "$tmp_ipv4" "IPv4 blacklist"
	else
		log "ERROR: IPv4 blacklist download failed or returned no entries; existing set left unchanged"
	fi

	if download_list "$IPV6_URL" "$tmp_ipv6" "IPv6 blacklist"; then
		update_set "$IPV6_SET" "$tmp_ipv6" "IPv6 blacklist"
	else
		log "WARNING: IPv6 blacklist download failed or returned no entries; existing set left unchanged"
	fi

	ensure_logrotate

	log "========== nftables blacklist update complete =========="
}

main "$@"
