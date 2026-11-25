#!/usr/bin/env bash
set -euo pipefail
umask 077

backup_root=${1:?Specify the Komodo backup directory}
script_dir=$(cd "$(dirname "$0")" && pwd)
settings=/root/.config/restic/komodo-offsite
rclone=/usr/local/bin/rclone

exec 9>/run/lock/komodo-core-offsite.lock
if ! flock -n 9; then
	echo "Another Komodo offsite backup is running" >&2
	exit 1
fi

if [[ ! -x "$rclone" || ! -s "$settings/password" || ! -s "$settings/storagebox-known-hosts" || ! -r "$script_dir/rclone.conf" ]]; then
	echo "Komodo offsite backup prerequisites are missing" >&2
	exit 1
fi

latest=$("$script_dir/check-komodo-core.sh" "$backup_root" --print-path)
files=("$latest"/*.gz "$backup_root/Stats.gz")
for file in "${files[@]}"; do
	if [[ ! -s "$file" || ! -f "$file" || -L "$file" ]]; then
		echo "Komodo offsite backup source contains a missing or unsafe archive" >&2
		exit 1
	fi
done
gzip -t -- "$backup_root/Stats.gz"
before=$(stat -c '%s %y %i' -- "${files[@]}")

unset RESTIC_PASSWORD RESTIC_PASSWORD_COMMAND RESTIC_REPOSITORY RESTIC_REPOSITORY_FILE
export RCLONE_CONFIG="$script_dir/rclone.conf"
export RCLONE_CONFIG_STORAGEBOX_KNOWN_HOSTS_FILE="$settings/storagebox-known-hosts"
export RCLONE_BWLIMIT=4M

log=$(mktemp /tmp/komodo-offsite-backup.XXXXXX)
if ! restic --no-cache --repo rclone:storagebox:restic/komodo-core --password-file "$settings/password" \
	-o "rclone.program=$rclone" backup --tag komodo-core --skip-if-unchanged -- "${files[@]}" >"$log" 2>&1; then
	echo "Komodo offsite backup failed; see restricted log: $log" >&2
	exit 1
fi
if [[ $(stat -c '%s %y %i' -- "${files[@]}") != "$before" ]]; then
	echo "Komodo backup archives changed during the offsite copy" >&2
	exit 1
fi
rm -f -- "$log"
echo "Komodo Core offsite backup succeeded"
