# tests/inspec/cis-rhel9/controls/cis-partitions.rb
# CIS RHEL9 Section 1.1 — filesystem / partition hardening
title "CIS RHEL9 – Filesystem Partitioning (Section 1.1)"

{
  "/tmp"  => %w[nodev noexec nosuid],
  "/var"  => %w[nodev],
  "/home" => %w[nodev],
}.each do |mp, opts|
  control "cis-partition-#{mp.tr('/','_')}-mount-options" do
    impact 1.0
    title "#{mp} has required mount options"
    tag cis: "1.1"
    opts.each do |opt|
      describe mount(mp) do
        its("options") { should include opt }
      end
    end
  end
end

control "cis-1.1-var-tmp-separate" do
  impact 0.7; tag cis: "1.1"
  describe mount("/var/lib/microshift") { it { should be_mounted } }
  describe mount("/var")               { it { should be_mounted } }
  describe mount("/tmp")               { it { should be_mounted } }
end

control "cis-1.1-core-dump-restricted" do
  impact 1.0; tag cis: "1.5.1"
  describe command("sysctl fs.suid_dumpable") do
    its("stdout") { should match(/fs\.suid_dumpable\s*=\s*0/) }
  end
  describe file("/etc/security/limits.conf") do
    its("content") { should match(/\*\s+hard\s+core\s+0/) }
  end
end

control "cis-1.1-audit-rules-woolies" do
  impact 0.9; tag cis: "4.1"
  describe file("/etc/audit/rules.d/99-woolies.rules") do
    it { should exist }
    its("content") { should match(/-w \/etc\/passwd/) }
    its("content") { should match(/-w \/etc\/shadow/) }
    its("content") { should match(/-w \/etc\/sudoers/) }
    its("content") { should match(/-S execve/) }
  end
end