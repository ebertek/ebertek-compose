#!/usr/bin/env bash
set -euo pipefail

export LC_ALL=C
backup_root=${1:?Specify the Komodo backup directory}
latest=

for candidate in "$backup_root"/????-??-??_??-??-??; do
	if [[ -d "$candidate" && ! -L "$candidate" && ${candidate##*/} =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}_[0-9]{2}-[0-9]{2}-[0-9]{2}$ ]]; then
		latest=$candidate
	fi
done

if [[ -z "$latest" ]]; then
	echo "No dated Komodo Core backup found" >&2
	exit 1
fi

age=$(($(date +%s) - $(stat -c %Y -- "$latest")))
if ((age < 0 || age >= 86400)); then
	echo "Latest dated Komodo Core backup is outside the 24-hour freshness window" >&2
	exit 1
fi

for collection in Action Procedure Repo Server Stack Update User Variable; do
	if [[ ! -s "$latest/$collection.gz" ]]; then
		echo "Latest Komodo Core backup is missing the $collection archive" >&2
		exit 1
	fi
done

gzip -t -- "$latest"/*.gz
if [[ ${2:-} == --print-path ]]; then
	printf '%s\n' "$latest"
else
	echo "Latest dated Komodo Core backup is fresh and its gzip files passed integrity checks"
fi
