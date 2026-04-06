# tests/godog/features/migration.feature
Feature: Phased Windows-VMware to RHEL9/MicroShift Migration
  As a WooliesX platform engineer
  I want a controlled A/B migration with the KubeVirt bridge keeping POS trading
  So that no store experiences downtime during the Windows-to-Linux cutover

  Background:
    Given store "NSW-042" is in migration phase "P1"
    And the KubeVirt bridge flag is "true" in image.toml
    And the legacy Windows VM is running on the same node

  Scenario: P1 — Parallel running: Windows VM and MicroShift coexist
    When MicroShift starts on the RHEL9 host
    Then the KubeVirt Windows VM should remain in "Running" state
    And MicroShift workloads should be healthy
    And POS transactions should continue uninterrupted

  Scenario: P2 — 48-hour trading window gate before decommission
    Given MicroShift has been trading for 48 clean hours
    And no greenboot rollbacks occurred in the last 48 hours
    When the ArgoCD wave gate evaluates phase progression
    Then the migration phase should advance from "P1" to "P2"
    And the KubeVirt bridge flag should be set to "false"

  Scenario: P3 — Windows VM decommissioned after verified trading period
    Given migration is in phase "P2"
    And the 48-hour clean trading window is confirmed
    When the rollout-controller triggers decommission
    Then the KubeVirt Windows VM should be stopped
    And all POS traffic should route through MicroShift workloads

  Scenario: Rollback: greenboot failure triggers ostree rollback
    Given the node is in phase "P1" with KubeVirt bridge active
    When a MicroShift health check fails on boot
    Then greenboot should trigger an ostree rollback
    And the previous ostree deployment should become active
    And the Windows VM should continue serving POS without interruption

  Scenario: Wave gate respects store tier ordering
    Given migration wave config targets "metro" stores before "supermarket"
    When the wave gate runs for phase "P2"
    Then only stores with tier "metro" should be progressed
    And stores with tier "supermarket" should remain in "P1"

  Scenario: node-metadata migration_phase matches ArgoCD wave gate
    Given store "NSW-042" has node-metadata with migration_phase "P1"
    When ArgoCD reads the ManagedCluster annotation "woolies.io/migration-phase"
    Then the annotation value should match the node-metadata field
    And the ApplicationSet wave should be "1"