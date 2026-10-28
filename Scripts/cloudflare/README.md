# Cloudflare reconciliation on Pleiades

The merged `~/ygg-compose` checkout is read-only. Cloudflare audit commands
read its Compose files and query Cloudflare directly. The live audit does not
write to Cloudflare, Git, or Terraform.

## One-time Python environment

Create a virtual environment outside the GitOps checkout:

```bash
python3 -m venv ~/cloudflare/.venv
~/cloudflare/.venv/bin/python -m pip install \
  -r ~/ygg-compose/Scripts/cloudflare/requirements.txt
```

If that directory is removed, repeat these commands. No persistent Cloudflare
configuration is stored in the virtual environment.

## Run

```bash
cd ~/ygg-compose
~/cloudflare/.venv/bin/python -m unittest discover \
  -s Scripts/cloudflare -p 'test_cloudflare_*.py'

# The following reads credentials from the merged private GitOps source.
# Never print, log, or commit their values.
set -a
source Scripts/cloudflare/cloudflare.env
set +a

~/cloudflare/.venv/bin/python Scripts/cloudflare/cloudflare-live.py
```

`cloudflare-live.py` requires `CLOUDFLARE_API_TOKEN` in the environment. Its
current implementation only calls Cloudflare's GET endpoints. The API
controller is the only active Cloudflare writer; legacy Terraform tools and
tracked configuration were retired. Preserve encrypted/offline Terraform state
backups separately from this public repository.

## Human-readable reusable Access policy labels

Compose services can declare the **exact Cloudflare reusable policy names**
in `cf.access.policies`, in the intended evaluation order:

```yaml
cf.access: "true"
cf.access.policies: '["2-Home","3-Whitelist","5-Keycloak","Block"]'
```

The controller fetches the account's reusable Access policies on each audit,
resolves names to their UUIDs, and continues using ordered UUIDs for drift
comparison, approval fingerprints, and API writes. There is no extra mapping
file or local policy cache. Existing UUID entries and mixed UUID/name labels
are supported for migration.

Policy names are matched **exactly** (including case and whitespace). A
missing or ambiguous name, an unknown UUID, or duplicate resolved policy
assignment aborts reconciliation before any writes. Renaming a policy in
Cloudflare therefore requires updating its Compose label. Do not assume
Cloudflare Access policy names are unique.

After converting existing labels, run the read-only live audit and confirm
that zero Access policy changes are proposed **before** enabling or allowing
scheduled writes. The private deployment merge must synchronize these source
changes before the new names are used. Existing policy updates and new Access application creation are eligible for
unattended reconciliation only when the allow and final deny guards validate. Unexpected
name-to-ID mismatches must be investigated, not approved blindly.

## Validate live onboarding compatibility before creating any service

Once the read-only audit reports no drift, run a separate read-only preflight:

```bash
cd ~/ygg-compose
~/cloudflare/.venv/bin/python \
  Scripts/cloudflare/cloudflare-manage.py --preflight
```

This fetches the actual Komodo Access application, the existing `ebi.nu`
Tunnel CNAME, and the complete remotely managed Tunnel configuration. It
requires the trusted `komodo.ebi.nu` ingress route to use the expected
Traefik service, checks that the 404 fallback and Access policies are
well-formed, and verifies that the CNAME points to the selected Tunnel.

This preflight uses **GET requests only** and reports counts and structural
checks, not credentials, origin settings or full API responses. It can reveal
live configuration differences that fake API tests cannot. A successful
preflight does not prove that a future Cloudflare POST or PUT will succeed;
the first real change should still be explicitly reviewed.

## Guarded direct API writes

The live audit remains GET-only. The separate `cloudflare-manage.py` command
first runs the same live audit, prints a plan, and outputs a fingerprint.
It will not change anything unless `--apply` is explicitly provided with
that fingerprint.

```bash
cd ~/ygg-compose
~/cloudflare/.venv/bin/python Scripts/cloudflare/cloudflare-manage.py

# Review the output carefully. Apply only if you intend the listed changes:
~/cloudflare/.venv/bin/python Scripts/cloudflare/cloudflare-manage.py \
  --apply <reviewed-16-character-fingerprint>
```

Use the fingerprint printed by the dry run, without angle brackets.
The apply command takes an exclusive lock outside `ygg-compose`, fetches live
Cloudflare configuration again, and rejects a changed plan. It applies only
allowlisted operations and re-reads each changed resource afterward.

The supported API writes are:

- New self-hosted Access applications referencing existing reusable policies.
- New ingress routes cloned from the existing Komodo Traefik route, while
  retaining the complete existing Tunnel configuration and terminal 404.
- New proxied `ebi.nu` CNAMEs, **only after Access and Tunnel verification**.
- Updates to existing Docker-subnet `ygg.nu` A records, but not static devices.

Existing Access policy changes use validated full-application PUT requests.
Unknown live application settings are rejected, not discarded. Deletes and
Terraform writes are never supported. Scheduled Komodo work is read-only
unless its explicit external enable-auto marker is present.

An interrupted apply is not rolled back: rerunning the live audit determines
which operations remain. Every operation is checked against current live
state. Avoid changing Cloudflare through Terraform or the dashboard during
an approved apply, particularly because updating a Tunnel configuration
replaces its entire remotely managed configuration.

The API token used for writes needs narrowly scoped Access application,
Tunnel and DNS permissions. Keep it out of source files and logs. Historical
Terraform source remains recoverable from Git history; preserve any previous
sensitive Terraform state or exports in a protected backup outside Git.

## Static non-Docker DNS inventory (read-only)

The Cloudflare audit can also verify explicitly declared, non-Docker
`*.ygg.nu` IPv4 records. The inventory belongs in the **private**
`ebertek-compose-secrets` source repository, at
`Scripts/cloudflare/static-hosts.json`. It is merged into
`/home/docker/ygg-compose/Scripts/cloudflare/static-hosts.json` alongside
the private `cloudflare.env`. Never put your real device inventory or
MAC addresses in this public repository.

The format is versioned JSON. This is an **illustrative** entry, not a real
device or a record to create:

```json
{
  "version": 1,
  "hosts": [
    {
      "hostname": "example-device.ygg.nu",
      "ipv4": "10.4.20.10",
      "mac": "02:00:00:00:00:10",
      "description": "Example device model and notes",
      "serial_number": "SAMPLE-123",
      "purchase_date": "2023-01-26",
      "open_ports": [80, 443]
    }
  ]
}
```

Each entry requires a unique, lowercase, single-label `*.ygg.nu` hostname
and a canonical IPv4 address in the `10.4.20.0/24` **allocation region**.
The LAN itself remains `10.4.20.0/23`; the inventory reserves every
planned `/27` network and broadcast address (for example, `.64` and `.95`)
so future segmentation remains possible. `mac` is optional and accepts colon
or hyphen separators,
and is **metadata only**: the reconciler never uploads it to Cloudflare,
uses it to infer ownership, or prints it in audit reports. Multiple DNS
hostnames may point to the same device address. Optional `description`
accepts a device model and notes (up to 512 characters), is validated as
private metadata, and is never included in DNS requests or audit output.
Additional optional inventory-only fields are `serial_number` (a nonempty
string), `purchase_date` (a real date in `YYYY-MM-DD` format), and
`open_ports` (an array of distinct numeric ports, each 1-65535). Omit a
field if its value is unknown. `open_ports: []` means no ports recorded,
which is different from never having collected port information. These are
user-reported observations, **not live port scans**; no TCP/UDP transport
or reachability is inferred from the port numbers.

All of these fields stay in the private GitOps inventory and are stripped
before comparison with Cloudflare: only hostname and IPv4 address are used
for DNS drift detection. Use JSON string fields rather than comments, which
JSON does not support. Do not include Docker `10.4.21.0/24` addresses.

Keep non-live records separately in the private source:
`static-hosts-reserved.json` for reserved/disconnected or not-yet-purchased
devices, and `retired-devices.json` for formerly owned equipment (including
records with no known hostname or IP). Neither file is read by the Cloudflare
controller, so it cannot accidentally provision historical devices.

With the file present, each audit compares inventory entries with the
existing Cloudflare `ygg.nu` DNS snapshot. It reports missing entries,
stale IPv4 addresses, duplicate A/CNAME conflicts, and improperly proxied
A records. Extra AAAA records and hostnames not in the inventory are
preserved. **This phase makes no static DNS changes, creates no records,
and never deletes anything.** An entry with drift causes the read-only
CLI to exit nonzero, but unattended reconciliation only logs static drift;
it can still safely reconcile independent Docker, Access, and Tunnel changes.
The separate `static-hosts-reserved.json` file (if maintained in the private
source) is planning documentation, not an input to the live audit.

The file is optional during the initial migration, so existing Komodo
reconciliation keeps working before the private inventory is ready. After
the complete inventory has been reviewed and merged, configure
`"static_dns_required": true` in the public
`Scripts/cloudflare/cloudflare-settings.json`, which makes a missing
private file a hard error. Do not enable this flag before synchronizing
the private source on Pleiades.

To inspect the read-only result without invoking unattended writes:

```bash
cd ~/ygg-compose
set -a
source Scripts/cloudflare/cloudflare.env
set +a
~/cloudflare/.venv/bin/python Scripts/cloudflare/cloudflare-live.py
```

The active static inventory covers **Cloudflare DNS expectations**, not DHCP
reservations or device discovery. The inventory intentionally omits disconnected
interfaces and devices not yet purchased, to avoid false missing-DNS findings. Network-device ownership and MAC/IP
assignment should be checked against the original device list before
considering any automatic static DNS mutations in a later phase.

## Existing Access policy changes

The guarded writer supports changing the ordered reusable policies of an
existing self-hosted application. It fetches the complete application,
verifies its ID, hostname, and old policy order, and refuses to write if the
API returns an unrecognized setting. For supported settings it uses the
full-application PUT and rechecks policies afterward.

A controlled live update to Unpackerr succeeded, followed by zero-drift
verification. With the external enable-auto marker present, creation of new
Access applications and updates to existing applications may run unattended,
subject to all of these gates:

- At most three total approved operations per run, including policy updates.
- Updates require exact live identity, application ID, and previous policy
  order; creation requires the hostname not to exist already.
- Every desired reusable policy must still exist and have a known decision.
- The desired policy list must contain at least one `allow` policy and end
  with exactly one `deny` policy for **both new and existing** Access apps.
  New apps are refused if these requirements are not met.
- The full-application PUT rejects unrecognized app settings and re-reads
  the application to verify the resulting order. Newly created Access apps
  have their policy decisions checked again immediately before POST.

Updates that fail these checks can still be reviewed with a manual approval
fingerprint; the automatic controller does not bypass its safety checks.
Any policy assignment change can affect access immediately. Review Compose
changes carefully before merging; a green audit is not an authorization review.

## Terraform retirement (October 2026)

The public repository no longer ships Terraform modules, a Terraform runner,
or the HCL/state-based import and source-sync helpers. Cloudflare changes are
made by the guarded API reconciler and driven by Compose labels. Terraform
must **not** be run concurrently against the same resources.

The legacy public HCL files can be retrieved from Git history at commit
`9545a6f4172822584c20f52da9c7e76bfe5d2cf0`, if needed for a manual
recovery investigation. This is not a substitute for a secured copy of the
**private** Terraform state and the private repository's configuration.
Neither sensitive state nor private secrets were exported or deleted by this
change. The Cloudflare credential file remains in the merged GitOps checkout
at `Scripts/cloudflare/cloudflare.env`, supplied by the private source repo.

## Komodo scheduled audit

The "Cloudflare audit" Komodo action runs every six hours as the `docker`
user on Pleiades. Its entrypoint, `Scripts/cloudflare/cloudflare-audit.sh`,
reads `/home/docker/ygg-compose/Scripts/cloudflare/cloudflare.env`. This
file must be supplied by the **private** `ebertek-compose-secrets` repository
at `Scripts/cloudflare/cloudflare.env`. Do not add credentials to the
public `ebertek-compose` repository or commit changes directly to the
merged `ygg-compose` checkout.

The existing environment variables are supported: `CF_API_TOKEN` (or
`CLOUDFLARE_API_TOKEN`), `CF_ACCOUNT_ID`, `CF_TUNNEL_ID`,
`CF_ZONE_EBI_NU`, and `CF_ZONE_YGG_NU`. The action exports the corresponding
`CLOUDFLARE_*` names for the Python controller. `CF_ZONE_EBERTEK_COM` may
remain in the private file but is not consumed by this reconciler.

The credential file must be readable by `docker` and should not be
accessible to unrelated users. Ensure its private-source deployment preserves
appropriate permissions. The runner refuses to start if the file is missing
or unreadable; it has no fallback to the old Terraform directory or an
external copy. Validate that the file is present after the next GitOps merge:

```bash
sudo -u docker test -r /home/docker/ygg-compose/Scripts/cloudflare/cloudflare.env
```

The action uses `/home/docker/cloudflare/.venv` for its Python environment.
Without the opt-in marker it executes the GET-only live audit; with the
owner-only marker it executes `cloudflare-manage.py --auto`. The opt-in marker
remains outside the GitOps checkout:

```bash
install -d -m 700 /home/docker/cloudflare
printf 'enabled\n' > /home/docker/cloudflare/enable-auto
chmod 600 /home/docker/cloudflare/enable-auto
```

Only a maximum of three changes per run are eligible, including guarded
Access application creation and existing policy updates. Removing the marker
returns the scheduled action to GET-only mode. The marker must be owned by
the executing user and inaccessible to other users. Review the next Komodo
action output after synchronizing the private credential path.
