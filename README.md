# quanminer-release

HiveOS packaging of the **third-party [`quantus-miner`](https://github.com/Quantus-Network/quantus-miner/releases)** (QUIC/UDP).
The upstream project ships no HiveOS integration; this repository wraps the
unmodified upstream linux-x86_64 binary with HiveOS custom-miner scripts
(`h-config.sh` / `h-run.sh` / `h-stats.sh` / `h-manifest.conf`).

**The miner binary is byte-identical to the upstream release asset** — its
SHA-256 is published in every release here (`quantus-miner-linux-x86_64.sha256.upstream`)
and can be verified against the upstream GitHub release.

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
| Extra config arguments | optional, e.g. `--cpu-workers 0` |

quantus-miner pins the pool certificate by fingerprint (no CA); the pool's
connection page publishes it. Hostnames are resolved to an IP at start.

See `packaging/hiveos/h-readme.md` (also shipped inside the package).

## Build

```bash
./scripts/package-hiveos-release.sh <upstream-quantus-miner-linux-x86_64> dist/
```
