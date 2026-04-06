# tests/inspec/cis-rhel9/controls/greenboot.rb
title "Woolies Edge – Greenboot A/B Rollback Gate"

control "woolies-greenboot-installed" do
  impact 1.0; tag custom: "woolies-greenboot"
  %w[greenboot greenboot-default-health-checks microshift-greenboot].each do |pkg|
    describe package(pkg) { it { should be_installed } }
  end
end

control "woolies-greenboot-service-enabled" do
  impact 1.0; tag custom: "woolies-greenboot"
  describe service("greenboot-healthcheck") do
    it { should be_enabled }; it { should be_running }
  end
end

control "woolies-greenboot-required-script-present" do
  impact 1.0; tag custom: "woolies-greenboot"
  path = "/etc/greenboot/check/required.d/40-woolies-store-health.sh"
  describe file(path) do
    it { should exist }; it { should be_executable }
    its("owner") { should eq "root" }
    its("mode")  { should cmp "0755" }
  end
end

control "woolies-greenboot-checks-microshift-api" do
  impact 0.9; tag custom: "woolies-greenboot"
  path = "/etc/greenboot/check/required.d/40-woolies-store-health.sh"
  describe file(path) do
    its("content") { should match(/6443|microshift|kubeconfig/i) }
  end
end

control "woolies-node-metadata-valid" do
  impact 1.0; tag custom: "woolies-edge"
  describe file("/etc/woolies/node-metadata.json") do
    it { should exist }; its("mode") { should cmp "0644" }
    its("content") { should match(/"store_id"/) }
    its("content") { should match(/"migration_phase"/) }
    its("content") { should match(/"platform"/) }
    its("content") { should match(/"regional_hub"/) }
  end
  describe json("/etc/woolies/node-metadata.json") do
    its(["migration_phase"]) { should match(/^P[0-4]$/) }
    its(["platform"])        { should eq "rhel9-microshift" }
  end
end

control "woolies-ostree-booted-deployment" do
  impact 1.0; tag custom: "woolies-edge"
  describe command("rpm-ostree status --json") do
    its("exit_status") { should eq 0 }
    its("stdout")      { should match(/"booted"\s*:\s*true/) }
  end
end

control "woolies-no-greenboot-rollback-pending" do
  impact 1.0; tag custom: "woolies-greenboot"
  describe command("grub2-editenv - list | grep boot_counter") do
    its("stdout") { should_not match(/boot_counter=[1-9]/) }
  end
end