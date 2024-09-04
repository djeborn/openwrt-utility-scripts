#/bin/ash

# This script checks if the internet is down by pinging a target.
# If the ping fails, it will restart the USB tethering by disabling and enabling it via ADB.

# Set the target to ping and the number of pings
PING_TARGET='1.1.1.1'   # Public DNS server to ping
PING_COUNT=3            # Number of pings
SLEEP_TIME=5            # Time to wait before enabling USB tethering

# Check if ADB is installed
command -v adb > /dev/null 2>&1

# Check if the previous command was successful
if [ $? -ne 0 ]; then
  # If ADB is not installed, print an error message and exit
  echo "ADB is not installed. Please install ADB and try again."
  exit 1
fi

# Check if the phone is connected via ADB by listing the devices and grepping for 'usb'
adb devices -l | grep -q 'usb'

# Check if the previous command was successful
if [ $? -ne 0 ]; then
  # If the phone is not connected via ADB, print an error message and exit
  echo "Phone is not connected via ADB. Please connect the phone via USB and enable USB debugging."
  exit 1
fi

# Print a message indicating that the script is checking the internet connection status
echo "Checking internet connection status..."

# Ping the target
ping -c $PING_COUNT -q $PING_TARGET > /dev/null 2>&1

# Check if the ping was successful
if [ $? -eq 0 ]; then
  # If the ping was successful, print a message
  echo "Internet is up!"
else
  # If the ping was unsuccessful, print a message
  echo "Internet is down! Restarting USB tethering..."

  # Restart the USB tethering by disabling and enabling it via ADB
  adb shell svc usb setFunctions none
  if [ $? -ne 0 ]; then
    echo "Failed to disable USB tethering. ADB returned error code $adb_result"
  fi
  sleep $SLEEP_TIME
  adb shell svc usb setFunctions rndis
  if [ $? -ne 0 ]; then
    echo "Failed to enable USB tethering. ADB returned error code $adb_result"
  fi
fi