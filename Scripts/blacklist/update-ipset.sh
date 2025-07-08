#!/bin/bash

# Log file for debugging cron issues
LOG_FILE="/var/log/update-ipset.log"
exec >>"$LOG_FILE" 2>&1

echo "========== $(date) Starting IPSet Update =========="
echo "PATH: $PATH"
echo "Running as user: $(whoami)"

# Full paths to binaries
IPSET="/usr/sbin/ipset"
CURL="/usr/bin/curl"
SORT="/usr/bin/sort"
GREP="/usr/bin/grep"
RM="/usr/bin/rm"

# Define ipset names
IPSET_NAME="blacklist"
TMP_SET="${IPSET_NAME}_tmp"
TMP_FILE="/tmp/ipset_blacklist.tmp"

# Ensure ipset exists
if ! $IPSET list $IPSET_NAME >/dev/null 2>&1; then
	echo "Creating ipset $IPSET_NAME"
	$IPSET create $IPSET_NAME hash:net
fi

# Create or reset temporary ipset
if $IPSET list $TMP_SET >/dev/null 2>&1; then
	$IPSET flush $TMP_SET
else
	$IPSET create $TMP_SET hash:net
fi

# Fetch and clean IP lists
echo "Downloading IP blacklists..."
$CURL -s https://iplists.firehol.org/files/firehol_level3.netset | $GREP -v '^#' >"$TMP_FILE"

# Uncomment or add more sources as needed
# $CURL -s https://www.spamhaus.org/drop/drop.txt | $AWK '{print $1}' >>"$TMP_FILE"
# $CURL -s https://cinsscore.com/list/ci-badguys.txt >>"$TMP_FILE"
# $CURL -s https://www.dshield.org/block.txt | $AWK '!/^#/ {print $1}' >>"$TMP_FILE"

# Check if we got any data
if [[ ! -s $TMP_FILE ]]; then
	echo "Error: No IPs downloaded. Aborting update."
	exit 1
fi

# Deduplicate entries
$SORT -u "$TMP_FILE" -o "$TMP_FILE"

# Add IPs to temporary ipset
echo "Adding IPs to temporary ipset..."
while read -r IP; do
	[[ -n "$IP" ]] && $IPSET add $TMP_SET "$IP" 2>/dev/null
done <"$TMP_FILE"

# Atomically swap the sets
echo "Swapping sets..."
$IPSET swap $TMP_SET $IPSET_NAME
$IPSET destroy $TMP_SET

# Save for persistence
$IPSET save $IPSET_NAME >/etc/ipset_blacklist.conf

# Cleanup
$RM -f "$TMP_FILE"

echo "Update complete ✅"
