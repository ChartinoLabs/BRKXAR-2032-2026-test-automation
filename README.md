# BRKXAR-2032 - Cisco Live United States Las Vegas 2026

This repository demonstrates automated network testing using [Huginn](https://github.com/ChartinoLabs/Huginn) and [Muninn](https://github.com/ChartinoLabs/Muninn). It validates network state before, during, and after operational changes - catching convergence issues, protocol flaps, and configuration drift automatically.

---

## Testbed Environments

This demo ships with **two testbed definitions** - a virtual lab and a physical lab. You are free to fork this repository and adapt either (or both) to your own environment.

| Environment   | Directory              | Devices                   | Notes                       |
| ------------- | ---------------------- | ------------------------- | --------------------------- |
| Virtual (CML) | `virtual-cml-testbed/` | 4x Catalyst 8000v routers | Runs on Cisco Modeling Labs |
| Physical      | `physical-testbed/`    | 2x routers + 2x switches  | Real IOS-XE hardware        |

Select which environment to use via the `ENV` variable in your `.env` file:

```bash
# .env
ENV=virtual-cml-testbed    # or: physical-testbed
```

> **When forking this repo**, you will need to update `testbed.yaml` in your chosen environment directory with your own device IPs, hostnames, ports, and credentials. See [Adapting to Your Environment](#adapting-to-your-environment) below.

---

## Topology

### Virtual CML Testbed

Four IOS-XE routers in a square mesh running OSPF area 0 and iBGP full-mesh (AS 65000):

<p align="center">
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 520 420" width="520" height="420">
  <!-- Background -->
  <rect width="520" height="420" rx="12" fill="#f8fafc" stroke="#e2e8f0" stroke-width="1.5"/>
  
  <!-- Title -->
  <text x="260" y="30" text-anchor="middle" font-family="system-ui, -apple-system, sans-serif" font-size="14" font-weight="600" fill="#1e293b">Virtual CML Testbed - 4x Catalyst 8000v</text>
  
  <!-- Links -->
  <!-- R1-R2 (top) -->
  <line x1="180" y1="100" x2="340" y2="100" stroke="#3b82f6" stroke-width="2.5" stroke-linecap="round"/>
  <text x="260" y="88" text-anchor="middle" font-family="monospace" font-size="10" fill="#475569">Gi2 - 10.0.12.0/30</text>
  
  <!-- R3-R4 (bottom) -->
  <line x1="180" y1="300" x2="340" y2="300" stroke="#3b82f6" stroke-width="2.5" stroke-linecap="round"/>
  <text x="260" y="328" text-anchor="middle" font-family="monospace" font-size="10" fill="#475569">Gi3 - 10.0.34.0/30</text>
  
  <!-- R1-R3 (left) -->
  <line x1="130" y1="130" x2="130" y2="270" stroke="#3b82f6" stroke-width="2.5" stroke-linecap="round"/>
  <text x="118" y="200" text-anchor="end" font-family="monospace" font-size="10" fill="#475569">Gi3</text>
  <text x="118" y="214" text-anchor="end" font-family="monospace" font-size="10" fill="#475569">10.0.13.0/30</text>
  
  <!-- R2-R4 (right) -->
  <line x1="390" y1="130" x2="390" y2="270" stroke="#3b82f6" stroke-width="2.5" stroke-linecap="round"/>
  <text x="402" y="200" text-anchor="start" font-family="monospace" font-size="10" fill="#475569">Gi3</text>
  <text x="402" y="214" text-anchor="start" font-family="monospace" font-size="10" fill="#475569">10.0.24.0/30</text>
  
  <!-- Router nodes -->
  <!-- R1 -->
  <rect x="90" y="80" width="80" height="50" rx="8" fill="#dbeafe" stroke="#2563eb" stroke-width="2"/>
  <text x="130" y="102" text-anchor="middle" font-family="system-ui, sans-serif" font-size="13" font-weight="700" fill="#1e40af">R1</text>
  <text x="130" y="118" text-anchor="middle" font-family="monospace" font-size="9" fill="#3b82f6">IOS-XE</text>
  
  <!-- R2 -->
  <rect x="350" y="80" width="80" height="50" rx="8" fill="#dbeafe" stroke="#2563eb" stroke-width="2"/>
  <text x="390" y="102" text-anchor="middle" font-family="system-ui, sans-serif" font-size="13" font-weight="700" fill="#1e40af">R2</text>
  <text x="390" y="118" text-anchor="middle" font-family="monospace" font-size="9" fill="#3b82f6">IOS-XE</text>
  
  <!-- R3 -->
  <rect x="90" y="280" width="80" height="50" rx="8" fill="#dbeafe" stroke="#2563eb" stroke-width="2"/>
  <text x="130" y="302" text-anchor="middle" font-family="system-ui, sans-serif" font-size="13" font-weight="700" fill="#1e40af">R3</text>
  <text x="130" y="318" text-anchor="middle" font-family="monospace" font-size="9" fill="#3b82f6">IOS-XE</text>
  
  <!-- R4 -->
  <rect x="350" y="280" width="80" height="50" rx="8" fill="#dbeafe" stroke="#2563eb" stroke-width="2"/>
  <text x="390" y="302" text-anchor="middle" font-family="system-ui, sans-serif" font-size="13" font-weight="700" fill="#1e40af">R4</text>
  <text x="390" y="318" text-anchor="middle" font-family="monospace" font-size="9" fill="#3b82f6">IOS-XE</text>
  
  <!-- Protocol info -->
  <rect x="170" y="360" width="180" height="44" rx="6" fill="#f0fdf4" stroke="#86efac" stroke-width="1"/>
  <text x="260" y="380" text-anchor="middle" font-family="monospace" font-size="10" fill="#166534">OSPF Area 0</text>
  <text x="260" y="394" text-anchor="middle" font-family="monospace" font-size="10" fill="#166534">iBGP Full Mesh (AS 65000)</text>
</svg>
</p>

### Physical Testbed

Two routers and two switches connected in a collapsed-core topology:

<p align="center">
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 520 360" width="520" height="360">
  <!-- Background -->
  <rect width="520" height="360" rx="12" fill="#f8fafc" stroke="#e2e8f0" stroke-width="1.5"/>
  
  <!-- Title -->
  <text x="260" y="30" text-anchor="middle" font-family="system-ui, -apple-system, sans-serif" font-size="14" font-weight="600" fill="#1e293b">Physical Testbed - IOS-XE Hardware</text>
  
  <!-- Tier labels -->
  <text x="40" y="105" font-family="system-ui, sans-serif" font-size="11" fill="#94a3b8" font-style="italic">Routers</text>
  <text x="40" y="265" font-family="system-ui, sans-serif" font-size="11" fill="#94a3b8" font-style="italic">Switches</text>
  
  <!-- Links: routers to switches -->
  <line x1="180" y1="130" x2="180" y2="240" stroke="#8b5cf6" stroke-width="2" stroke-linecap="round"/>
  <line x1="180" y1="130" x2="340" y2="240" stroke="#8b5cf6" stroke-width="1.5" stroke-dasharray="6,3" stroke-linecap="round"/>
  <line x1="340" y1="130" x2="340" y2="240" stroke="#8b5cf6" stroke-width="2" stroke-linecap="round"/>
  <line x1="340" y1="130" x2="180" y2="240" stroke="#8b5cf6" stroke-width="1.5" stroke-dasharray="6,3" stroke-linecap="round"/>
  
  <!-- Router-to-router link -->
  <line x1="220" y1="105" x2="300" y2="105" stroke="#3b82f6" stroke-width="2.5" stroke-linecap="round"/>
  
  <!-- Switch-to-switch link -->
  <line x1="220" y1="265" x2="300" y2="265" stroke="#10b981" stroke-width="2.5" stroke-linecap="round"/>
  
  <!-- Router nodes -->
  <!-- TAC-R1 -->
  <rect x="120" y="80" width="100" height="50" rx="8" fill="#dbeafe" stroke="#2563eb" stroke-width="2"/>
  <text x="170" y="102" text-anchor="middle" font-family="system-ui, sans-serif" font-size="13" font-weight="700" fill="#1e40af">TAC-R1</text>
  <text x="170" y="118" text-anchor="middle" font-family="monospace" font-size="9" fill="#3b82f6">IOS-XE Router</text>
  
  <!-- TAC-R2 -->
  <rect x="300" y="80" width="100" height="50" rx="8" fill="#dbeafe" stroke="#2563eb" stroke-width="2"/>
  <text x="350" y="102" text-anchor="middle" font-family="system-ui, sans-serif" font-size="13" font-weight="700" fill="#1e40af">TAC-R2</text>
  <text x="350" y="118" text-anchor="middle" font-family="monospace" font-size="9" fill="#3b82f6">IOS-XE Router</text>
  
  <!-- Switch nodes -->
  <!-- TAC-S1 -->
  <rect x="120" y="240" width="100" height="50" rx="8" fill="#dcfce7" stroke="#16a34a" stroke-width="2"/>
  <text x="170" y="262" text-anchor="middle" font-family="system-ui, sans-serif" font-size="13" font-weight="700" fill="#15803d">TAC-S1</text>
  <text x="170" y="278" text-anchor="middle" font-family="monospace" font-size="9" fill="#16a34a">IOS-XE Switch</text>
  
  <!-- TAC-S2 -->
  <rect x="300" y="240" width="100" height="50" rx="8" fill="#dcfce7" stroke="#16a34a" stroke-width="2"/>
  <text x="350" y="262" text-anchor="middle" font-family="system-ui, sans-serif" font-size="13" font-weight="700" fill="#15803d">TAC-S2</text>
  <text x="350" y="278" text-anchor="middle" font-family="monospace" font-size="9" fill="#16a34a">IOS-XE Switch</text>
  
  <!-- Legend -->
  <line x1="160" y1="330" x2="180" y2="330" stroke="#8b5cf6" stroke-width="2"/>
  <text x="185" y="334" font-family="system-ui, sans-serif" font-size="10" fill="#475569">Primary link</text>
  <line x1="270" y1="330" x2="290" y2="330" stroke="#8b5cf6" stroke-width="1.5" stroke-dasharray="6,3"/>
  <text x="295" y="334" font-family="system-ui, sans-serif" font-size="10" fill="#475569">Cross link</text>
</svg>
</p>

---

## Quick Start

```bash
# 1. Install dependencies
uv sync

# 2. Configure your environment
cp .env.example .env
# Edit .env to set ENV=virtual-cml-testbed or ENV=physical-testbed

# 3. Learn the baseline state of your network
make baseline

# 4. Run the full test plan
make test
```

---

## Makefile Reference

All targets respect the `ENV` and `SCENARIO` variables (defaults: `virtual-cml-testbed` and `link-shutdown-r1r2`).

### End-to-End Execution

| Target          | Description                                                 |
| --------------- | ----------------------------------------------------------- |
| `make baseline` | Learn the expected state of the entire network (all phases) |
| `make test`     | Execute the full test plan against the network              |

### Phase-by-Phase Execution

Run each phase of a scenario individually for debugging or step-by-step demos:

| Target                  | Phase          | Description                                |
| ----------------------- | -------------- | ------------------------------------------ |
| `make learn-pre-change` | pre-change     | Learn expected state before any changes    |
| `make pre-change`       | pre-change     | Verify network matches pre-change baseline |
| `make shutdown`         | shutdown       | Execute the link shutdown action           |
| `make post-shutdown`    | post-shutdown  | Verify network state after shutdown        |
| `make normalize`        | normalize      | Execute the link restore action            |
| `make post-normalize`   | post-normalize | Verify network recovered to baseline       |

### Reconciliation

When expected state changes (e.g., a link goes down), reconciliation updates the test parameters to reflect the new "known good" state:

| Target                         | Description                                                 |
| ------------------------------ | ----------------------------------------------------------- |
| `make learn-post-shutdown`     | Learn the network state after shutdown (for reconciliation) |
| `make reconcile-post-shutdown` | Reconcile test parameters to match post-shutdown state      |
| `make clean-parameters`        | Delete learned parameters (keeps ACTION and GATE files)     |

### Infrastructure as Code

Manage device configuration via Terraform (IOS XE as Code under Cisco's [Network as Code umbrella](https://netascode.cisco.com)):

| Target          | Description                                                 |
| --------------- | ----------------------------------------------------------- |
| `make tf-init`  | Initialize Terraform in the environment's `xeac/` directory |
| `make tf-plan`  | Preview configuration changes                               |
| `make tf-apply` | Apply configuration to devices                              |

### Code Quality

| Target         | Description                                       |
| -------------- | ------------------------------------------------- |
| `make quality` | Run ruff format, ruff check, and ty type-checking |

---

## Demo Scenario: Link Shutdown and Recovery

The default scenario (`link-shutdown-r1r2`) demonstrates automated validation across an operational change - shutting down the R1-to-R2 link and verifying convergence:

```
Phase Flow (end-to-end via `make test`):

  pre-change ──> shutdown ──> [convergence gate] ──> post-shutdown
                                                          │
  post-normalize <── [convergence gate] <── normalize <───┘
```

When running **end-to-end** (`make test`), convergence gates execute automatically between phases - Huginn polls protocol state until the topology stabilizes before proceeding.

When running **phase-by-phase** with individual Makefile targets, there are no automatic gates between your commands. You must wait for the network to converge before running the next verification phase:

1. `make pre-change` - Verify version, interfaces, OSPF neighbors, BGP peers match baseline
2. `make shutdown` - Shut R1 GigabitEthernet2 (the R1–R2 link)
3. **Wait for convergence** (~30–60s for OSPF/BGP to reconverge around the failure)
4. `make post-shutdown` - Verify OSPF/BGP reconverged correctly
5. `make normalize` - Restore R1 GigabitEthernet2
6. **Wait for convergence** (~30–60s for protocols to recover)
7. `make post-normalize` - Verify full recovery to original baseline

---

## Adapting to Your Environment

When you fork this repository, update the following to match your lab:

1. **`<env>/testbed.yaml`** - Device hostnames/IPs, SSH/NETCONF ports, credentials
2. **`.env`** - Set `ENV` to your chosen testbed directory
3. **`<env>/xeac/`** - Terraform variables for your device management IPs (if using IaC)
4. **`<env>/parameters/`** - Delete learned parameters (`make clean-parameters`) and re-learn against your devices (`make baseline`)

The test plan structure (`test_plan/scenarios.yaml`, `test_plan/test_cases/`, `test_plan/groups/`) can be reused as-is or modified to test different scenarios.

---

## Built With

| Project                                          | Description                                                                                      |
| ------------------------------------------------ | ------------------------------------------------------------------------------------------------ |
| [Huginn](https://github.com/ChartinoLabs/Huginn) | Network test automation framework - learns expected state, executes test plans, reconciles drift |
| [Muninn](https://github.com/ChartinoLabs/Muninn) | Network state parsers - structured parsing of CLI/API output across IOS-XE, IOS-XR, NX-OS        |
| [IOS XE as Code](https://netascode.cisco.com)    | Terraform-based network configuration management                                                 |
