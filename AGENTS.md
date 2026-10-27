# Agent Instructions

This file is the repository-specific operating guide for AI assistants and
other automated contributors. Follow the user's requested scope, inspect the
current files before editing, and distinguish source-code changes from live
infrastructure operations. For security reporting, also read [SECURITY.md](SECURITY.md).

## Repository and deployment architecture

- **`ebertek/ebertek-compose` (this repository):** public source of Docker
  Compose stacks, scripts, Komodo resource definitions, nonsecret configuration,
  and CI workflows. Make changes here through reviewed branches/PRs.
- **`ebertek/ebertek-compose-secrets`:** separate private source of sensitive
  deployment configuration. Do not assume it can be read or written from this
  repository or from an assistant's GitHub permissions.
- **`ebertek/ygg-compose`:** a merged GitOps deployment repository assembled
  from the public and private sources. On Pleiades, it is checked out at
  `/home/docker/ygg-compose`. **It is not an editable source checkout.**
  Never edit tracked files in it, generate commits there, or assume separate
  public/private source clones exist on Pleiades.
- Komodo manages stacks across `pleiades.ygg.nu`, `ygg.ebi.nu`, and
  `hc.ebi.nu`. Stack ownership, servers, run directories, schedules, and
  GitOps actions are defined in [`komodo/resources.toml`](komodo/resources.toml).
  Do not assume all services run on the same host.
- Successful CI on a push to `main` can trigger a dispatch to the merged
  repository through [`.github/workflows/trigger-ygg.yml`](.github/workflows/trigger-ygg.yml).
  Source merging, deployment checkout updates, Komodo resource synchronization,
  and container recreation are **distinct steps**. A changed Compose label does
  not reach a running container until that service is redeployed.

Use explicit paths, users, and hosts in instructions. `~` changes meaning
under `sudo -s`: `/root` is not `/home/docker`. Run the Pleiades
Cloudflare scripts with the `docker` user's virtual environment and checkout.

## Change discipline

- Favor minimal changes, preserve established names, settings, and comments,
  and avoid sweeping refactors or unrelated reformatting.
- Do not deploy stacks, restart services, modify DNS/Access/Tunnels, update
  secrets, or execute destructive commands without explicit authorization.
  A request to change repository files is **not** permission for a production
  apply.
- For each change, identify its source owner and how it reaches production.
  Never write private configuration to this public repository.
- If a workflow cannot be validated locally, state precisely what remains
  unverified. Don't call a check green merely because it should pass.
- Do not create placeholder credentials, guessed resource IDs, fabricated
  service names, or speculative configuration entries.

## Docker Compose and networking

- Preserve anchors, profiles, external networks, static IP/MAC/IPv6 addresses,
  NFS dependencies, mount paths, restart policies, healthchecks, limits, and
  existing reverse-proxy middleware unless the task requires changing them.
- Never remove a persistent volume, database, or service data directory as a
  cleanup shortcut. Verify network reachability and dependencies before
  suggesting stack recreation.
- Respect image tag and digest pinning, Renovate restrictions, and upstream
  version semantics. Verify healthcheck commands exist in the target image,
  especially for Alpine/minimal/distroless images.
- For services exposed through Traefik, check the actual router
  `Host(`hostname`)` expression, entrypoint, TLS, middleware, and service
  port. Traefik accepts quoted `Host()` arguments; malformed rules must
  raise validation errors, not silently vanish from Cloudflare discovery.
- Public `*.ebi.nu` hostnames normally require `cf.access: "true"` and
  ordered `cf.access.policies` labels. Preserve the intended policy order;
  never infer that a named `bypass` policy is safe without inspecting its
  match conditions.

## Cloudflare controller: current source of truth

Read [`Scripts/cloudflare/README.md`](Scripts/cloudflare/README.md) and the
current implementation before modifying controller behavior.

- For Compose-managed applications, desired state comes from merged Compose
  labels; observed state comes from Cloudflare's APIs. Do not regenerate live
  desired state from Cloudflare alone.
- The direct API reconciler manages Access applications/policy references,
  `ebi.nu` Tunnel CNAMEs and ingress, and existing Docker-subnet `ygg.nu`
  A-record addresses. It must preserve unrelated and unmanaged resources.
- `cloudflare-live.py` is GET-only. `cloudflare-manage.py` defaults to
  planning, with `--preflight` for GET-only compatibility checks,
  `--apply <fingerprint>` for a reviewed manual write, and `--auto` for
  explicitly opted-in, bounded unattended operations.
- The scheduled Komodo action `Cloudflare audit` uses
  `Scripts/cloudflare/cloudflare-audit.sh`. **Do not infer its effects from
  its name:** without `/home/docker/cloudflare/enable-auto` it performs a
  GET-only audit; with the owner-only opt-in marker it invokes `--auto`.
  Check this mode before describing a run as read-only.
- Unattended mutations are restricted to a small allowlist and at most three
  operations per run. **Existing Access application policy updates remain
  manual-only**, even though a guarded PUT writer exists.
- A new app must be verified protected by Access before its Tunnel route and
  public DNS are published. Preserve the complete existing Tunnel
  configuration (`ingress`, `originRequest`, and `warp-routing` where
  present), including the terminal fallback. Treat unknown live fields and
  conflicting resources as blockers, not attributes to discard.
- Existing Access application changes use a full application PUT, not a
  policies-only PATCH. Verify the current API shape and all writable versus
  response-only fields; preserve app settings and require a controlled live
  validation before claiming this path safe for automation.
- Never automatically delete Cloudflare resources merely because a container
  or Compose hostname is absent.
- Older `terraform/cloudflare/` files and helper scripts are **migration/
  recovery references**, not the authoritative controller for new services.
  Do not run Terraform apply or enable simultaneous Terraform and API writers.
  Preserve any existing external Terraform state and backup information
  until a separate, approved retirement.
- Runtime Python dependencies are declared in
  `Scripts/cloudflare/requirements.txt`; the virtual environment belongs
  outside the merged checkout, presently at
  `/home/docker/cloudflare/.venv`. Do not use `pip --break-system-packages`
  or require extra local source repositories.

## Komodo, GitOps and shell scripts

- Review the relevant `komodo/resources.toml` action or procedure before
  changing schedules, server targets, terminal commands, execution order, or
  permissions. A Resource Sync definition is not proof that the action has
  been imported or run successfully.
- Distinguish a read-only audit from an action that applies changes. Preserve
  current safety gates, locks, exit-status propagation, and explicit opt-ins.
- The GitHub source API may create files as nonexecutable (`100644`). Shell
  entrypoints with a shebang must have executable Git mode (`100755`) where
  required by CI. Check `git ls-files -s` rather than removing shebangs just
  to satisfy an executable-bit lint rule.
- Use `set -Eeuo pipefail` where appropriate, quote expansions, and never
  echo tokens or full secret-bearing environment/configuration dumps.

## Security rules

- Follow [`SECURITY.md`](SECURITY.md). Never paste, commit, log, or reproduce
  credentials, private keys, API tokens, webhook URLs, cookies or private
  deployment secrets. Treat runtime credential files as sensitive even when
  located inside a merged checkout.
- The public repository must not contain private-repo file contents, secret
  state files, Terraform state, credential-bearing snapshots, or live API
  responses with sensitive fields.
- Apply least privilege to GitHub Actions, containers, Docker socket access,
  API tokens, Komodo terminals, and SSH. Do not weaken existing Access,
  Keycloak, Traefik, or network controls for convenience.
- Do not log sensitive payloads when debugging failures. Prefer resource
  counts, schema keys, status codes, and redacted diagnostics.
- Trivy's configured scans are currently scheduled/manual and use
  `exit-code: "0"`; a successful security workflow alone is **not** proof
  that there are no vulnerabilities. Review actual findings.

## Formatting and validation before pushing

Use [`.editorconfig`](.editorconfig), the existing formatter configuration,
and [`.github/workflows/lint.yml`](.github/workflows/lint.yml).
YAML/JSON/JavaScript/Markdown use two spaces; shell uses tabs (width four).
Do not suppress linters without a documented reason.

**Run local checks before committing or opening a PR whenever tooling is
available.** Repeatedly using a slow Super-Linter CI job as an iterative
formatter is avoidable. Prefer running the configured Black, Ruff, Pylint,
shfmt, ShellCheck and Prettier checks on changed files; inspect their current
versions/settings rather than guessing at defaults. At minimum, run relevant
commands such as:

```bash
python -m unittest discover -s Scripts/cloudflare -p 'test_cloudflare_*.py'
docker compose -f ygg-arr/compose.yaml config --quiet
npx prettier --check AGENTS.md SECURITY.md
git diff --check
git diff --stat
```

Additional relevant CI gates include Super-Linter, Docker Compose config
checks, Renovate validation, and the scheduled/manual security workflow.
Some Compose checks require environment variables or external files; don't
invent them when absent. Offline unit tests do **not** replace a GET-only
production preflight or an explicitly approved live write test.

## Completion and handoff

- Report source paths changed, rationale, security/runtime implications,
  tests actually run, and any missing validations.
- Distinguish GitHub PR creation, passing CI, merging, merged-repo sync,
  Komodo Resource Sync, and live deployment; none automatically proves the
  later step happened.
- Provide concrete, idempotent verification commands using the correct user
  and paths. Do not ask users to edit `ygg-compose` tracked files.
- When a deployment is already healthy, prefer observation and rollback
  planning to speculative extra infrastructure changes.
