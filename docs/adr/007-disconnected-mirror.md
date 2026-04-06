# Disconnected Mirror Registry (Edge Stores)

Edge SNO clusters do **not** pull from the public internet. All OCP and app
images are mirrored to `registry.woolies.internal:5000`. 

## OpenShift payload

- `oc adm release mirror` is used from a connected hub cluster to mirror
  OCP payloads into the mirror registry.
- `install-config.yaml` references the mirror via `imageContentSources`.
- `99-woolies-mirror-registry-ca` MachineConfig injects the mirror CA.

## Application images

- All app images (scan-assist-ai, MQTT, DDS, MCP agents) are pushed into:
  - `registry.woolies.internal:5000/woolies-apps/*`
- Edge clusters are configured (via Image/Cluster config and NetworkPolicy)
  to only pull from the internal mirror and Red Hat-certified registries.

This allows SNO stores to operate in **disconnected** or **limited egress**
environments while still receiving controlled updates via GitOps.