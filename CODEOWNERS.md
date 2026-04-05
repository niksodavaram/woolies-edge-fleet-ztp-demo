# CODEOWNERS for woolies-edge-fleet-ztp-demo
# Paths on the left, GitHub users or teams on the right.

# Default: platform team reviews everything
*                           @woolies/platform-team

# Security-sensitive areas
04-secrets-cicd/*           @woolies/platform-team @woolies/security-team
02-infrastructure/ztp/*     @woolies/platform-team @woolies/security-team

# Day 0 (Golden image, Kickstart, container examples)
00-provisioning/*           @woolies/platform-team

# Day 1 (Ansible bootstrap)
01-bootstrap/*              @woolies/platform-team

# Day 1.5 (SNO, ZTP, hub-side infra)
02-infrastructure/*         @woolies/platform-team

# Day 2 (workloads, MQTT/DDS, MCP agents)
03-workloads/*              @woolies/platform-team @woolies/app-team

# Documentation and ADRs
docs/*                      @woolies/platform-team