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
DEFAULT_TTL=117
TABLE_FAMILY="inet"
TABLE_NAME="fw4"
CHAIN_NAME="mangle_forward"
COMMENT_V4="ttl-adjust-ipv4"
COMMENT_V6="ttl-adjust-ipv6"

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
  --ttl <value>          TTL/HopLimit to set (default: 117)
  --apply                Apply (default action)
  --remove               Remove the TTL rules
  --status               Show current matching rules
  --quiet                Suppress informational output
    --create               Create table/chain if missing (requires nft privileges)
  --help                 Show this help text

Notes:
  * Requires nftables (fw4) and the default table inet fw4 on OpenWrt.
  * Adds two rules with comments "ttl-adjust-ipv4" and "ttl-adjust-ipv6".
EOF
}

ensure_fw4_chain_exists() {
    if ! nft list table "$TABLE_FAMILY" "$TABLE_NAME" >/dev/null 2>&1; then
        if [ "$AUTO_CREATE" -eq 1 ] 2>/dev/null; then
            log "Table $TABLE_FAMILY $TABLE_NAME not found; creating it"
            nft add table "$TABLE_FAMILY" "$TABLE_NAME" || error_exit "Failed to create table $TABLE_NAME"
        else
            error_exit "Table $TABLE_FAMILY $TABLE_NAME not found; ensure fw4 is active or run with --create"
        fi
    fi

    if ! nft list chain "$TABLE_FAMILY" "$TABLE_NAME" "$CHAIN_NAME" >/dev/null 2>&1; then
        if [ "$AUTO_CREATE" -eq 1 ] 2>/dev/null; then
            log "Chain $CHAIN_NAME not found in table $TABLE_NAME; creating chain"
            nft add chain "$TABLE_FAMILY" "$TABLE_NAME" "$CHAIN_NAME" \{ type filter hook forward priority 0; \} || error_exit "Failed to create chain $CHAIN_NAME"
        else
            error_exit "Chain $CHAIN_NAME not found in table $TABLE_NAME; run with --create to create it"
        fi
    fi
}

get_handles_by_comment() {
    local comment="$1"
    nft --handle --numeric list chain "$TABLE_FAMILY" "$TABLE_NAME" "$CHAIN_NAME" \
        2>/dev/null | awk -v c="$comment" '
            $0 ~ ("comment \"" c "\"") {
                for (i = 1; i <= NF; i++) {
                    if ($i == "handle") {
                        print $(i + 1)
                    }
                }
            }
        '
}

remove_rules() {
    local handles handle

    handles=$(get_handles_by_comment "$COMMENT_V4")
    for handle in $handles; do
        log "Removing IPv4 TTL rule (handle $handle)"
        nft delete rule "$TABLE_FAMILY" "$TABLE_NAME" "$CHAIN_NAME" handle "$handle"
    done

    handles=$(get_handles_by_comment "$COMMENT_V6")
    for handle in $handles; do
        log "Removing IPv6 HopLimit rule (handle $handle)"
        nft delete rule "$TABLE_FAMILY" "$TABLE_NAME" "$CHAIN_NAME" handle "$handle"
    done
}

apply_rules() {
    remove_rules

    log "Applying TTL adjust on interface '$INTERFACE_NAME' with TTL $TTL_VALUE"
    nft add rule "$TABLE_FAMILY" "$TABLE_NAME" "$CHAIN_NAME" \
        oifname "$INTERFACE_NAME" ip ttl set "$TTL_VALUE" comment "$COMMENT_V4"
    nft add rule "$TABLE_FAMILY" "$TABLE_NAME" "$CHAIN_NAME" \
        oifname "$INTERFACE_NAME" ip6 hoplimit set "$TTL_VALUE" comment "$COMMENT_V6"
}

show_status() {
    log "Current rules in $TABLE_FAMILY $TABLE_NAME $CHAIN_NAME containing 'ttl-adjust'"
    nft list chain "$TABLE_FAMILY" "$TABLE_NAME" "$CHAIN_NAME" 2>/dev/null | \
        grep 'ttl-adjust' || echo "(none)"
}

main() {
    parse_args "$@"
    require_command nft
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
