#!/usr/bin/env bash
# HiveOS sources this file after wallet.conf and calls miner_ver/miner_config_gen.
# The generated file is NUL-delimited so credentials are never eval'd.
#
# Flight-sheet mapping for the high-performance quanpool-miner (QUIC over UDP):
#   Pool URL           -> --node-addr  (host:port; quic+udp:// prefix accepted;
#                         a hostname is resolved at start time by h-run.sh)
#   Wallet template    -> --auth-token (use %WAL%.%WORKER_NAME%)
#   Password           -> --tls-cert-sha256 when it is a 64-char hex pool
#                         certificate fingerprint (get it from your pool's
#                         connection page); REQUIRED for our pool's pinned cert.
#   Extra config args  -> passed through, usually blank (e.g. --gpu-devices 2 to
#                         cap to 2 cards, --cpu-workers <N> to enable CPU, or an
#                         explicit --tls-cert-sha256 override)
#
# quanpool-miner is a high-performance quantus-miner build (v6, native CUDA by
# default — no Vulkan/wgpu runtime needed). It carries a 5% miner dev fee. It
# defaults to its own built-in pool, so --node-addr (from Pool URL) is REQUIRED
# here to point it at this pool.

quanminer_trim() {
    local value=$1
    value=${value#"${value%%[![:space:]]*}"}
    value=${value%"${value##*[![:space:]]}"}
    printf '%s' "$value"
}

miner_ver() {
    local directory version=""
    directory="/hive/miners/custom/${CUSTOM_NAME:-quanminer}"
    if [[ -x "$directory/quanpool-miner" ]]; then
        version=$("$directory/quanpool-miner" --version 2>/dev/null \
            | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1 | tr -d '\r')
    fi
    printf '%s\n' "${version:-${CUSTOM_VERSION:-unknown}}"
}

miner_config_gen() {
    local config_file url template worker wallet pass line
    local -a args=() extra=()
    local explicit_fp=0 explicit_metrics=0 explicit_mode=0

    [[ -n ${CUSTOM_URL:-} ]] || {
        echo "ERROR: no pool URL set in the HiveOS flight sheet" >&2
        return 1
    }
    [[ -n ${CUSTOM_TEMPLATE:-} ]] || {
        echo "ERROR: no wallet/worker template set in the HiveOS flight sheet" >&2
        return 1
    }

    config_file=${CUSTOM_CONFIG_FILENAME:-/hive/miners/custom/quanminer/quanminer.conf}
    if declare -f mkfile_from_symlink >/dev/null 2>&1; then
        mkfile_from_symlink "$config_file"
    else
        mkdir -p "$(dirname "$config_file")" || return 1
        : >"$config_file" || return 1
    fi

    # Extra config is tokenized without eval.
    if [[ -n ${CUSTOM_USER_CONFIG:-} ]]; then
        while IFS= read -r line; do
            line=${line%%#*}
            line=$(quanminer_trim "$line")
            [[ -n $line ]] || continue
            local -a tokens=()
            read -r -a tokens <<<"$line"
            extra+=("${tokens[@]}")
        done <<<"$(printf '%s' "$CUSTOM_USER_CONFIG" | tr ';' '\n')"
    fi
    local i
    for ((i = 0; i < ${#extra[@]}; i++)); do
        case ${extra[i]} in
            --tls-cert-sha256|--tls-cert-sha256=*|--tls-cert-sha256-file|--tls-cert-sha256-file=*) explicit_fp=1 ;;
            --metrics-port|--metrics-port=*) explicit_metrics=1 ;;
            --mode|--mode=*) explicit_mode=1 ;;
        esac
    done

    # quanpool-miner takes exactly one node address; use the first pool URL.
    url=$(printf '%s' "$CUSTOM_URL" | tr ',;' '\n' | head -1)
    url=$(quanminer_trim "$url")
    url=${url#quic+udp://}
    url=${url#udp://}
    url=${url#stratum+ssl://}   # tolerate a pasted stratum URL; port decides
    url=${url#stratum+tcp://}
    [[ -n $url ]] || { echo "ERROR: empty pool URL" >&2; return 1; }
    args+=(serve --node-addr "$url")

    template=$CUSTOM_TEMPLATE
    if [[ $template == *%* ]]; then
        worker=${WORKER_NAME:-${RIG_NAME:-$(hostname -s 2>/dev/null || hostname)}}
        wallet=${WAL:-${EWAL:-${WALLET:-${WALLET_ADDRESS:-}}}}
        template=${template//%WORKER_NAME%/$worker}
        template=${template//%WORKER%/$worker}
        [[ -n $wallet ]] && template=${template//%WAL%/$wallet}
        [[ -n ${EWAL:-} ]] && template=${template//%EWAL%/$EWAL}
        [[ $template != *%* ]] || {
            echo "ERROR: wallet/worker template contains an unexpanded HiveOS macro" >&2
            return 1
        }
    fi
    args+=(--auth-token "$template")

    # The pool certificate fingerprint comes from the Password field (64 hex)
    # or from an explicit extra argument; without one the miner cannot pin the
    # pool's QUIC certificate and will refuse to connect.
    if ((explicit_fp == 0)); then
        pass=$(quanminer_trim "${CUSTOM_PASS:-}")
        if [[ $pass =~ ^[0-9a-fA-F]{64}$ ]]; then
            args+=(--tls-cert-sha256 "$(printf '%s' "$pass" | tr '[:upper:]' '[:lower:]')")
        else
            echo "ERROR: set the pool TLS certificate fingerprint (64 hex chars) in the Password field, or pass --tls-cert-sha256 in Extra config arguments" >&2
            return 1
        fi
    fi

    # h-stats.sh consumes this exact metrics port (quanpool-miner /hive-stats).
    ((explicit_metrics)) || args+=(--metrics-port "${CUSTOM_API_PORT:-9900}")

    # Pool mining (share difficulty). quanpool-miner defaults to pool mode; set
    # it explicitly unless the flight sheet already passed --mode.
    ((explicit_mode)) || args+=(--mode pool)

    args+=("${extra[@]}")

    umask 077
    printf '%s\0' "${args[@]}" >"$config_file" || return 1
    chmod 600 "$config_file" || return 1
}

miner_config_gen || return $?
