# Agent Instructions

## Repository Overview

This repository contains Docker Compose deployments and supporting configuration for the Ygg self-hosted infrastructure.

The infrastructure includes containerized applications, networking, reverse proxies, monitoring, automation, and security services.

Changes must prioritize reliability, security, reproducibility, and compatibility with existing deployments.

## General Principles

- Prefer minimal, targeted changes over broad refactoring.
- Preserve existing configuration conventions and service names.
- Do not introduce unnecessary dependencies, services, or helper files.
- Do not modify unrelated services or configurations.
- Do not assume that development, CI, and production environments are identical.
- Do not make deployment changes or restart running services without explicit authorization.
- Explain changes that affect runtime behavior, security, networking, or persistent data.

## Docker Compose

- Follow the existing Compose specification and repository conventions.
- Preserve YAML anchors, aliases, profiles, networks, and volume definitions.
- Respect static IP addresses, MAC addresses, IPv6 assignments, and network modes.
- Preserve resource limits, reservations, restart policies, healthchecks, and logging settings unless a change is explicitly required.
- Do not replace pinned image versions or digests with floating tags.
- Prefer upstream-supported application healthchecks over process-only checks where available.
- Verify that proposed healthcheck commands and utilities exist in the target image.
- Do not assume that minimal or distroless images contain a shell.
- Never remove persistent volumes or introduce destructive maintenance commands without explicit authorization.

## Formatting and Linting

- Follow `.editorconfig`, `.gitattributes`, and repository-specific formatter settings.
- Preserve the existing `.vscode/settings.json` language associations.
- YAML, JSON, and JavaScript use two-space indentation.
- Shell scripts use tabs with a tab width of four.
- Respect the repository's existing Prettier configuration.
- Maintain compatibility with Super-Linter v9 defaults.
- Do not disable linting rules or add suppression comments merely to silence warnings without justification.
- Do not reformat unrelated files.

## Dependencies and Renovate

- Prefer official upstream container images and documented image tags.
- Preserve Renovate package rules, versioning strategies, and update restrictions.
- Do not introduce major-version upgrades unless explicitly requested.
- Validate Renovate configuration changes.
- Distinguish Docker image tags from application versions.
- Do not assume that a newer tag represents a compatible release.

## Security

- Never commit credentials, access tokens, private keys, or other sensitive values.
- Do not print secrets into CI logs or diagnostic output.
- Respect existing Docker secrets, environment files, and authentication mechanisms.
- Apply least privilege to GitHub Actions permissions and container capabilities.
- Do not introduce privileged containers, host networking, or Docker socket access without explaining the security implications.
- Do not suppress Gitleaks, Trivy, or other security findings without documenting the reason.
- Preserve existing network isolation and authentication requirements.

## GitHub Actions

- Follow existing workflow naming and formatting conventions.
- Use official or well-maintained GitHub Actions where practical.
- Prefer immutable action references where practical.
- Apply least-privilege workflow permissions.
- Avoid introducing redundant workflows or duplicate validation.
- Ensure commands work in GitHub-hosted Ubuntu runners.
- Keep validation jobs independent of production secrets wherever possible.

## Validation

Before completing a change, perform applicable checks:

1. Validate YAML and formatting against the existing repository configuration.
2. Run `docker compose config --quiet` for affected standalone Compose files when required environment files and variables are available.
3. Validate Renovate configuration when modified.
4. Run applicable linting and security checks when available.
5. Review the diff for unrelated changes, exposed secrets, and unintended runtime effects.

Never claim validation succeeded unless the checks were actually executed.

When validation cannot be performed, explain what remains unverified.

## Reporting Changes

Summarize:

- What changed and why.
- Any compatibility or security implications.
- Which validation checks passed.
- Any remaining risks or manual deployment steps.
