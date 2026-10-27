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
current implementation only calls Cloudflare's GET endpoints. Terraform-based
commands and their state are retained temporarily for rollback but should not
run automatic changes during the transition.

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

## Guarded direct API writes (manual approval only)

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

The supported writes in this first phase are:

- New self-hosted Access applications referencing existing reusable policies.
- New ingress routes cloned from the existing Komodo Traefik route, while
  retaining the complete existing Tunnel configuration and terminal 404.
- New proxied `ebi.nu` CNAMEs, **only after Access and Tunnel verification**.
- Updates to existing Docker-subnet `ygg.nu` A records, but not static devices.

This initial writer **does not support changing policies on existing Access
applications**. If any such change is proposed, the entire apply is rejected
rather than silently altering an existing application's other settings.
Deletes and Terraform writes are never supported. No Komodo schedule or
unattended apply is configured yet.

An interrupted apply is not rolled back: rerunning the live audit determines
which operations remain. Every operation is checked against current live
state. Avoid changing Cloudflare through Terraform or the dashboard during
an approved apply, particularly because updating a Tunnel configuration
replaces its entire remotely managed configuration.

The API token used for writes needs narrowly scoped Access application,
Tunnel and DNS permissions. Keep it out of source files and logs. Retain
your prior Terraform state and configuration as a migration reference until
the API-only approach has been validated on actual changes.
