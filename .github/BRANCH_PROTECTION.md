# Branch protection and GitOps governance

## Branch strategy

```
main                    ← production-ready · protected · requires PR
├── feature/EDGEPLT-*   ← new capabilities
├── fix/EDGEPLT-*       ← bug fixes
├── security/*          ← CVE patches (fast-track)
└── migration/phase-*   ← migration phase runbooks
```

## Branch protection rules for `main`

Configure in: **Settings → Branches → Add rule → Branch name pattern: `main`**

| Rule | Setting | Why |
|---|---|---|
| Require a pull request | ✅ Enabled | All changes reviewed |
| Required approvals | **2** (platform team) | Fleet touches 3,000 stores |
| Dismiss stale reviews | ✅ Enabled | Re-review after each push |
| Require review from code owners | ✅ Enabled | CODEOWNERS enforced |
| Require status checks | ✅ All 5 CI jobs must pass | No broken image ships |
| Require branches up to date | ✅ Enabled | No stale merges |
| Restrict who can push | platform-team only | No direct pushes |
| Require signed commits | ✅ Enabled | Image provenance |
| Allow force pushes | ❌ Disabled | Immutable history |
| Allow deletions | ❌ Disabled | Never delete main |

## Required status checks (must all pass before merge)

```
✅ validate-blueprint        (image.toml TOML syntax + migration metadata)
✅ ansible-lint              (Ansible production profile)
✅ validate-manifests        (kubeconform on all YAML)
✅ security-scan / secret-detection
✅ compliance-check          (CIS controls in blueprint)
```

## Environment protection rules

### `image-build` environment
- Required reviewers: platform-team (1 approval)
- Deployment branches: main only
- Wait timer: 5 minutes (allows cancel if error noticed)
- Secrets: `REGISTRY_PASSWORD`, `COSIGN_PRIVATE_KEY`

### `fleet-sync` environment
- Required reviewers: platform-team (2 approvals)
- Deployment branches: main only
- Wait timer: 10 minutes
- Secrets: `ARGOCD_AUTH_TOKEN`, `THANOS_QUERY_URL`
- Prevents: parallel deployments via concurrency group

## CODEOWNERS

```
# All files — platform team
*                         @woolies/platform-team

# Security-sensitive — security team co-review
00-provisioning/*/        @woolies/platform-team @woolies/security-team
04-secrets-cicd/*         @woolies/platform-team @woolies/security-team

# Migration runbooks — store ops co-review
05-migration/*            @woolies/platform-team @woolies/store-ops

# ADRs — platform team + architect
docs/adrs/*               @woolies/platform-team @woolies/architects
```

## Why this governance model matters

This is infrastructure as product — not a ticket queue.
Every change to the fleet goes through:

1. **Developer** raises PR with conventional commit message
2. **pre-commit** catches issues locally before push
3. **CI pipeline** runs 5 parallel quality gates automatically
4. **Code owner review** by platform team (2 approvals for main)
5. **Environment approval** gates before image publish or fleet sync
6. **ArgoCD** reconciles continuously — Git is always the source of truth

A bad config that slips through can affect 3,000 stores simultaneously.
The governance model is proportional to that blast radius.
