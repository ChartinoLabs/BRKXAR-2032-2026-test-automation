# BRKXAR-2032 - Cisco Live 2026 Demo

Test automation demo using **Huginn** and **Muninn** against a 4-router Catalyst 8000v topology running in CML.

## Topology

| Device | OS     | SSH Port | NETCONF Port | Loopback0    |
|--------|--------|----------|--------------|--------------|
| R1     | IOS-XE | 2381     | 2391         | 192.0.2.1/32 |
| R2     | IOS-XE | 2382     | 2392         | 192.0.2.2/32 |
| R3     | IOS-XE | 2383     | 2393         | 192.0.2.3/32 |
| R4     | IOS-XE | 2384     | 2394         | 192.0.2.4/32 |

```
        R1 -------- R2
        |            |
        R3 -------- R4
```

- R1-R2: 10.0.12.0/30 (Gi2)
- R1-R3: 10.0.13.0/30 (Gi3)
- R2-R4: 10.0.24.0/30 (Gi3)
- R3-R4: 10.0.34.0/30 (Gi3)
- OSPF area 0 + iBGP full mesh (AS 65000)
- Configuration managed by IOS XE as Code (see `xeac/`)

## Quick Start

```bash
uv sync
make baseline   # Learn initial state
make test       # Run test plan
```

## Demo Scenario

**Link Shutdown and Recovery** (R1 to R2):

1. Pre-change baseline verification (version, interfaces, OSPF, BGP)
2. Shut R1 GigabitEthernet2
3. Convergence gate (wait for protocol state changes)
4. Post-shutdown verification
5. Normalize R1 GigabitEthernet2
6. Convergence gate (wait for recovery)
7. Post-normalize verification
