#!/bin/ash
# ===========================================================================
# USB Tethering Internet Monitor
# ===========================================================================
# Description:  Monitors internet connectivity and automatically restarts
#               USB tethering when connection is lost
# Requirements: ADB installed and phone connected with USB debugging enabled
# ===========================================================================

# Configuration
PING_TARGET='1.1.1.1'   # Public DNS server to ping
PING_COUNT=3            # Number of pings
TETHER_RESTART_DELAY=5  # Seconds to wait between disabling and enabling tethering

# Exit codes
EXIT_SUCCESS=0
EXIT_MISSING_ADB=1
EXIT_NO_DEVICE=2
EXIT_TETHER_FAILURE=3

# Log a message to stdout with timestamp
log_message() {
    echo "[$(date)] $1"
}

# Check if a command exists in the system
check_command_exists() {
    command -v "$1" > /dev/null 2>&1
    return $?
}

# Check if the device is connected via ADB
check_device_connected() {
    adb devices -l | grep -q 'usb'
    return $?
}

# Check internet connectivity by pinging target
check_internet() {
    ping -c $PING_COUNT -q $PING_TARGET > /dev/null 2>&1
    return $?
}

# Disable USB tethering
disable_tethering() {
    log_message "Disabling USB tethering..."
    adb shell svc usb setFunctions none
    status=$?
    if [ $status -ne 0 ]; then
        log_message "Error: Failed to disable USB tethering (status code: $status)"
        return 1
    fi
    return 0
}

# Enable USB tethering
enable_tethering() {
    log_message "Enabling USB tethering..."
    adb shell svc usb setFunctions rndis
    status=$?
    if [ $status -ne 0 ]; then
        log_message "Error: Failed to enable USB tethering (status code: $status)"
        return 1
    fi
    return 0
}

# Restart USB tethering
restart_tethering() {
    log_message "Restarting USB tethering..."
    
    if ! disable_tethering; then
        return 1
    fi
    
    log_message "Waiting $TETHER_RESTART_DELAY seconds..."
    sleep $TETHER_RESTART_DELAY
    
    if ! enable_tethering; then
        return 1
    fi
    
    log_message "USB tethering restarted successfully"
    return 0
}

# Main function - program entry point
main() {
    # Check if ADB is installed
    if ! check_command_exists adb; then
        log_message "Error: ADB is not installed. Please install ADB and try again."
        exit $EXIT_MISSING_ADB
    fi

    # Check if phone is connected
    if ! check_device_connected; then
        log_message "Error: Phone is not connected via ADB. Please connect the phone via USB and enable USB debugging."
        exit $EXIT_NO_DEVICE
    fi

    log_message "Checking internet connection status..."

    # Check internet connectivity
    if check_internet; then
        log_message "Internet connection is up!"
    else
        log_message "Internet connection is down!"
        
        # Restart USB tethering
        if ! restart_tethering; then
            log_message "Failed to restart USB tethering"
            exit $EXIT_TETHER_FAILURE
        fi
    fi
    
    exit $EXIT_SUCCESS
}

# Run the main function
main
