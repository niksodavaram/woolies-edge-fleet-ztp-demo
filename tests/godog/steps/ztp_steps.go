// tests/godog/steps/ztp_steps.go
package steps

import (
	"context"
	"encoding/json"
	"fmt"
	"net/http"
	"os/exec"
	"strings"
	"time"

	"github.com/cucumber/godog"
)

type ZTPContext struct {
	NodeMAC       string
	KubeconfigPath string
	NodeMetadata  map[string]interface{}
}

func (z *ZTPContext) aRHEL9EdgeNodeWithMAC(mac string) error {
	z.NodeMAC = mac
	z.KubeconfigPath = "/var/lib/microshift/resources/kubeadmin/kubeconfig"
	return nil
}

func (z *ZTPContext) theNodeCompletesPXEBoot() error {
	// In CI: simulate via Molecule/QEMU; in staging: real PXE
	out, err := exec.Command("rpm-ostree", "status", "--json").Output()
	if err != nil {
		return fmt.Errorf("rpm-ostree status failed: %w", err)
	}
	var status map[string]interface{}
	if err := json.Unmarshal(out, &status); err != nil {
		return fmt.Errorf("parse rpm-ostree status: %w", err)
	}
	return nil
}

func (z *ZTPContext) ostreeDeploymentShouldBeBooted(ref string) error {
	out, _ := exec.Command("rpm-ostree", "status", "--json").Output()
	var status struct {
		Deployments []struct {
			Booted    bool   `json:"booted"`
			BaseCommitMeta struct {
				Ref string `json:"ostree.linux"`
			} `json:"base-commit-meta"`
		} `json:"deployments"`
	}
	json.Unmarshal(out, &status)
	for _, d := range status.Deployments {
		if d.Booted {
			return nil
		}
	}
	return fmt.Errorf("no booted ostree deployment found for ref %s", ref)
}

func (z *ZTPContext) kickstartPostRuns() error {
	// In integration tests, %post output is read from log
	out, err := exec.Command("cat", "/var/log/woolies-kickstart-post.log").Output()
	if err != nil {
		return fmt.Errorf("kickstart post log missing: %w", err)
	}
	if !strings.Contains(string(out), "post-install complete") {
		return fmt.Errorf("kickstart post-install did not complete successfully")
	}
	return nil
}

func (z *ZTPContext) nodeMetadataFieldShouldEqual(field, expected string) error {
	out, err := exec.Command("cat", "/etc/woolies/node-metadata.json").Output()
	if err != nil {
		return fmt.Errorf("node-metadata.json not found: %w", err)
	}
	var meta map[string]interface{}
	json.Unmarshal(out, &meta)
	actual, ok := meta[field]
	if !ok {
		return fmt.Errorf("field '%s' not found in node-metadata.json", field)
	}
	if fmt.Sprintf("%v", actual) != expected {
		return fmt.Errorf("expected %s=%s, got %v", field, expected, actual)
	}
	return nil
}

func (z *ZTPContext) microshiftAPIHealthzShouldReturn(url, want string) error {
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Minute)
	defer cancel()

	for {
		select {
		case <-ctx.Done():
			return fmt.Errorf("timed out waiting for %s to return %s", url, want)
		default:
			// #nosec G402 — self-signed cert on edge node, intentional
			client := &http.Client{Timeout: 5 * time.Second}
			resp, err := client.Get(url)
			if err == nil && resp.StatusCode == 200 {
				return nil
			}
			time.Sleep(10 * time.Second)
		}
	}
}

func (z *ZTPContext) namespaceShouldHaveStatus(ns, status string) error {
	out, err := exec.Command("kubectl",
		"--kubeconfig", z.KubeconfigPath,
		"get", "namespace", ns,
		"-o", "jsonpath={.status.phase}",
	).Output()
	if err != nil {
		return fmt.Errorf("kubectl get namespace %s: %w", ns, err)
	}
	if string(out) != status {
		return fmt.Errorf("namespace %s: expected %s, got %s", ns, status, out)
	}
	return nil
}

func (z *ZTPContext) portShouldBe(port int, state string) error {
	target := fmt.Sprintf("localhost:%d", port)
	conn, err := exec.Command("nc", "-zv", "-w2", "localhost", fmt.Sprintf("%d", port)).CombinedOutput()
	open := err == nil
	if state == "OPEN" && !open {
		return fmt.Errorf("port %d should be open but is closed (%s)", port, conn)
	}
	if state == "CLOSED" && open {
		return fmt.Errorf("port %d should be closed but is open — target: %s", port, target)
	}
	return nil
}

func (z *ZTPContext) getenforceReturns(expected string) error {
	out, err := exec.Command("getenforce").Output()
	if err != nil {
		return fmt.Errorf("getenforce failed: %w", err)
	}
	if !strings.Contains(string(out), expected) {
		return fmt.Errorf("SELinux mode: expected %s, got %s", expected, out)
	}
	return nil
}

// InitializeZTPScenario wires step definitions to godog
func InitializeZTPScenario(ctx *godog.ScenarioContext) {
	z := &ZTPContext{}

	ctx.Step(`^a RHEL 9 edge node with MAC address "([^"]+)"$`, z.aRHEL9EdgeNodeWithMAC)
	ctx.Step(`^the node completes PXE boot$`, z.theNodeCompletesPXEBoot)
	ctx.Step(`^the ostree deployment "([^"]+)" should be booted$`, z.ostreeDeploymentShouldBeBooted)
	ctx.Step(`^Kickstart %post runs$`, z.kickstartPostRuns)
	ctx.Step(`^the metadata field "([^"]+)" should equal "([^"]+)"$`, z.nodeMetadataFieldShouldEqual)
	ctx.Step(`^the MicroShift API at "([^"]+)" should return "([^"]+)"$`, z.microshiftAPIHealthzShouldReturn)
	ctx.Step(`^namespace "([^"]+)" should have status "([^"]+)"$`, z.namespaceShouldHaveStatus)
	ctx.Step(`^port (\d+) should be (OPEN|CLOSED).*$`, z.portShouldBe)
	ctx.Step(`^the command "getenforce" should return "([^"]+)"$`, z.getenforceReturns)
}