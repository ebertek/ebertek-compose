#!/usr/bin/env bash
# Run Cloudflare Terraform from the merged ygg-compose checkout.
set -euo pipefail

readonly CONFIG_DIR="${HOME}/ygg-compose/terraform/cloudflare"
readonly ENV_FILE="${CONFIG_DIR}/cloudflare.env"
readonly STATE_DIR="${HOME}/terraform-state/cloudflare"
readonly BACKEND_STATE="${STATE_DIR}/terraform.tfstate"
readonly PROVIDER_CONFIG="${HOME}/cloudflare-provider-dev/policy-fix.tfrc"
readonly PROVIDER_BINARY_DIR="${HOME}/cloudflare-provider-dev/policy-fix"

fail() {
	printf 'ERROR: %s\n' "$*" >&2
	exit 1
}

usage() {
	cat <<'USAGE'
Usage: cloudflare-terraform.sh <terraform-command> [arguments...]

Examples:
  cloudflare-terraform.sh plan
  cloudflare-terraform.sh validate
  cloudflare-terraform.sh state list
  cloudflare-terraform.sh plan -detailed-exitcode
  cloudflare-terraform.sh apply --allow-apply <reviewed-plan-file>

The apply and destroy commands are blocked by default. For an intentional
apply, pass --allow-apply immediately after 'apply' and provide a saved plan
file; no direct or automatic apply is permitted. Destroy remains blocked.
USAGE
}

[[ $# -gt 0 ]] || {
	usage >&2
	exit 2
}
case "$1" in
-h | --help | help)
	usage
	exit 0
	;;
destroy | force-unlock | import | state | apply | plan | validate | fmt | show | output | providers | version | init | refresh | console | graph | test) ;;
*) fail "Unsupported Terraform command: $1" ;;
esac

command_name="$1"
shift

if [[ "$command_name" == destroy || "$command_name" == refresh ]]; then
	fail "'$command_name' is blocked. Use a reviewed plan and explicit apply procedure."
fi

if [[ "$command_name" == apply ]]; then
	[[ "${1:-}" == --allow-apply ]] || fail "Apply requires: apply --allow-apply <saved-plan-file>"
	shift
	[[ $# -eq 1 && "$1" != -* && -f "$1" ]] || fail "Apply requires one existing saved plan file."
fi

# Block state-changing subcommands; state list/show/pull remain available.
if [[ "$command_name" == state ]]; then
	case "${1:-}" in
	list | show | pull) ;;
	*) fail "Only read-only state list/show/pull are supported by this wrapper." ;;
	esac
fi

[[ -d "$CONFIG_DIR" ]] || fail "Missing merged Terraform configuration: $CONFIG_DIR"
[[ -r "$ENV_FILE" ]] || fail "Missing readable credentials file: $ENV_FILE"
[[ -f "$BACKEND_STATE" ]] || fail "Missing persistent state: $BACKEND_STATE"
[[ -r "$PROVIDER_CONFIG" ]] || fail "Missing provider override: $PROVIDER_CONFIG"
[[ -d "$PROVIDER_BINARY_DIR" ]] || fail "Missing patched provider directory: $PROVIDER_BINARY_DIR"

# Credentials are intentionally stored as shell exports in the private repo.
# shellcheck disable=SC1090
source "$ENV_FILE"
[[ -n "${CLOUDFLARE_API_TOKEN:-}" ]] || fail "CLOUDFLARE_API_TOKEN is not set by $ENV_FILE"
export CLOUDFLARE_API_TOKEN
export TF_CLI_CONFIG_FILE="$PROVIDER_CONFIG"
export TF_DATA_DIR="$STATE_DIR/.terraform"

mkdir -p "$TF_DATA_DIR"
chmod 700 "$TF_DATA_DIR"

# Explicitly set the working directory; don't rely on caller location.
cd "$CONFIG_DIR"
exec terraform "$command_name" "$@"
