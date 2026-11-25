#!/bin/sh
# Install private GitOps credential files for Yggflare without logging contents.
# Invoked from the ygg-core run directory by Komodo before deployment.
set -eu
umask 077

source_dir=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
config_dir=/volume2/docker/yggflare/config

fail() {
  printf '%s\n' 'Yggflare credential preparation failed; check private files and config permissions.' >&2
  exit 1
}

[ -d "$config_dir" ] && [ ! -L "$config_dir" ] || fail

# Validate every source before replacing any installed credential.
for name in komodo_api_key komodo_api_secret kuma_api_key; do
  source_file="$source_dir/yggflare_${name}.txt"
  [ -f "$source_file" ] && [ ! -L "$source_file" ] && [ -s "$source_file" ] || fail
  chmod 600 "$source_file" || fail
done

stage=$(mktemp -d "$config_dir/.yggflare-credentials.XXXXXX") || fail
trap 'rm -rf -- "$stage"' EXIT
trap 'exit 1' HUP INT TERM

install -m 600 "$source_dir/yggflare_komodo_api_key.txt" "$stage/komodo-api-key.txt" || fail
install -m 600 "$source_dir/yggflare_komodo_api_secret.txt" "$stage/komodo-api-secret.txt" || fail
install -m 600 "$source_dir/yggflare_kuma_api_key.txt" "$stage/kuma-api-key.txt" || fail

for name in komodo-api-key.txt komodo-api-secret.txt kuma-api-key.txt; do
  # Reject unexpected existing directories or symlinks instead of following them.
  target="$config_dir/$name"
  [ ! -L "$target" ] || fail
  if [ -e "$target" ]; then
    [ -f "$target" ] || fail
  fi
done

for name in komodo-api-key.txt komodo-api-secret.txt kuma-api-key.txt; do
  mv -fT -- "$stage/$name" "$config_dir/$name" || fail
done

printf '%s\n' 'Yggflare integration credentials prepared with mode 0600.'
