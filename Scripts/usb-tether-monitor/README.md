# USB Tethering Internet Monitor

A robust shell script for OpenWrt routers that automatically monitors and restarts USB tethering when internet connectivity is lost. This README was restored and includes setup instructions for OpenWrt and Android devices. The primary script is named `usb-tether-monitor.sh` in this folder.

## Features

- Automatic recovery: detects internet outages and restarts USB tethering.
- Multiple ping targets for redundancy.
- Retry logic with verification after restart.
- Optional continuous monitoring mode.
- Color-coded logging (can be disabled).
- Simple configuration options at the top of the script.

## Requirements

### OpenWrt Router

- OpenWrt 19.07 or newer.
- USB port.
- Packages: `adb`, `kmod-usb-net-rndis`, `kmod-usb-net-cdc-ether` (install with `opkg`).

### Android Phone

- Android 5.0 (Lollipop) or newer.
- USB data cable (not charge-only).
- USB Debugging enabled.
- USB Tethering capability.

## Installation (OpenWrt)

1. Update package lists:

```sh
opkg update
```

2. Install required packages:

```sh
opkg install kmod-usb-net-rndis kmod-usb-net-cdc-ether
opkg install adb
```

3. Create a directory and upload the script (recommended filename: `usb-tether-monitor.sh`):

```sh
mkdir -p /root/Scripts/usb-tether-monitor
# Upload the script to that folder (scp/wget/uploader). Recommended name:
# usb-tether-monitor.sh
chmod +x /root/Scripts/usb-tether-monitor/usb-tether-monitor.sh
```

4. Verify ADB is available on the router:

```sh
adb version
```

## Android Setup

1. Enable Developer Options: tap "Build number" 7 times in Settings → About phone.
2. Enable USB Debugging in Developer Options.
3. Ensure the phone has mobile data or Wi-Fi internet available.
4. Connect phone to router's USB port using a data-capable cable.
5. On your phone, accept the "Allow USB debugging?" prompt.

## Verifying Connection

On the router, run:

```sh
adb devices
```

You should see your device listed with the `device` state.

## Manual Tethering Commands

Enable tethering from the router:

```sh
adb shell svc usb setFunctions rndis
```

Disable tethering:

```sh
adb shell svc usb setFunctions none
```

## Configure Network Interface (OpenWrt)

After enabling USB tethering, the router may expose a `usb0` (or similar) interface. To configure a persistent interface, add to `/etc/config/network`:

```
config interface 'usbwan'
    option ifname 'usb0'
    option proto 'dhcp'
    option metric '10'
```

Restart network:

```sh
/etc/init.d/network restart
```

## Configuration Options (in script)

Open the top of the script (`usb-tether-monitor.sh`) and edit variables such as:

- `PING_TARGETS` - space-separated ping targets
- `PING_COUNT` - number of pings per target
- `PING_TIMEOUT` - per-ping timeout
- `MAX_RETRY_ATTEMPTS` - restart attempts
- `CONTINUOUS_MODE` - set to `1` to run continuously
- `ENABLE_COLORS` - set to `0` to disable colored output

## Running the Script

Single-run mode (default):

```sh
/root/Scripts/usb-tether-monitor/usb-tether-monitor.sh
```

Continuous mode (set `CONTINUOUS_MODE=1` in the script):

```sh
/root/Scripts/usb-tether-monitor/usb-tether-monitor.sh &
```

Run via cron (example, every 5 minutes):

```sh
# crontab -e
*/5 * * * * /root/Scripts/usb-tether-monitor/usb-tether-monitor.sh >> /var/log/usb-tethering.log 2>&1
```

## Troubleshooting

- If `adb` is missing, install it via `opkg` or provide a compatible binary for your architecture.
- If the phone shows `unauthorized` in `adb devices`, check the phone for the permission prompt.
- If `usb0` doesn't appear, ensure kernel modules `rndis`/`cdc` are loaded and check `dmesg`.

## Exit Codes

- `0` - Success
- `1` - ADB not installed
- `2` - No device connected
- `3` - Tethering restart failed
- `4` - Ping command not available
- `5` - Maximum retry attempts exceeded

## Security Notes

- USB Debugging grants elevated access to your phone. Only allow trusted hosts.
- Enabling "Always allow from this computer" gives the router permanent debugging access.

---

_Last updated: October 5, 2025_
