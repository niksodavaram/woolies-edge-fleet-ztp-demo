# Contributing to woolies-edge-fleet-ztp-demo

Thanks for taking the time to contribute. This repo is a **reference edge
platform** (Day 0–4, ZTP, GitOps, Vault, MQTT/DDS, MCP) rather than a
product, so we keep changes small, reviewable, and well-documented. [web:186][web:191]

## Workflow

- Work from the latest `main` branch.
- Create a feature branch:
  - `feature/<short-name>` for new capabilities.
  - `fix/<short-name>` for bug fixes.
  - `docs/<short-name>` for documentation only.

## Commit messages

- Use **Conventional Commits** style where possible:
  - `feat: add mqtt iot workload`
  - `fix: correct store-001 network overlay`
  - `docs: clarify day0-to-day4 flow`
- Keep commits focused and small; avoid mixing unrelated changes.

## Pull requests

- Ensure local checks pass before opening a PR:
  - `pre-commit run --all-files` (YAML + Ansible lint).
- In your PR description, include:
  - **Context**: what problem you’re solving.
  - **Scope**: which layer(s) you touched (Day 0, Day 1, Day 1.5, Day 2, Day 3+).
  - **Risk**: any impact to existing flows or examples.

## Style and structure

- Do not hard-code secrets or tokens; always use Vault paths and ExternalSecrets.
- Keep folder structure consistent with existing layout:
  - `00-provisioning/`, `01-bootstrap/`, `02-infrastructure/`, `03-workloads/`, `04-secrets-cicd/`, `docs/`.
- Update documentation when you add or change behaviour:
  - README, ADRs, or relevant file under `docs/`.

## Reviews

- At least one review from a **platform**-style owner is required for:
  - `00-`, `01-`, `02-`, or `04-` changes.
- Security-sensitive changes (Vault, ESO, SCC, SCC-related MachineConfigs)
  should be explicitly tagged for security review.

By contributing, you confirm you have the right to submit the code and are
comfortable with it being used as reference architecture material.