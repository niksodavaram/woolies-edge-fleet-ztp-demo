# tests/godog/features/ztp.feature
Feature: Zero-Touch Provisioning (ZTP) of Woolies Store Edge Node
  As a WooliesX infrastructure engineer
  I want store hardware to be provisioned automatically when plugged in
  So that store technicians can deploy nodes without manual configuration

  Background:
    Given a RHEL 9 edge node with MAC address "aa:bb:cc:dd:ee:ff"
    And the SD-WAN assigns DHCP and triggers PXE boot
    And the Kickstart file "store-default.ks" is served from the image server

  Scenario: Node boots from PXE and installs the ostree image
    When the node completes PXE boot
    Then the ostree deployment "rhel/9/x86_64/edge" should be booted
    And the rpm-ostree deployment should show version "1.3.0"

  Scenario: Post-install metadata is written correctly
    When Kickstart %post runs
    Then the file "/etc/woolies/node-metadata.json" should exist
    And the metadata field "migration_phase" should equal "P1"
    And the metadata field "platform" should equal "rhel9-microshift"
    And the metadata field "regional_hub" should equal "hub-nsw.woolies.internal"

  Scenario: Greenboot health check gates the deployment
    Given MicroShift is starting after first boot
    When greenboot runs the required health checks
    Then "greenboot-healthcheck" service should be active
    And the MicroShift API at "https://localhost:6443/healthz" should return "ok"
    And no rollback should be triggered

  Scenario: MicroShift core namespaces become Ready
    Given greenboot declared the boot as green
    When I wait up to 5 minutes for MicroShift to stabilise
    Then namespace "kube-system" should have status "Active"
    And namespace "openshift-dns" should have status "Active"
    And namespace "openshift-ingress" should have status "Active"

  Scenario: Node registers with ACM hub
    Given MicroShift is running and kubeconfig is available
    When the klusterlet agent contacts "hub-nsw.woolies.internal"
    Then the ManagedCluster resource should reach "Ready" condition
    And the cluster label "woolies.store/tier" should be "supermarket"
    And the cluster label "woolies.store/state" should be "NSW"

  Scenario: ArgoCD syncs the store workload ApplicationSet
    Given the ManagedCluster is registered and labels are set
    When ArgoCD evaluates the store-workloads ApplicationSet
    Then an Application should be created for namespace "woolies-pos"
    And sync status should be "Synced"
    And health status should be "Healthy"

  Scenario: Firewall blocks unauthorised ports
    Given the node is fully provisioned
    Then port 22 should be OPEN for SSH
    And port 6443 should be OPEN for MicroShift API
    And port 1883 should be OPEN for MQTT cold-chain
    And port 23 should be CLOSED (telnet blocked)
    And port 21 should be CLOSED (FTP blocked)

  Scenario: SELinux remains enforcing after full provisioning
    Given the node has completed ZTP and greenboot
    Then the command "getenforce" should return "Enforcing"
    And no SELinux denials should appear in "/var/log/audit/audit.log" for "microshift"