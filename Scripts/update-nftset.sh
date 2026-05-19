#!/bin/bash

LOG_FILE="/var/log/update-nftset.log"
exec >>"$LOG_FILE" 2>&1

echo "========== $(date) Starting nftables Blacklist Update =========="

NFT="/usr/sbin/nft"
CURL="/usr/bin/curl"
SORT="/usr/bin/sort"
GREP="/usr/bin/grep"
RM="/usr/bin/rm"

TABLE_NAME="inet"
CHAIN_NAME="filter"
SET_NAME="blacklist"
SET_NAME6="blacklist6"
TMP_FILE="/tmp/nft_blacklist.tmp"
TMP_FILE6="/tmp/nft_blacklist6.tmp"

# Bootstrap: create table, sets, chain and rules if they don't exist
bootstrap_nftables() {
	echo "Bootstrapping nftables ruleset..."
	if ! $NFT -f - <<'NFTEOF'; then
table inet filter {
	set blacklist {
		type ipv4_addr
		flags interval
		comment "Auto-managed blacklist of banned IPs"
	}

	set blacklist6 {
		type ipv6_addr
		flags interval
		comment "Auto-managed IPv6 blacklist"
	}

	chain input {
		type filter hook input priority filter; policy accept;
		ip saddr @blacklist counter drop
		ip6 saddr @blacklist6 counter drop
	}

	chain forward {
		type filter hook forward priority filter; policy accept;
	}

	chain output {
		type filter hook output priority filter; policy accept;
	}
}
NFTEOF
		echo "Error: Failed to bootstrap nftables. Aborting."
		exit 1
	fi

	# Persist to disk so it survives reboots
	NFTABLES_CONF="/etc/nftables/tnt.nft"
	NFTABLES_MAIN="/etc/sysconfig/nftables.conf"

	mkdir -p /etc/nftables

	cat >"$NFTABLES_CONF" <<'EOF'
table inet filter {
	set blacklist {
		type ipv4_addr
		flags interval
		comment "Auto-managed blacklist of banned IPs"
	}

	set blacklist6 {
		type ipv6_addr
		flags interval
		comment "Auto-managed IPv6 blacklist"
	}

	chain input {
		type filter hook input priority filter; policy accept;
		ip saddr @blacklist counter drop
		ip6 saddr @blacklist6 counter drop
	}

	chain forward {
		type filter hook forward priority filter; policy accept;
	}

	chain output {
		type filter hook output priority filter; policy accept;
	}
}
EOF

	# Only write main conf if it doesn't already include tnt.nft
	if ! grep -q 'tnt.nft' "$NFTABLES_MAIN" 2>/dev/null; then
		echo 'include "/etc/nftables/tnt.nft"' >>"$NFTABLES_MAIN"
		echo "Added tnt.nft include to $NFTABLES_MAIN"
	fi

	# Enable and start nftables service if not already
	systemctl enable nftables --quiet 2>/dev/null
	systemctl start nftables --quiet 2>/dev/null
	echo "Bootstrap complete."
}

# Check if both sets exist, bootstrap if either is missing
if ! $NFT list set $TABLE_NAME $CHAIN_NAME $SET_NAME >/dev/null 2>&1 ||
	! $NFT list set $TABLE_NAME $CHAIN_NAME $SET_NAME6 >/dev/null 2>&1; then
	bootstrap_nftables
fi

# --- IPv4 ---
echo "Downloading IPv4 blacklist..."
$CURL -s --max-time 30 --fail https://iplists.firehol.org/files/firehol_level3.netset | $GREP -v '^#' >"$TMP_FILE"

if [[ ! -s "$TMP_FILE" ]]; then
	echo "Error: IPv4 download failed or empty. Blacklist unchanged."
	$RM -f "$TMP_FILE"
else
	$SORT -u "$TMP_FILE" -o "$TMP_FILE"
	COUNT=$(wc -l <"$TMP_FILE")
	echo "Downloaded $COUNT IPv4 entries."
	$NFT flush set $TABLE_NAME $CHAIN_NAME $SET_NAME
	if ! $NFT -f - <<EOF; then
add element inet filter blacklist { $(paste -sd, "$TMP_FILE") }
EOF
		echo "Error: nft add element failed for IPv4."
	else
		echo "IPv4 update complete ($COUNT entries loaded)"
	fi
	$RM -f "$TMP_FILE"
fi

# --- IPv6 ---
echo "Downloading IPv6 blacklist..."
$CURL -s --max-time 30 --fail https://iplists.firehol.org/files/firehol_level3_ipv6.netset | $GREP -v '^#' >"$TMP_FILE6"

if [[ ! -s "$TMP_FILE6" ]]; then
	echo "Warning: IPv6 download failed or empty, skipping."
	$RM -f "$TMP_FILE6"
else
	$SORT -u "$TMP_FILE6" -o "$TMP_FILE6"
	COUNT6=$(wc -l <"$TMP_FILE6")
	echo "Downloaded $COUNT6 IPv6 entries."
	$NFT flush set $TABLE_NAME $CHAIN_NAME $SET_NAME6
	if ! $NFT -f - <<EOF; then
add element inet filter blacklist6 { $(paste -sd, "$TMP_FILE6") }
EOF
		echo "Error: nft add element failed for IPv6."
	else
		echo "IPv6 update complete ($COUNT6 entries loaded)"
	fi
	$RM -f "$TMP_FILE6"
fi

# Setup logrotate if not already configured
if [[ ! -f /etc/logrotate.d/nftset ]]; then
	cat >/etc/logrotate.d/nftset <<'EOF'
/var/log/update-nftset.log {
	weekly
	rotate 4
	compress
	missingok
	notifempty
}
EOF
	echo "Logrotate config created."
fi

echo "========== $(date) Done =========="
