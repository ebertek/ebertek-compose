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

# The following uses the existing deployment-side credentials.
# Never print, log, or commit their values.
set -a
source terraform/cloudflare/cloudflare.env
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
change. The temporary fallback for the private credential file remains until
its migration has been confirmed on Pleiades; it does not execute Terraform.

## Komodo scheduled audit

The "Cloudflare audit" Komodo action is scheduled every six hours. Its
cloudflare-audit.sh entrypoint runs as docker on Pleiades, sources the
owner-only `/home/docker/cloudflare/cloudflare.env` credential file (with a
temporary fallback to the legacy merged-checkout path), and runs
cloudflare-live.py when the opt-in marker is absent.
With the marker present it invokes cloudflare-manage.py --auto.

The action depends on `/home/docker/cloudflare/.venv`. Before removing the
legacy credential file from the private source repository, migrate it to the
runtime location using the following commands **on Pleiades as root**:

```bash
install -d -o docker -g docker -m 700 /home/docker/cloudflare
install -o docker -g docker -m 600 \
  /home/docker/ygg-compose/terraform/cloudflare/cloudflare.env \
  /home/docker/cloudflare/cloudflare.env
sudo -u docker test -r /home/docker/cloudflare/cloudflare.env
```

Never print or commit the token. The action prefers the runtime file, verifies
that it is owned by the executing user and mode `0600`, and warns when the
legacy fallback is used. Remove the legacy private-repository credential file
only after a successful Komodo run with the new path; avoid removing it from
`ygg-compose` manually.

Unattended mutation is **off by default**. To opt in deliberately, the docker
user can create an owner-only file outside the GitOps checkout:

```bash
install -d -m 700 /home/docker/cloudflare
printf 'enabled\n' > /home/docker/cloudflare/enable-auto
chmod 600 /home/docker/cloudflare/enable-auto
```

Only a maximum of three changes in one run are eligible, including guarded
existing Access policy updates. Remove that file to switch the scheduled
action back to read-only audit. The marker must be owned by the executing user
and inaccessible to other users. With the marker present, the scheduled
Komodo action performs bounded reconciliation every six hours. Audit the
resulting changes and do not enable automatic changes until validating the
deployed runtime credentials and Komodo action behavior.
