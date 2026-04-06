# tests/inspec/cis-rhel9/controls/microshift.rb
title "Woolies Edge – MicroShift Operational Health"

control "woolies-microshift-service-running" do
  impact 1.0; tag custom: "woolies-microshift"
  describe service("microshift") do
    it { should be_enabled }; it { should be_running }
  end
end

control "woolies-microshift-api-responding" do
  impact 1.0; tag custom: "woolies-microshift"
  describe command("curl -sk https://localhost:6443/healthz") do
    its("stdout")      { should match(/ok/) }
    its("exit_status") { should eq 0 }
  end
end

control "woolies-microshift-kubeconfig-present" do
  impact 1.0; tag custom: "woolies-microshift"
  describe file("/var/lib/microshift/resources/kubeadmin/kubeconfig") do
    it { should exist }; its("mode") { should cmp "0600" }
    its("owner") { should eq "root" }
  end
end

control "woolies-microshift-data-dir-on-separate-partition" do
  impact 0.8; tag custom: "woolies-microshift"
  describe mount("/var/lib/microshift") do
    it { should be_mounted }
  end
end

control "woolies-microshift-core-namespaces-ready" do
  impact 1.0; tag custom: "woolies-microshift"
  %w[kube-system openshift-dns openshift-ingress].each do |ns|
    describe command("kubectl --kubeconfig=/var/lib/microshift/resources/kubeadmin/kubeconfig \
                      get namespace #{ns} -o jsonpath='{.status.phase}'") do
      its("stdout") { should eq "Active" }
    end
  end
end