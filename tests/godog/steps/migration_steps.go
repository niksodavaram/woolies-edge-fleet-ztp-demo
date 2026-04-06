// tests/godog/steps/migration_steps.go
package steps

import (
	"encoding/json"
	"fmt"
	"os/exec"
	"strings"

	"github.com/cucumber/godog"
)

type MigrationContext struct {
	StoreID        string
	CurrentPhase   string
	KubeconfigPath string
}

func (m *MigrationContext) storeIsInMigrationPhase(storeID, phase string) error {
	m.StoreID = storeID
	m.CurrentPhase = phase
	out, err := exec.Command("cat", "/etc/woolies/node-metadata.json").Output()
	if err != nil {
		return fmt.Errorf("node-metadata.json not found: %w", err)
	}
	var meta map[string]interface{}
	json.Unmarshal(out, &meta)
	if meta["migration_phase"] != phase {
		return fmt.Errorf("store %s: expected phase %s, got %v", storeID, phase, meta["migration_phase"])
	}
	return nil
}

func (m *MigrationContext) kubeVirtWindowsVMShouldBe(state string) error {
	out, err := exec.Command("kubectl",
		"--kubeconfig", m.KubeconfigPath,
		"get", "vmi", "-A",
		"-o", "jsonpath={.items[0].status.phase}",
	).Output()
	if err != nil {
		return fmt.Errorf("kubectl get vmi: %w", err)
	}
	if !strings.EqualFold(string(out), state) {
		return fmt.Errorf("KubeVirt VM: expected %s, got %s", state, out)
	}
	return nil
}

func (m *MigrationContext) noGreenbBootRolledBackInLast48Hours() error {
	out, err := exec.Command("journalctl", "-u", "greenboot-healthcheck",
		"--since", "48 hours ago", "--no-pager").Output()
	if err != nil {
		return fmt.Errorf("journalctl failed: %w", err)
	}
	if strings.Contains(string(out), "Script returned non-zero exit code") {
		return fmt.Errorf("greenboot recorded a health check failure in the last 48 hours")
	}
	return nil
}

func (m *MigrationContext) migrationPhaseShouldAdvanceTo(from, to string) error {
	// Validates wave gate annotation set by rollout-controller MCP agent
	out, err := exec.Command("kubectl",
		"--kubeconfig", m.KubeconfigPath,
		"get", "managedcluster", m.StoreID,
		"-o", "jsonpath={.metadata.annotations.woolies\\.io/migration-phase}",
	).Output()
	if err != nil {
		return fmt.Errorf("get managedcluster %s: %w", m.StoreID, err)
	}
	if string(out) != to {
		return fmt.Errorf("expected phase %s → %s, annotation says %s", from, to, out)
	}
	return nil
}

func (m *MigrationContext) waveGateShouldOnlyProgressTier(tier string) error {
	out, err := exec.Command("kubectl",
		"--kubeconfig", m.KubeconfigPath,
		"get", "managedclusters",
		"-l", fmt.Sprintf("woolies.store/tier=%s", tier),
		"-o", "jsonpath={.items[*].metadata.annotations.woolies\\.io/migration-phase}",
	).Output()
	if err != nil {
		return fmt.Errorf("get managedclusters for tier %s: %w", tier, err)
	}
	phases := strings.Fields(string(out))
	for _, p := range phases {
		if p == "P1" {
			return fmt.Errorf("tier %s still has stores in P1 — wave gate did not advance", tier)
		}
	}
	return nil
}

func (m *MigrationContext) annotationShouldMatchNodeMetadata(annotationKey string) error {
	// Check ManagedCluster annotation matches /etc/woolies/node-metadata.json
	annotation, err := exec.Command("kubectl",
		"--kubeconfig", m.KubeconfigPath,
		"get", "managedcluster", m.StoreID,
		"-o", fmt.Sprintf("jsonpath={.metadata.annotations.%s}", annotationKey),
	).Output()
	if err != nil {
		return fmt.Errorf("get annotation: %w", err)
	}
	meta, _ := exec.Command("cat", "/etc/woolies/node-metadata.json").Output()
	var nodeMetadata map[string]interface{}
	json.Unmarshal(meta, &nodeMetadata)
	expected := fmt.Sprintf("%v", nodeMetadata["migration_phase"])
	if string(annotation) != expected {
		return fmt.Errorf("annotation %s=%s does not match node-metadata %s", annotationKey, annotation, expected)
	}
	return nil
}

// InitializeMigrationScenario wires migration step definitions
func InitializeMigrationScenario(ctx *godog.ScenarioContext) {
	m := &MigrationContext{
		KubeconfigPath: "/var/lib/microshift/resources/kubeadmin/kubeconfig",
	}

	ctx.Step(`^store "([^"]+)" is in migration phase "([^"]+)"$`, m.storeIsInMigrationPhase)
	ctx.Step(`^the KubeVirt Windows VM should remain in "([^"]+)" state$`, m.kubeVirtWindowsVMShouldBe)
	ctx.Step(`^no rollbacks occurred in the last 48 hours$`, m.noGreenbBootRolledBackInLast48Hours)
	ctx.Step(`^the migration phase should advance from "([^"]+)" to "([^"]+)"$`, m.migrationPhaseShouldAdvanceTo)
	ctx.Step(`^only stores with tier "([^"]+)" should be progressed$`, m.waveGateShouldOnlyProgressTier)
	ctx.Step(`^the annotation value should match the node-metadata field$`, func() error {
		return m.annotationShouldMatchNodeMetadata("woolies.io/migration-phase")
	})
}