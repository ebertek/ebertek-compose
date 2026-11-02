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

Cloudflare reconciliation and LAN inventory auditing are implemented in the
standalone [Yggflare](https://github.com/ebertek/yggflare) project. This
repository supplies declarative Compose labels and other service definitions.

Changes to Traefik Host rules, `cf.access` and `cf.access.policies` can affect
public exposure and authorization. Keep the desired Access policy order,
security middleware, and TLS behavior intact; never bypass authentication for
test convenience.

Production Cloudflare API credentials and private static-device inventories
must not be committed to this public repository. Yggflare's write safety,
backup/recovery controls, and audit logging are reviewed and tested in its
own source repository. Never run multiple automatic Cloudflare reconcilers
against the same resources.

The deployed merged `ygg-compose` checkout remains an immutable GitOps output;
all persistent source changes belong in their respective source repositories.
Deleting a Compose service does not authorize deletion of live DNS, Access or
Tunnel resources.

## CI and dependency scanning

GitHub's `Lint` workflow checks formatting, Compose parsing,
and Renovate configuration. The separate `Security`
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
