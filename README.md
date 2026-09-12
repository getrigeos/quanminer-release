# quanminer-release

HiveOS packaging of the **third-party high-performance `quanpool-miner`** (QUIC/UDP).
This repository wraps the unmodified `quanpool-miner` linux-x86_64 binary with
HiveOS custom-miner scripts (`h-config.sh` / `h-run.sh` / `h-stats.sh` /
`h-manifest.conf`) and points it at this pool.

**The miner binary is byte-identical to the official `quanpool-miner` build**
(`https://download.quanpool.com/quanpool-miner-6.2.4-linux-x86_64`) — its SHA-256
is published in every release here (`quanpool-miner-linux-x86_64.sha256.upstream`)
and can be verified against that download.

> ⚠️ **quanpool-miner carries a built-in 5% miner dev fee** (it mines to its
> author for a share of the time). It is a much faster build (≈1.4 GH/s on an
> RTX 5090 vs ≈0.81 GH/s for the stock quantus-miner), so it is usually still
> ahead net of the fee — but the fee is real. It also defaults to its **own**
> pool, so this package always sets `--node-addr` to point it at our pool.
> If you want a fee-free miner, use INVminer (Stratum TLS) instead.

## Use in HiveOS

Add a custom miner in the flight sheet:

| Field | Value |
|---|---|
| Miner name | `quanminer` |
| Installation URL | the `quanminer-<version>.tar.gz` asset from [Releases](../../releases) |
| Hash algorithm | leave empty |
| Wallet and worker template | `%WAL%.%WORKER_NAME%` |
| Pool URL | your pool's QUIC endpoint (e.g. `qminer.innovlab.cc:17601`) |
| Password | the pool's TLS certificate SHA-256 fingerprint (64 hex) |
| Extra config arguments | optional, e.g. `--gpu-devices 1`, or `--cpu-workers <N>` to add CPU |

quanpool-miner pins the pool certificate by fingerprint (no CA); the pool's
connection page publishes it. Hostnames are resolved to an IP at start.
Native CUDA is the default engine — no Vulkan/wgpu runtime to install. The miner
talks QUIC over UDP, so ensure outbound UDP to the pool port is allowed
(networks that block UDP should use the pool's TCP/Stratum miner instead).

## Build

```bash
./scripts/package-hiveos-release.sh <quanpool-miner-linux-x86_64> dist/
```
