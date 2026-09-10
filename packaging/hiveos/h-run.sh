#!/usr/bin/env bash
set -o pipefail

cd "$(dirname "$0")" || { echo "[h-run] cannot enter miner directory" >&2; exit 1; }
quanminer_config_override=${CUSTOM_CONFIG_FILENAME:-}
quanminer_log_override=${CUSTOM_LOG_BASENAME:-}
. ./h-manifest.conf

binary=./quanpool-miner
config=${quanminer_config_override:-${CUSTOM_CONFIG_FILENAME:-/hive/miners/custom/quanminer/quanminer.conf}}
log_base=${quanminer_log_override:-${CUSTOM_LOG_BASENAME:-/var/log/miner/custom/quanminer/quanminer}}

[[ -x $binary ]] || { echo "[h-run] quanpool-miner binary is missing or not executable" >&2; exit 127; }
[[ -s $config ]] || { echo "[h-run] generated config is missing; re-apply the flight sheet" >&2; exit 1; }

mapfile -d '' -t quanminer_args <"$config"
((${#quanminer_args[@]} > 0)) || { echo "[h-run] generated config is empty" >&2; exit 1; }

# quanpool-miner accepts only IP:PORT for --node-addr: resolve a hostname at
# start time so DNS changes take effect on every restart.
for ((i = 0; i < ${#quanminer_args[@]}; i++)); do
    if [[ ${quanminer_args[i]} == --node-addr ]] && ((i + 1 < ${#quanminer_args[@]})); then
        addr=${quanminer_args[i+1]}
        host=${addr%:*}
        port=${addr##*:}
        if [[ ! $host =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
            ip=$(getent ahostsv4 "$host" 2>/dev/null | awk '{print $1; exit}')
            [[ -n $ip ]] || { echo "[h-run] cannot resolve pool host $host" >&2; exit 1; }
            quanminer_args[i+1]="${ip}:${port}"
        fi
    fi
done

mkdir -p /run/hive "$(dirname "$log_base")" || exit 1
: >/run/hive/MINER_RUN
printf '%s\n' '{"status":"running"}' >/run/hive/miner_status.1
: >"${log_base}.log"

if pgrep -x quanpool-miner >/dev/null 2>&1; then
    echo "[h-run] quanpool-miner is already running" >&2
    exit 1
fi

echo "[h-run] starting quanpool-miner (pool credentials redacted)"
exec "$binary" "${quanminer_args[@]}" >>"${log_base}.log" 2>&1
