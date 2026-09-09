#!/usr/bin/env bash
# Sourced by the HiveOS agent. Sets caller-scope `khs` and `stats`; never echo or exit.

quanminer_hive_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
quanminer_api_override=${CUSTOM_API_PORT:-}
quanminer_config_override=${CUSTOM_CONFIG_FILENAME:-}
. "$quanminer_hive_dir/h-manifest.conf"

quanminer_version=${CUSTOM_VERSION:-unknown}
if [[ -x "$quanminer_hive_dir/quantus-miner" ]]; then
    quanminer_bin_version=$("$quanminer_hive_dir/quantus-miner" --version 2>/dev/null \
        | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1 | tr -d '\r')
    [[ -n $quanminer_bin_version ]] && quanminer_version=$quanminer_bin_version
fi

quanminer_port=${quanminer_api_override:-${CUSTOM_API_PORT:-4067}}
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

# Prometheus text: miner_hash_rate (total H/s), miner_gpu_hash_rate,
# miner_cpu_hash_rate, miner_gpu_devices — verified against v4.0.2.
if command -v curl >/dev/null 2>&1; then
    quanminer_metrics=$(curl -fsS --max-time 3 "http://127.0.0.1:${quanminer_port}/metrics" 2>/dev/null)
else
    quanminer_metrics=$(wget -qO- -T 3 "http://127.0.0.1:${quanminer_port}/metrics" 2>/dev/null)
fi
if [[ -n $quanminer_metrics ]]; then
    quanminer_total=$(awk '$1=="miner_hash_rate"{print $2; exit}' <<<"$quanminer_metrics")
    quanminer_total=${quanminer_total:-0}
    khs=$(awk -v hs="$quanminer_total" 'BEGIN{printf "%.3f", hs/1000}')
    # Per-GPU temps/fans from the HiveOS gpu-stats snapshot when present.
    quanminer_temp="[]"; quanminer_fan="[]"
    if [[ -r /run/hive/gpu-stats.json ]] && command -v jq >/dev/null 2>&1; then
        quanminer_temp=$(jq -c '[.temp[]? // 0]' /run/hive/gpu-stats.json 2>/dev/null || printf '[]')
        quanminer_fan=$(jq -c '[.fan[]? // 0]' /run/hive/gpu-stats.json 2>/dev/null || printf '[]')
    fi
    stats=$(jq -nc \
        --arg ver "$quanminer_version" \
        --arg algo "qpow" \
        --argjson khs_total "$khs" \
        --argjson temp "$quanminer_temp" \
        --argjson fan "$quanminer_fan" \
        '{hs: [$khs_total], hs_units: "khs", total_khs: $khs_total,
          temp: $temp, fan: $fan, uptime: 0, ver: $ver, ar: [0, 0], algo: $algo}' \
        2>/dev/null)
    [[ -n $stats ]] || { khs=0; stats='{"hs":[],"hs_units":"khs","total_khs":0,"temp":[],"fan":[],"uptime":0,"ar":[0,0],"algo":"qpow"}'; }
else
    khs=0
    stats='{"hs":[],"hs_units":"khs","total_khs":0,"temp":[],"fan":[],"uptime":0,"ar":[0,0],"algo":"qpow"}'
fi
