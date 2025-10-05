#!/bin/ash
# ============================================================================
# nft-ttl-adjust.sh — generic nftables TTL/HopLimit adjuster for OpenWrt
# ----------------------------------------------------------------------------
# Adds or removes nftables rules which set IPv4 TTL and IPv6 hoplimit on a
# specified outgoing interface. This is a generic TTL/HopLimit adjuster
# helper and can be used for any carrier where masking TTL helps avoid
# throttling or classification issues.
# ============================================================================

set -e

DEFAULT_INTERFACE="usb0"
DEFAULT_TTL=65
# New approach: drop-in snippet management for fw4
PRE_DIR="/usr/share/nftables.d/chain-pre/mangle_postrouting"
SNIPPET_FILE="$PRE_DIR/01-set-ttl.nft"

TTL_VALUE="$DEFAULT_TTL"
INTERFACE_NAME="$DEFAULT_INTERFACE"
ACTION="apply"
QUIET=0
AUTO_CREATE=0

log() {
    if [ "$QUIET" -eq 1 ]; then
        return
    fi
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

error_exit() {
    echo "Error: $1" >&2
    exit 1
}

require_command() {
    command -v "$1" >/dev/null 2>&1 || error_exit "Required command '$1' not found"
}

is_positive_int() {
    case "$1" in
        ''|*[!0-9]*) return 1 ;;
        *) [ "$1" -gt 0 ] 2>/dev/null ;;
    esac
}

parse_args() {
    while [ $# -gt 0 ]; do
        case "$1" in
            --interface|--ifname)
                shift
                [ $# -gt 0 ] || error_exit "--interface requires a value"
                INTERFACE_NAME="$1"
                ;;
            --ttl)
                shift
                [ $# -gt 0 ] || error_exit "--ttl requires a value"
                is_positive_int "$1" || error_exit "TTL must be a positive integer"
                TTL_VALUE="$1"
                ;;
            --apply)
                ACTION="apply"
                ;;
            --remove|--delete)
                ACTION="remove"
                ;;
                    --create)
                        AUTO_CREATE=1
                        ;;
            --status)
                ACTION="status"
                ;;
            --quiet|-q)
                QUIET=1
                ;;
            --help|-h)
                usage
                exit 0
                ;;
            *)
                error_exit "Unknown option: $1"
                ;;
        esac
        shift
    done
}

usage() {
    cat <<'EOF'
Usage: nft-ttl-adjust.sh [options]

Options:
  --interface <ifname>   Output interface to match (default: usb0)
    --ttl <value>          TTL/HopLimit to set (default: 65)
    --apply                Apply (default action). This will create the snippet at
                                                 /usr/share/nftables.d/chain-pre/mangle_postrouting/01-set-ttl.nft
    --remove               Remove the snippet file and reload fw4
    --status               Show current snippet contents or (none)
    --quiet                Suppress informational output
        --create               Create parent directory if missing (requires privileges)
  --help                 Show this help text

Notes:
  * Requires nftables (fw4) and the default table inet fw4 on OpenWrt.
    * Writes a small fw4 drop-in snippet under /usr/share/nftables.d/chain-pre/mangle_postrouting
EOF
}

ensure_fw4_chain_exists() {
    # Ensure the drop-in directory exists (or allow --create to make it)
    if [ ! -d "$PRE_DIR" ]; then
        if [ "$AUTO_CREATE" -eq 1 ] 2>/dev/null; then
            log "Directory $PRE_DIR not found; creating it"
            mkdir -p "$PRE_DIR" || error_exit "Failed to create directory $PRE_DIR"
        else
            error_exit "Directory $PRE_DIR not found; run with --create to create it"
        fi
    fi
}

remove_rules() {
    if [ -f "$SNIPPET_FILE" ]; then
        log "Removing snippet $SNIPPET_FILE"
        rm -f "$SNIPPET_FILE" || error_exit "Failed to remove $SNIPPET_FILE"
        log "Reloading fw4"
        fw4 reload || error_exit "fw4 reload failed"
    else
        log "No snippet to remove at $SNIPPET_FILE"
    fi
}

apply_rules() {
    # Ensure parent dir exists (create if requested)
    if [ ! -d "$PRE_DIR" ]; then
        if [ "$AUTO_CREATE" -eq 1 ] 2>/dev/null; then
            log "Creating directory $PRE_DIR"
            mkdir -p "$PRE_DIR" || error_exit "Failed to create $PRE_DIR"
        else
            error_exit "Directory $PRE_DIR does not exist; run with --create to create it"
        fi
    fi

    log "Writing snippet to $SNIPPET_FILE with TTL $TTL_VALUE"
    tmpfile="${SNIPPET_FILE}.tmp.$$"
    {
        printf 'ip ttl set %s\n' "$TTL_VALUE"
        printf 'ip6 hoplimit set %s\n' "$TTL_VALUE"
    } >"$tmpfile" || error_exit "Failed to write temporary file $tmpfile"
    mv "$tmpfile" "$SNIPPET_FILE" || error_exit "Failed to move $tmpfile to $SNIPPET_FILE"
    log "Reloading fw4"
    fw4 reload || error_exit "fw4 reload failed"
}

show_status() {
    log "Current snippet at $SNIPPET_FILE"
    if [ -f "$SNIPPET_FILE" ]; then
        cat "$SNIPPET_FILE"
    else
        echo "(none)"
    fi
}

main() {
    parse_args "$@"
    require_command fw4
    ensure_fw4_chain_exists

    case "$ACTION" in
        apply)
            apply_rules
            ;;
        remove)
            remove_rules
            ;;
        status)
            show_status
            ;;
        *)
            error_exit "Unknown action: $ACTION"
            ;;
    esac
}

main "$@"
