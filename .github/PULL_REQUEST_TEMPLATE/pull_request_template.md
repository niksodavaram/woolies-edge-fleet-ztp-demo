## Summary

<!-- What does this PR change? One paragraph. -->

## Change type

- [ ] 🏗️ Day 0 — Golden image / blueprint change
- [ ] 🤖 Day 1 — Ansible bootstrap / hardening change
- [ ] ☸️ Day 1.5 — OpenShift / MicroShift manifest change
- [ ] 📦 Day 2 — Workload / app change
- [ ] 🔐 Day 3 — GitOps / secrets / governance change
- [ ] 🗺️ Migration — Phase or wave config change
- [ ] 📚 Docs / ADR only

## Layers affected

- [ ] `00-provisioning/` — image build pipeline
- [ ] `01-bootstrap/` — Ansible fleet bootstrap
- [ ] `02-infrastructure/` — OpenShift / MicroShift
- [ ] `03-workloads/` — store workloads
- [ ] `04-secrets-cicd/` — GitOps + secrets ⚠️ _requires security review_
- [ ] `05-migration/` — migration phases / wave config

## Migration phase impact

Current phase: <!-- P0 | P1 | P2 | P3 | P4 -->

- [ ] image.toml `current_phase` updated (if phase advancing)
- [ ] `kubevirt_bridge` flag correct for this phase
- [ ] Wave definition updated if rollout scope changes
- [ ] Rollback procedure documented in `05-migration/rollback/`

## Testing done

- [ ] `packer validate` / `ksvalidator` passes locally
- [ ] `ansible-lint` passes locally (`ansible-lint site-bootstrap.yml`)
- [ ] `kubeconform` passes on changed manifests
- [ ] `shellcheck` passes on changed shell scripts
- [ ] `pre-commit run --all-files` passes
- [ ] Tested on lab MicroShift node (store tier: <!-- supermarket | metro | liquor -->)
- [ ] greenboot health check still passes after change

## Security checklist

- [ ] No secrets, passwords or tokens committed to Git
- [ ] All credentials fetched from Vault via External Secrets Operator
- [ ] SELinux policy not weakened (`setenforce 0` never acceptable)
- [ ] CIS hardening controls not reduced
- [ ] If `04-secrets-cicd/` changed: security team reviewer added

## Blast radius

Estimated stores affected by this change: <!-- e.g. "all 3,000" | "NSW supermarkets only" | "none — docs only" -->

Rollback plan:
<!-- How do we undo this if it goes wrong? e.g. "git revert + ArgoCD sync" | "ostree rollback" | "re-run previous wave" -->

## Related

- Jira: `EDGEPLT-`<!-- ticket number -->
- ADR: <!-- link if this change requires a new or updated ADR -->
- Runbook: <!-- link to 05-migration/phases/ if phase advancing -->
