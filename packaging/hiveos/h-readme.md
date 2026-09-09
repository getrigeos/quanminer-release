# quanminer — third-party Quantus quantus-miner for HiveOS

This package wraps the **unmodified third-party `quantus-miner`** (linux-x86_64,
from https://github.com/Quantus-Network/quantus-miner/releases) with the
HiveOS custom-miner integration scripts. The binary's SHA-256 is recorded in
the release notes; verify it against the upstream release asset.

quantus-miner talks **QUIC over UDP** to the pool. Standard TCP firewalls do
not apply; make sure outbound UDP to the pool port is allowed.

## Flight sheet

| Field | Value |
|---|---|
| Miner name | `quanminer` |
| Installation URL | the `quanminer-<version>.tar.gz` from this repository's Releases |
| Hash algorithm | leave empty |
| Wallet and worker template | `%WAL%.%WORKER_NAME%` |
| Pool URL | your pool's QUIC endpoint, e.g. `qminer.innovlab.cc:17601` |
| Password | the pool's TLS certificate SHA-256 fingerprint (64 hex chars, from the pool's connection page) |
| Extra config arguments | optional passthrough, e.g. `--cpu-workers 0` |

The Password field is **required**: quantus-miner pins the pool's QUIC
certificate by SHA-256 fingerprint instead of using CA certificates. Your
pool's connection page publishes it. An `--tls-cert-sha256 <fp>` in Extra
config arguments overrides the Password field.

Hostnames in the Pool URL are resolved to an IP at miner start (the upstream
binary only accepts `IP:PORT`).

## InnovLab pool quick values

- Pool URL: `qminer.innovlab.cc:17601`
- Password: see https://quan.innovlab.cc/#connect (certificate fingerprint)
- Note: `hk2`/`ru2` regional names do NOT carry the QUIC endpoint.
