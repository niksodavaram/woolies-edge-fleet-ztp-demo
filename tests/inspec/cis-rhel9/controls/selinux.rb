# tests/inspec/cis-rhel9/controls/selinux.rb
# Run: inspec exec tests/inspec/cis-rhel9 -t ssh://ansible-svc@<ip> --sudo
title "CIS RHEL9 – SELinux (Section 1.6)"

control "cis-1.6.1-selinux-installed" do
  impact 1.0; tag cis: "1.6.1"
  describe package("libselinux")              { it { should be_installed } }
  describe package("selinux-policy-targeted") { it { should be_installed } }
end

control "cis-1.6.2-selinux-not-disabled-bootloader" do
  impact 1.0; tag cis: "1.6.2"
  describe command("grubby --info=ALL") do
    its("stdout") { should_not match(/selinux=0/) }
    its("stdout") { should_not match(/enforcing=0/) }
  end
end

control "cis-1.6.3-selinux-policy-targeted" do
  impact 1.0; tag cis: "1.6.3"
  describe file("/etc/selinux/config") do
    it { should exist }
    its("content") { should match(/^SELINUXTYPE\s*=\s*(targeted|mls)/) }
  end
end

control "cis-1.6.4-selinux-enforcing" do
  impact 1.0; tag cis: "1.6.4"
  describe command("getenforce") { its("stdout") { should match(/Enforcing/i) } }
  describe file("/etc/selinux/config") do
    its("content") { should match(/^SELINUX\s*=\s*enforcing/) }
  end
end

control "cis-1.6.5-no-unconfined-services" do
  impact 0.7; tag cis: "1.6.5"
  describe command("ps -eZ | grep unconfined_service_t") { its("stdout") { should eq "" } }
end

control "cis-1.6.6-setroubleshoot-not-installed" do
  impact 0.5; tag cis: "1.6.6"
  describe package("setroubleshoot") { it { should_not be_installed } }
end

control "woolies-microshift-selinux-module-loaded" do
  impact 1.0; tag custom: "woolies-edge"
  describe package("microshift-selinux") { it { should be_installed } }
  describe command("semodule -l | grep microshift") do
    its("stdout")      { should match(/microshift/) }
    its("exit_status") { should eq 0 }
  end
end