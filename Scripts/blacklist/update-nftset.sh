#!/bin/bash

# Log file for debugging cron issues
LOG_FILE="/var/log/update-nftset.log"
exec >>"$LOG_FILE" 2>&1

echo "========== $(date) Starting nftables Blacklist Update =========="
echo "PATH: $PATH"
echo "Running as user: $(whoami)"

# Full paths to binaries
NFT="/usr/sbin/nft"
CURL="/usr/bin/curl"
SORT="/usr/bin/sort"
GREP="/usr/bin/grep"
RM="/usr/bin/rm"

TABLE_NAME="inet"
CHAIN_NAME="filter"
SET_NAME="blacklist"
TMP_FILE="/tmp/nft_blacklist.tmp"

# Confirm set exists before flushing
if ! $NFT list set $TABLE_NAME $CHAIN_NAME $SET_NAME >/dev/null 2>&1; then
	echo "Error: Set $TABLE_NAME $CHAIN_NAME $SET_NAME does not exist. Make sure it's in /etc/nftables.conf."
	exit 1
fi

# Flush existing elements
echo "Flushing set $SET_NAME..."
$NFT flush set $TABLE_NAME $CHAIN_NAME $SET_NAME

# Download IP blacklist
echo "Downloading IP blacklists..."
$CURL -s https://iplists.firehol.org/files/firehol_level3.netset | $GREP -v '^#' >"$TMP_FILE"

# Abort if empty
if [[ ! -s $TMP_FILE ]]; then
	echo "Error: No IPs downloaded. Aborting update."
	exit 1
fi

# Deduplicate
$SORT -u "$TMP_FILE" -o "$TMP_FILE"

# Add entries one by one
echo "Adding IPs to set $SET_NAME..."
if [[ -s "$TMP_FILE" ]]; then
	echo "Adding IPs to set blacklist (bulk)..."
	$NFT -f - <<EOF
add element inet filter blacklist { $(paste -sd, "$TMP_FILE") }
EOF
else
	echo "Error: IP list is empty, skipping add."
fi

$RM -f "$TMP_FILE"

echo "Update complete ✅"
