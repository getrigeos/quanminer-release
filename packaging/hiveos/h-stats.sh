#!/usr/bin/env bash
# Sourced by the HiveOS agent. Sets caller-scope `khs` and `stats`; never echo or exit.
# quanpool-miner exposes a Hive-compatible JSON endpoint at /hive-stats, so we
# pass it through as `stats` and compute the required total `khs` from it.

quanminer_hive_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
quanminer_api_override=${CUSTOM_API_PORT:-}
quanminer_config_override=${CUSTOM_CONFIG_FILENAME:-}
. "$quanminer_hive_dir/h-manifest.conf"

quanminer_version=${CUSTOM_VERSION:-unknown}
if [[ -x "$quanminer_hive_dir/quanpool-miner" ]]; then
    quanminer_bin_version=$("$quanminer_hive_dir/quanpool-miner" --version 2>/dev/null \
        | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1 | tr -d '\r')
    [[ -n $quanminer_bin_version ]] && quanminer_version=$quanminer_bin_version
fi

# The metrics/stats port: prefer the live override, then the config's
# --metrics-port, then the manifest default.
quanminer_port=${quanminer_api_override:-${CUSTOM_API_PORT:-9900}}
quanminer_config=${quanminer_config_override:-${CUSTOM_CONFIG_FILENAME:-/hive/miners/custom/quanminer/quanminer.conf}}
if [[ -r $quanminer_config ]]; then
    mapfile -d '' -t quanminer_cfg <"$quanminer_config"
    for ((quanminer_i = 0; quanminer_i < ${#quanminer_cfg[@]}; quanminer_i++)); do
        case ${quanminer_cfg[quanminer_i]} in
            --metrics-port)
                ((quanminer_i + 1 < ${#quanminer_cfg[@]})) \
                    && quanminer_port=${quanminer_cfg[quanminer_i + 1]}
                ;;
            --metrics-port=*) quanminer_port=${quanminer_cfg[quanminer_i]#*=} ;;
        esac
    done
fi

if command -v curl >/dev/null 2>&1; then
    quanminer_stats=$(curl -fsS --max-time 4 "http://127.0.0.1:${quanminer_port}/hive-stats" 2>/dev/null)
else
    quanminer_stats=$(wget -qO- -T 4 "http://127.0.0.1:${quanminer_port}/hive-stats" 2>/dev/null)
fi

if [[ -n $quanminer_stats ]]; then
    # /hive-stats is already Hive-shaped (hs, hs_units, temp, fan, ver, ar, algo).
    # Force our detected version into ver and compute total khs for Hive.
    stats=$(python3 - "$quanminer_stats" "$quanminer_version" <<'PY' 2>/dev/null
import json, sys
try:
    d = json.loads(sys.argv[1])
    if isinstance(d, dict):
        d["ver"] = sys.argv[2]
        vals = d.get("hs") or []
        unit = str(d.get("hs_units") or "khs").lower()
        factor = {"hs":0.001,"khs":1.0,"mhs":1000.0,"ghs":1000000.0,"ths":1000000000.0}.get(unit,1.0)
        khs = sum(float(x or 0) for x in vals) * factor
        print(json.dumps(d) + "\t" + repr(round(khs, 3)))
    else:
        print("")
except Exception:
    print("")
PY
)
    if [[ -n $quanminer_stats && $stats == *$'\t'* ]]; then
        khs=${stats#*$'\t'}
        stats=${stats%$'\t'*}
    else
        khs=0
        stats='{"hs":[],"hs_units":"khs","temp":[],"fan":[],"uptime":0,"ver":"'"$quanminer_version"'","ar":[0,0],"algo":"qpow"}'
    fi
else
    khs=0
    stats='{"hs":[],"hs_units":"khs","temp":[],"fan":[],"uptime":0,"ver":"'"$quanminer_version"'","ar":[0,0],"algo":"qpow"}'
fi
