# Security Policy

## Scope and support

`ebertek/ebertek-compose` is a public source repository for a self-hosted
multi-host infrastructure: Docker Compose, GitHub Actions, Komodo resource
definitions, reverse-proxy/identity configuration, and automation scripts.

Security reports in scope include weaknesses **caused by this repository's
configuration or custom code**, for example:

- Unintended public exposure of a service, authentication or authorization
  bypass, or unsafe Cloudflare Access/Traefik/Tunnel policy handling.
- Credentials, private keys, tokens, or sensitive runtime material committed
  or exposed by workflows, logs, scripts, or repository artifacts.
- Unsafe automation permitting unintended DNS/Access/Tunnel changes,
  unapproved infrastructure writes, destructive cleanup, or privilege escalation.
- Insecure default permissions, unnecessary container capabilities, risky
  mounts or Docker socket exposure, and compromised CI/deployment boundaries.

For vulnerabilities solely in upstream software, Docker images, or third-party
actions, please also report them to the upstream maintainer. If a repository
choice or configuration makes an upstream issue exploitable here, it is also
appropriate to report that configuration risk privately.

Only the latest `main` branch is maintained. No formal security response,
remediation, or disclosure SLA is offered; reports are handled on a
best-effort basis.

## Report privately

**Do not open a public issue or pull request containing exploit details or
sensitive evidence.** Use GitHub's private vulnerability reporting feature
for this repository, if enabled. If that feature is unavailable, request a
private reporting route without sharing sensitive details in a public issue.

A useful private report includes:

- A concise description and affected files, services, versions, or revisions.
- The conditions required to reproduce the issue, realistic impact, and
  suggested remediation if known.
- A minimal proof of concept using sanitized test data, where safe.
- Whether any secret, privileged account, production deployment, or third
  party could be affected.

Do not send plaintext credentials or full private configuration/state files.
For secret exposure, identify the affected path and type of secret privately
without copying the value into the report.

Please do not run intrusive scans, denial-of-service tests, credential
attacks, exploitation against live endpoints, or modify production resources
without explicit authorization. Prefer harmless reproduction in a local or
isolated environment.

## Sensitive configuration and repository boundaries

This is a **public** repository. Private source configuration belongs in the
separate `ebertek/ebertek-compose-secrets` repository or in an appropriate
runtime secret store. The `ebertek/ygg-compose` repository merges public and
private inputs for deployment and is **not** an editable source repository.
Never copy merged private files back into the public source.

Protect, and never commit or print, the following:

- Cloudflare API tokens, OAuth/OIDC client secrets, service tokens and
  credentials, SSH keys, passwords, certificates' private keys, and webhook
  URLs.
- Private environment files (including the deployed Cloudflare credential
  file), Docker secrets, backups, database dumps, access cookies, and
  authorization headers.
- Terraform state, state backups, plan files, and Cloudflare exports that may
  contain secrets or internal topology. Treat generated recovery snapshots
  as sensitive unless reviewed and sanitized.

Use the minimum permissions needed for workflows, Cloudflare API tokens,
containers, SSH access, and Komodo actions. Keep authentication and network
isolation intact when adding public-facing services.

If a secret is exposed, treat it as compromised: revoke/rotate it in the
relevant provider, investigate any logs or artifacts, remove the exposure at
the source, and assess whether repository history or existing clones still
contain it. Deleting a file in a later commit does not erase it from history.

## Deployment and Cloudflare safety

Cloudflare API reconciliation is the intended controller for new
Compose-managed service hostnames. Desired application state comes from
Compose labels; live DNS, Access and Tunnel configuration is read from
Cloudflare. Legacy public Terraform HCL and Terraform-specific tooling have been removed
from active source; historical revisions remain in Git history. **Do not have
Terraform and the API reconciler write to the same resources concurrently.**

The following boundaries must be preserved:

- A new public hostname must have its intended Access application and
  ordered policies configured and verified before Tunnel ingress or public
  DNS make it reachable.
- Preserve existing Tunnel routes, origin options (including
  `warp-routing`), terminal fallback, and all unmanaged Cloudflare resources.
- Unknown live API fields or conflicting DNS/Access records must block writes.
  Never silently discard application settings when updating policies.
- Existing Access policy updates require a fresh-state check and validated
  full-application PUT. Unattended creation and policy updates additionally
  require at least one allow policy and exactly one final deny policy;
  unsafe changes are refused.
- The automated reconciler is **not** an automatic deletion mechanism.
  Disappearance from Compose does not authorize deletion from Cloudflare.
- Static non-Docker `ygg.nu` A record writes require the explicitly enabled,
  version-controlled private active-host inventory. The controller validates
  the planned /27 address boundaries, refuses proxied/CNAME/undeclared-extra
  conflicts, re-reads current record identity before writing, and verifies
  results. Only explicitly declared `additional_ipv4` companion A records
  may coexist with the primary; they are never written or removed. Updates modify only the IPv4 content; creation uses unproxied A
  records. A blocked static hostname does not authorize overwriting it.
  Unmanaged, reserved, and retired devices must never be changed or deleted
  automatically. Keep MACs, serials, device descriptions, purchase dates and
  port inventories private; no such metadata enters Cloudflare writes.
- `Scripts/cloudflare/cloudflare-live.py` and
  `cloudflare-manage.py --preflight` are GET-only. The manual
  `cloudflare-manage.py --apply` path performs reviewed writes; the
  `--auto` path can perform bounded, allowlisted writes if explicitly
  enabled.
- The Komodo action named **Cloudflare audit** does **not** always mean
  read-only: its deployed entrypoint switches to `--auto` only when
  `CF_AUTO_APPLY=true` is explicitly set in the **private**
  `Scripts/cloudflare/cloudflare.env`. Unset or `false` is GET-only;
  invalid values abort. Restrict access to that file and audit logs; set
  `CF_AUTO_APPLY=false` to disable unattended writes.
- Preserve encryption and recoverability of any retained private Terraform
  state and Cloudflare recovery exports. Do not treat live API configuration
  as a complete backup: it may not recover unretrievable secrets after loss
  of the Cloudflare account. The scheduled action reads the merged private
  `/home/docker/ygg-compose/Scripts/cloudflare/cloudflare.env` (sourced from
  `ebertek-compose-secrets`); the public repository must never contain it.

For implementation details and validation commands, see
[`Scripts/cloudflare/README.md`](Scripts/cloudflare/README.md).

## CI and dependency scanning

GitHub's `Lint` workflow checks formatting, Compose parsing,
Cloudflare Python tests, and Renovate configuration. The separate `Security`
workflow performs scheduled or manually initiated Trivy repository and image
scans. At present the Trivy jobs use `exit-code: "0"`: scan findings
require human review and do not necessarily fail the workflow.

Keep CI workflow permissions least-privileged and avoid exposing secrets to
untrusted pull requests. Do not log authentication headers, full environment
files, or Cloudflare mutation payloads. Treat logs and generated artifacts as
potentially sensitive even if GitHub Actions reports success.

## Disclosure and remediation

Please allow a reasonable opportunity to investigate and remediate a
privately reported issue before publishing technical details. Coordinated
disclosure timing is handled case by case; no response-time guarantees are
made. Reports, fixes, and security-impacting changes should be assessed for
necessary credential rotation, configuration rollback, and regression tests.
