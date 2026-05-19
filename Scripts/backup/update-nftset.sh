#!/bin/bash

LOG_FILE="/var/log/update-nftset.log"
exec >> "$LOG_FILE" 2>&1

echo "========== $(date) Starting nftables Blacklist Update =========="

NFT="/usr/sbin/nft"
CURL="/usr/bin/curl"
SORT="/usr/bin/sort"
GREP="/usr/bin/grep"
RM="/usr/bin/rm"

TABLE_NAME="inet"
CHAIN_NAME="filter"
SET_NAME="blacklist"
TMP_FILE="/tmp/nft_blacklist.tmp"

# Confirm set exists before doing anything
if ! $NFT list set $TABLE_NAME $CHAIN_NAME $SET_NAME >/dev/null 2>&1; then
	echo "Error: Set $TABLE_NAME $CHAIN_NAME $SET_NAME does not exist."
	exit 1
fi

# Download first
echo "Downloading IP blacklist..."
$CURL -s --max-time 30 --fail https://iplists.firehol.org/files/firehol_level3.netset | $GREP -v '^#' > "$TMP_FILE"

if [[ ! -s "$TMP_FILE" ]]; then
	echo "Error: Download failed or returned empty list. Blacklist unchanged."
	$RM -f "$TMP_FILE"
	exit 1
fi

# Deduplicate
$SORT -u "$TMP_FILE" -o "$TMP_FILE"
COUNT=$(wc -l < "$TMP_FILE")
echo "Downloaded $COUNT entries."

# Now flush and reload
echo "Flushing set $SET_NAME..."
$NFT flush set $TABLE_NAME $CHAIN_NAME $SET_NAME

echo "Adding IPs to set $SET_NAME..."
if ! $NFT -f - <<EOF
add element inet filter blacklist { $(paste -sd, "$TMP_FILE") }
EOF
then
	echo "Error: nft add element failed."
	$RM -f "$TMP_FILE"
	exit 1
fi

$RM -f "$TMP_FILE"

echo "Update complete ✅ ($COUNT entries loaded)"
