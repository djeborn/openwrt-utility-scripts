#!/bin/ash
set -u
# USB Tethering Internet Monitor (OpenWrt-friendly)
# Restored version with colored logging, retries, and continuous mode

# Default configuration file (optional)
DEFAULT_CONFIG_FILE='/etc/usb-tether-monitor.conf'
CONFIG_LOADED_FILES=''

# Configuration defaults (can be overridden via config file or CLI)
PING_TARGETS='1.1.1.1 8.8.8.8'   # Space-separated list of targets to ping
PING_COUNT=3                     # Number of pings per target
PING_TIMEOUT=5                   # Timeout in seconds for ping (per attempt)
TETHER_RESTART_DELAY=5           # Seconds to wait between disabling and enabling tethering
CONNECTIVITY_RECHECK_DELAY=10    # Seconds to wait before rechecking connectivity after restart
MAX_RETRY_ATTEMPTS=3             # Number of times to retry tethering restart
CONTINUOUS_MODE=0                # Set to 1 to run continuously
CHECK_INTERVAL=60                # Seconds between checks in continuous mode
ENABLE_COLORS=1                  # Set to 0 to disable colored output

# Internal flags
PRINT_CONFIG_ONLY=0
USE_DEFAULT_CONFIG=1

# Color placeholders (actual values assigned in init_colors)
COLOR_RESET=''
COLOR_RED=''
COLOR_GREEN=''
COLOR_YELLOW=''
COLOR_BLUE=''
COLOR_MAGENTA=''
COLOR_CYAN=''
COLOR_BOLD=''
COLOR_RED_BOLD=''
COLOR_GREEN_BOLD=''
COLOR_YELLOW_BOLD=''

# Exit codes
EXIT_SUCCESS=0
EXIT_MISSING_ADB=1
EXIT_NO_DEVICE=2
EXIT_TETHER_FAILURE=3
EXIT_MISSING_PING=4
EXIT_MAX_RETRIES=5

# Automatically disable colors when stdout is not a terminal
auto_disable_colors() {
    if [ "$ENABLE_COLORS" -eq 1 ] 2>/dev/null && [ ! -t 1 ]; then
        ENABLE_COLORS=0
    fi
}

# Initialize color codes (ANSI escape sequences)
init_colors() {
    if [ "$ENABLE_COLORS" -eq 1 ] 2>/dev/null; then
        COLOR_RESET='\033[0m'
        COLOR_RED='\033[0;31m'
        COLOR_GREEN='\033[0;32m'
        COLOR_YELLOW='\033[0;33m'
        COLOR_BLUE='\033[0;34m'
        COLOR_MAGENTA='\033[0;35m'
        COLOR_CYAN='\033[0;36m'
        COLOR_BOLD='\033[1m'
        COLOR_RED_BOLD='\033[1;31m'
        COLOR_GREEN_BOLD='\033[1;32m'
        COLOR_YELLOW_BOLD='\033[1;33m'
    else
        COLOR_RESET=''
        COLOR_RED=''
        COLOR_GREEN=''
        COLOR_YELLOW=''
        COLOR_BLUE=''
        COLOR_MAGENTA=''
        COLOR_CYAN=''
        COLOR_BOLD=''
        COLOR_RED_BOLD=''
        COLOR_GREEN_BOLD=''
        COLOR_YELLOW_BOLD=''
    fi
}

usage() {
    cat <<'EOF'
Usage: usb-tether-monitor.sh [options]

Options:
  --continuous               Run continuously (sets CONTINUOUS_MODE=1)
  --once                     Run a single connectivity check (default)
  --interval <seconds>       Interval between checks in continuous mode
  --targets "<list>"          Space-separated ping targets to check
  --ping-count <n>           Number of pings per target
  --timeout <seconds>        Ping timeout in seconds
  --restart-delay <seconds>  Delay between disabling and enabling tethering
  --recheck-delay <seconds>  Delay before verifying connectivity after restart
  --max-retries <n>          Maximum tethering restart attempts
  --config <path>            Load additional configuration file
  --no-default-config        Skip loading the default config file
  --no-color                 Disable colored output
  --color                    Force colored output
  --print-config             Show effective configuration and exit
  --help                     Show this help message
EOF
}

is_unsigned_integer() {
    case "$1" in
        ''|*[!0-9]*) return 1 ;;
        *) return 0 ;;
    esac
}

is_positive_integer() {
    if ! is_unsigned_integer "$1"; then
        return 1
    fi
    [ "$1" -gt 0 ] 2>/dev/null
}

load_config_file() {
    file="$1"
    if [ -z "$file" ]; then
        return 1
    fi

    if [ -f "$file" ]; then
        # shellcheck disable=SC1090
        . "$file"
        CONFIG_LOADED_FILES="$CONFIG_LOADED_FILES $file"
        return 0
    fi

    return 1
}

parse_args() {
    while [ $# -gt 0 ]; do
        case "$1" in
            --config)
                shift
                if [ $# -eq 0 ]; then
                    echo "Error: --config requires a file path" >&2
                    exit 1
                fi
                if ! load_config_file "$1"; then
                    echo "Error: Config file '$1' not found or unreadable" >&2
                    exit 1
                fi
                ;;
            --no-default-config)
                USE_DEFAULT_CONFIG=0
                ;;
            --continuous)
                CONTINUOUS_MODE=1
                ;;
            --once|--single)
                CONTINUOUS_MODE=0
                ;;
            --interval)
                shift
                if [ $# -eq 0 ] || ! is_positive_integer "$1"; then
                    echo "Error: --interval expects a positive integer (seconds)" >&2
                    exit 1
                fi
                CHECK_INTERVAL="$1"
                ;;
            --targets)
                shift
                if [ $# -eq 0 ]; then
                    echo "Error: --targets expects a space-separated list" >&2
                    exit 1
                fi
                PING_TARGETS="$1"
                ;;
            --ping-count)
                shift
                if [ $# -eq 0 ] || ! is_positive_integer "$1"; then
                    echo "Error: --ping-count expects a positive integer" >&2
                    exit 1
                fi
                PING_COUNT="$1"
                ;;
            --timeout)
                shift
                if [ $# -eq 0 ] || ! is_positive_integer "$1"; then
                    echo "Error: --timeout expects a positive integer" >&2
                    exit 1
                fi
                PING_TIMEOUT="$1"
                ;;
            --restart-delay)
                shift
                if [ $# -eq 0 ] || ! is_unsigned_integer "$1"; then
                    echo "Error: --restart-delay expects a non-negative integer" >&2
                    exit 1
                fi
                TETHER_RESTART_DELAY="$1"
                ;;
            --recheck-delay)
                shift
                if [ $# -eq 0 ] || ! is_unsigned_integer "$1"; then
                    echo "Error: --recheck-delay expects a non-negative integer" >&2
                    exit 1
                fi
                CONNECTIVITY_RECHECK_DELAY="$1"
                ;;
            --max-retries)
                shift
                if [ $# -eq 0 ] || ! is_positive_integer "$1"; then
                    echo "Error: --max-retries expects a positive integer" >&2
                    exit 1
                fi
                MAX_RETRY_ATTEMPTS="$1"
                ;;
            --no-color|--no-colour)
                ENABLE_COLORS=0
                ;;
            --color|--colour)
                ENABLE_COLORS=1
                ;;
            --print-config)
                PRINT_CONFIG_ONLY=1
                ;;
            --help|-h)
                usage
                exit 0
                ;;
            --)
                shift
                break
                ;;
            *)
                echo "Error: Unknown option '$1'" >&2
                usage >&2
                exit 1
                ;;
        esac
        shift
    done
}

preprocess_args_for_config() {
    for arg in "$@"; do
        case "$arg" in
            --no-default-config)
                USE_DEFAULT_CONFIG=0
                ;;
        esac
    done
}

validate_configuration() {
    if [ -z "${PING_TARGETS//[[:space:]]/}" ]; then
        echo "Configuration error: PING_TARGETS cannot be empty" >&2
        return 1
    fi

    if ! is_positive_integer "$PING_COUNT"; then
        echo "Configuration error: PING_COUNT must be a positive integer" >&2
        return 1
    fi

    if ! is_positive_integer "$PING_TIMEOUT"; then
        echo "Configuration error: PING_TIMEOUT must be a positive integer" >&2
        return 1
    fi

    if ! is_unsigned_integer "$TETHER_RESTART_DELAY"; then
        echo "Configuration error: TETHER_RESTART_DELAY must be a non-negative integer" >&2
        return 1
    fi

    if ! is_unsigned_integer "$CONNECTIVITY_RECHECK_DELAY"; then
        echo "Configuration error: CONNECTIVITY_RECHECK_DELAY must be a non-negative integer" >&2
        return 1
    fi

    if ! is_positive_integer "$MAX_RETRY_ATTEMPTS"; then
        echo "Configuration error: MAX_RETRY_ATTEMPTS must be a positive integer" >&2
        return 1
    fi

    if ! is_positive_integer "$CHECK_INTERVAL"; then
        echo "Configuration error: CHECK_INTERVAL must be a positive integer" >&2
        return 1
    fi

    case "$CONTINUOUS_MODE" in
        0|1) ;;
        *)
            echo "Configuration error: CONTINUOUS_MODE must be 0 or 1" >&2
            return 1
            ;;
    esac

    case "$ENABLE_COLORS" in
        0|1) ;;
        *)
            echo "Configuration error: ENABLE_COLORS must be 0 or 1" >&2
            return 1
            ;;
    esac

    return 0
}

print_effective_config() {
    echo "Effective configuration:"
    echo "  PING_TARGETS=\"$PING_TARGETS\""
    echo "  PING_COUNT=$PING_COUNT"
    echo "  PING_TIMEOUT=$PING_TIMEOUT"
    echo "  TETHER_RESTART_DELAY=$TETHER_RESTART_DELAY"
    echo "  CONNECTIVITY_RECHECK_DELAY=$CONNECTIVITY_RECHECK_DELAY"
    echo "  MAX_RETRY_ATTEMPTS=$MAX_RETRY_ATTEMPTS"
    echo "  CONTINUOUS_MODE=$CONTINUOUS_MODE"
    echo "  CHECK_INTERVAL=$CHECK_INTERVAL"
    echo "  ENABLE_COLORS=$ENABLE_COLORS"
    if [ -n "$CONFIG_LOADED_FILES" ]; then
        echo "  Loaded config file(s):${CONFIG_LOADED_FILES# }"
    else
        echo "  Loaded config file(s): (none)"
    fi
}

# Log a message to stdout with timestamp and color
# Usage: log_message "message" "LEVEL"
log_message() {
    local message="$1"
    local level="${2:-INFO}"
    local color_level

    case "$level" in
        ERROR)
            color_level="$COLOR_RED_BOLD"
            ;;
        SUCCESS)
            color_level="$COLOR_GREEN_BOLD"
            ;;
        WARNING)
            color_level="$COLOR_YELLOW_BOLD"
            ;;
        INFO)
            color_level="$COLOR_CYAN"
            ;;
        DEBUG)
            color_level="$COLOR_MAGENTA"
            ;;
        *)
            color_level="$COLOR_RESET"
            ;;
    esac

    # Print timestamp in blue, then [LEVEL] in level color, then message
    printf "%b [%b%b%b] %b\n" \
        "${COLOR_BLUE}$(date '+%Y-%m-%d %H:%M:%S')${COLOR_RESET}" \
        "${color_level}" "$level" "${COLOR_RESET}" \
        "$message"
}

# Check if a command exists in the system
check_command_exists() {
    command -v "$1" >/dev/null 2>&1
    return $?
}

# Check if the device is connected via ADB
check_device_connected() {
    # Look for a device listed as "device" (authorized)
    adb devices | awk 'NR>1 && $2=="device" { print $1; exit }' >/dev/null 2>&1
    return $?
}

ensure_prerequisites() {
    if ! check_command_exists ping; then
        log_message "ping command is not available. Please install iputils or busybox." "ERROR"
        exit $EXIT_MISSING_PING
    fi

    if ! check_command_exists adb; then
        log_message "ADB is not installed. Please install ADB and try again." "ERROR"
        exit $EXIT_MISSING_ADB
    fi

    if ! check_device_connected; then
        log_message "Phone is not connected via ADB. Please connect the phone via USB and enable USB debugging." "ERROR"
        exit $EXIT_NO_DEVICE
    fi
}

# Check internet connectivity by pinging multiple targets
check_internet() {
    local target

    for target in $PING_TARGETS; do
        # Use -c (count) and -W (timeout for reply, seconds) when available
        # If ping returns success, consider internet up
        if ping -c "$PING_COUNT" -W "$PING_TIMEOUT" -q "$target" >/dev/null 2>&1; then
            log_message "Successfully pinged ${target}" "SUCCESS"
            return 0
        fi
    done
    log_message "Failed to reach any ping target" "ERROR"
    return 1
}

# Disable USB tethering
disable_tethering() {
    local status

    log_message "Disabling USB tethering..." "INFO"
    adb shell svc usb setFunctions none >/dev/null 2>&1
    status=$?
    if [ "$status" -ne 0 ]; then
        log_message "Failed to disable USB tethering (status code: $status)" "ERROR"
        return 1
    fi
    return 0
}

# Enable USB tethering
enable_tethering() {
    local status

    log_message "Enabling USB tethering..." "INFO"
    adb shell svc usb setFunctions rndis >/dev/null 2>&1
    status=$?
    if [ "$status" -ne 0 ]; then
        log_message "Failed to enable USB tethering (status code: $status)" "ERROR"
        return 1
    fi
    return 0
}

# Restart USB tethering with verification
restart_tethering() {
    local attempt=1

    while [ "$attempt" -le "$MAX_RETRY_ATTEMPTS" ]; do
        log_message "Restarting USB tethering (attempt ${attempt}/${MAX_RETRY_ATTEMPTS})..." "WARNING"

        if ! disable_tethering; then
            log_message "Retry attempt ${attempt} failed at disable step" "ERROR"
            attempt=$((attempt + 1))
            [ "$attempt" -le "$MAX_RETRY_ATTEMPTS" ] && sleep "$TETHER_RESTART_DELAY"
            continue
        fi

        log_message "Waiting ${TETHER_RESTART_DELAY} seconds..." "DEBUG"
        sleep "$TETHER_RESTART_DELAY"

        if ! enable_tethering; then
            log_message "Retry attempt ${attempt} failed at enable step" "ERROR"
            attempt=$((attempt + 1))
            [ "$attempt" -le "$MAX_RETRY_ATTEMPTS" ] && sleep "$TETHER_RESTART_DELAY"
            continue
        fi

        # Wait for network to stabilize
        log_message "Waiting ${CONNECTIVITY_RECHECK_DELAY} seconds for connection to stabilize..." "DEBUG"
        sleep "$CONNECTIVITY_RECHECK_DELAY"

        # Verify connectivity
        if check_internet; then
            log_message "USB tethering restarted successfully - Internet connectivity restored!" "SUCCESS"
            return 0
        else
            log_message "Tethering restarted but connectivity not restored on attempt ${attempt}" "WARNING"
            attempt=$((attempt + 1))
            [ "$attempt" -le "$MAX_RETRY_ATTEMPTS" ] && sleep "$TETHER_RESTART_DELAY"
        fi
    done

    log_message "Failed to restart USB tethering after ${MAX_RETRY_ATTEMPTS} attempts" "ERROR"
    return $EXIT_MAX_RETRIES
}

# Perform a single connectivity check and restart if needed
perform_check() {
    local status

    log_message "Checking internet connection status..." "INFO"

    if check_internet; then
        log_message "Internet connection is UP!" "SUCCESS"
        return $EXIT_SUCCESS
    else
        log_message "Internet connection is DOWN!" "ERROR"

        if ! restart_tethering; then
            status=$?
            if [ "$status" -eq "$EXIT_MAX_RETRIES" ]; then
                log_message "Failed to restart USB tethering after all retry attempts" "ERROR"
            else
                log_message "Failed to restart USB tethering (status $status)" "ERROR"
            fi
            return "$status"
        fi
        return $EXIT_SUCCESS
    fi
}

# Main function - program entry point
main() {
    preprocess_args_for_config "$@"

    if [ "$USE_DEFAULT_CONFIG" -eq 1 ] 2>/dev/null; then
        load_config_file "$DEFAULT_CONFIG_FILE" >/dev/null 2>&1 || true
    fi

    parse_args "$@"

    if ! validate_configuration; then
        exit $EXIT_TETHER_FAILURE
    fi

    auto_disable_colors
    init_colors

    if [ "$PRINT_CONFIG_ONLY" -eq 1 ]; then
        print_effective_config
        exit $EXIT_SUCCESS
    fi

    trap 'log_message "Termination signal received. Exiting monitor." "WARNING"; exit 0' INT TERM

    local status

    printf "\n${COLOR_BOLD}${COLOR_CYAN}========================================${COLOR_RESET}\n"
    printf "${COLOR_BOLD}${COLOR_CYAN}  USB Tethering Internet Monitor${COLOR_RESET}\n"
    printf "${COLOR_BOLD}${COLOR_CYAN}========================================${COLOR_RESET}\n\n"

    if [ -n "$CONFIG_LOADED_FILES" ]; then
        log_message "Loaded config file(s):${CONFIG_LOADED_FILES# }" "DEBUG"
    else
        log_message "No config files detected; using built-in defaults" "DEBUG"
    fi

    ensure_prerequisites

    log_message "Configuration: Targets=(${PING_TARGETS}), PingCount=${PING_COUNT}, Timeout=${PING_TIMEOUT}s" "INFO"

    # Run in continuous mode or single check
    if [ "$CONTINUOUS_MODE" -eq 1 ] 2>/dev/null; then
        log_message "Running in continuous mode (check interval: ${CHECK_INTERVAL}s)" "INFO"

        while true; do
            if ! perform_check; then
                status=$?
                log_message "Monitor encountered an unrecoverable error (status $status); exiting." "ERROR"
                exit "$status"
            fi
            log_message "Waiting ${CHECK_INTERVAL} seconds until next check..." "DEBUG"
            sleep "$CHECK_INTERVAL"
        done
    else
        log_message "Running in single check mode" "INFO"
        if ! perform_check; then
            status=$?
            exit "$status"
        fi
    fi

    printf "\n${COLOR_BOLD}${COLOR_GREEN}========================================${COLOR_RESET}\n"
    printf "${COLOR_BOLD}${COLOR_GREEN}  Monitor Completed Successfully${COLOR_RESET}\n"
    printf "${COLOR_BOLD}${COLOR_GREEN}========================================${COLOR_RESET}\n\n"
    exit $EXIT_SUCCESS
}

# Run the main function
main "$@"
