# quanminer — high-performance quanpool-miner for HiveOS

This package wraps the **unmodified third-party `quanpool-miner` v6** (linux-x86_64)
with the HiveOS custom-miner integration scripts, pointed at this pool. The
binary's SHA-256 is recorded in the release notes; verify it against the official
`quanpool-miner` download.

> ⚠️ **5% miner dev fee.** quanpool-miner is a much faster build (≈1.4 GH/s on an
> RTX 5090 vs ≈0.81 GH/s stock) but carries a built-in 5% dev fee to its author.
> It is usually still ahead net of the fee. For a fee-free miner use INVminer
> (Stratum TLS). This build also defaults to its OWN pool, so this package always
> sets `--node-addr` to this pool via the Pool URL field.

quanpool-miner talks **QUIC over UDP** and uses **native CUDA** by default (no
Vulkan). Standard TCP firewalls do not apply; make sure outbound UDP to the pool
port is allowed.

## Flight sheet

| Field | Value |
|---|---|
| Miner name | `quanminer` |
| Installation URL | the `quanminer-<version>.tar.gz` from this repository's Releases |
| Hash algorithm | leave empty |
| Wallet and worker template | `%WAL%.%WORKER_NAME%` |
| Pool URL | your pool's QUIC endpoint, e.g. `qminer.innovlab.cc:17601` |
| Password | the pool's TLS certificate SHA-256 fingerprint (64 hex chars, from the pool's connection page) |
| Extra config arguments | usually blank (all GPUs, native CUDA); e.g. `--gpu-devices 1` to cap cards, `--cpu-workers <N>` to add CPU |

The Password field is **required**: quanpool-miner pins the pool's QUIC
certificate by SHA-256 fingerprint instead of using CA certificates. Your pool's
connection page publishes it. An `--tls-cert-sha256 <fp>` in Extra config
arguments overrides the Password field.

Hostnames in the Pool URL are resolved to an IP at miner start (the binary only
accepts `IP:PORT`). HiveOS stats come from the miner's `/hive-stats` endpoint.

## InnovLab pool quick values

- Pool URL: `qminer.innovlab.cc:17601`
- Password: see https://quan.innovlab.cc/#connect (certificate fingerprint)
- Note: `hk2`/`ru2` regional names do NOT carry the QUIC endpoint.
