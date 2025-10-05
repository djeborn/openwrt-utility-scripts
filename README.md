# OpenWrt USB Tethering Monitor

Monitor and automatically recover internet connectivity on an OpenWrt router that relies on an Android phone for USB tethering. The repository centres around a shell script, `usb-tether-monitor.sh`, which watches connectivity, restarts tethering when needed, and offers a handful of operator-friendly switches and config hooks.

## Repository Structure

- `Scripts/usb-tether-monitor/usb-tether-monitor.sh` – main monitoring script.
- `Scripts/usb-tether-monitor/README.md` – detailed setup guide specific to the script.
- `Scripts/usb-tether-monitor/` – place for auxiliary assets (init scripts, configs, helpers).
- `Scripts/nft-ttl-adjust/nft-ttl-adjust.sh` – Visible Wireless TTL/HopLimit helper.
- `Scripts/nft-ttl-adjust/README.md` – usage notes for the TTL helper.
- Root `README.md` (this file) – high-level overview and quick start.

## Feature Highlights

- 🟢 Automatic recovery when pings to public targets fail.
- 🔁 Smart retry cycles and verification after tethering restarts.
- 🎨 Colorised, timestamped logs with auto-disable on non-interactive outputs.
- ⚙️ Runtime configuration via optional config file or CLI flags.
- 🔄 Single-run and continuous monitoring modes.
- 📝 Optional `--print-config` summary for quick diagnostics.

## Requirements

### Router

- OpenWrt 19.07 or newer (tested on BusyBox `ash`).
- USB host port with power for the phone.
- Packages: `adb`, `kmod-usb-net-rndis`, `kmod-usb-net-cdc-ether`, and a `ping` implementation (BusyBox or `iputils`).

### Android Phone

- Android 5.0 (Lollipop) or newer with USB tethering support.
- USB debugging enabled (Developer Options) and authorised for the router.
- Reliable mobile data or upstream Wi-Fi connection.

## Quick Start

1. SSH into your OpenWrt router and install dependencies:

   ```sh
   opkg update
   opkg install kmod-usb-net-rndis kmod-usb-net-cdc-ether adb iputils-ping
   ```

2. Copy the script onto the router (default location shown):

   ```sh
   mkdir -p /root/Scripts/usb-tether-monitor
   scp Scripts/usb-tether-monitor/usb-tether-monitor.sh \
      root@router-ip:/root/Scripts/usb-tether-monitor/
   chmod +x /root/Scripts/usb-tether-monitor/usb-tether-monitor.sh
   ```

3. Connect your Android phone via USB, enable USB tethering once, and authorise USB debugging when prompted.

4. Run a manual check:

   ```sh
   /root/Scripts/usb-tether-monitor/usb-tether-monitor.sh
   ```

## Configuration Options

The script uses built-in defaults but can be customised in three ways:

1. **External config file** (default path `/etc/usb-tether-monitor.conf`). Any shell assignments placed here override defaults. Example:

   ```sh
   # /etc/usb-tether-monitor.conf
   PING_TARGETS='1.1.1.1 9.9.9.9'
   CONTINUOUS_MODE=1
   CHECK_INTERVAL=120
   ENABLE_COLORS=0
   ```

2. **Command-line flags** (`--no-default-config`, `--config`, `--continuous`, `--interval`, etc.) to override specific values at runtime. See `--help` for the full list:

   ```sh
    /root/Scripts/usb-tether-monitor/usb-tether-monitor.sh \
       --continuous --interval 90 --targets "1.1.1.1 8.8.8.8" --max-retries 5
   ```

3. **Inline edits**: modify the defaults near the top of `usb-tether-monitor.sh` if you prefer a baked-in configuration.

### Colour Output

- Colours are on by default when stdout is a TTY.
- Disable permanently via `ENABLE_COLORS=0` (config or CLI `--no-color`).

### Print Effective Configuration

Inspect the active settings without performing checks:

```sh
/root/Scripts/usb-tether-monitor/usb-tether-monitor.sh --print-config
```

## Running Continuously

### Background Job

```sh
/root/Scripts/usb-tether-monitor/usb-tether-monitor.sh --continuous &
```

### Cron Example

```sh
crontab -e
*/5 * * * * /root/Scripts/usb-tether-monitor/usb-tether-monitor.sh >> /var/log/usb-tethering.log 2>&1
```

### Procd Service Skeleton (Optional)

Create `/etc/init.d/usb-tether-monitor` and enable it to run on boot. A minimal skeleton:

```sh
#!/bin/sh /etc/rc.common
START=95
USE_PROCD=1
PROG=/root/Scripts/usb-tether-monitor/usb-tether-monitor.sh

start_service() {
	 procd_open_instance
   procd_set_param command $PROG --continuous
   procd_set_param respawn
   procd_set_param stdout 1
   procd_set_param stderr 1
   procd_close_instance
}
```

Remember to make it executable and enable it:

```sh
chmod +x /etc/init.d/usb-tether-monitor
/etc/init.d/usb-tether-monitor enable
/etc/init.d/usb-tether-monitor start
```

## TTL Bypass Helper (snippet-based)

The `Scripts/nft-ttl-adjust/nft-ttl-adjust.sh` helper now manages a small
drop-in snippet for `fw4` instead of directly adding/removing rules with
`nft`. This aligns with OpenWrt's `fw4` snippet mechanism and makes the
changes persistent and easy to manage via the normal `fw4 reload` flow.

What it does now:

- Writes a snippet file at `/usr/share/nftables.d/chain-pre/mangle_postrouting/01-set-ttl.nft`
   containing two simple rewrite lines:
   - `ip ttl set <value>`
   - `ip6 hoplimit set <value>`
- Calls `fw4 reload` after creating or removing the snippet so the change is applied.
- Supports `--create` to create the parent directory if it's missing.

Examples

Apply (default) — creates the snippet and reloads fw4:

```sh
/root/Scripts/nft-ttl-adjust/nft-ttl-adjust.sh --ttl 65 --create --apply
```

Remove the snippet and reload fw4:

```sh
/root/Scripts/nft-ttl-adjust/nft-ttl-adjust.sh --remove
```

Check status (prints the snippet contents or `(none)`):

```sh
/root/Scripts/nft-ttl-adjust/nft-ttl-adjust.sh --status
```

If you'd rather have the script insert full nftable rules into a chain, the
older behaviour (direct `nft add rule ...`) is available in previous
commits, but the snippet approach is recommended for fw4-managed systems.

## Troubleshooting Cheatsheet

- **`adb devices` shows `unauthorized`** – unlock the phone, accept the debugging prompt, then rerun the script.
- **No `usb0` interface** – ensure `kmod-usb-net-rndis` and `kmod-usb-net-cdc-ether` are loaded; check `dmesg` for USB errors.
- **Script exits with `EXIT_MISSING_PING`** – install `iputils-ping` or ensure BusyBox `ping` is present.
- **Colours in logs are garbled** – add `--no-color` or set `ENABLE_COLORS=0`.
- **Need more diagnostics** – run `usb-tether-monitor.sh --print-config` and inspect `/proc/net/dev` for the tether interface.

## Contributing

Bug reports, feature ideas, and pull requests are welcome. When contributing, please:

- Keep shell compatible with BusyBox `ash`.
- Add notes to `Scripts/usb-tether-monitor/README.md` if behaviour changes.
- Run shellcheck locally if available.

## License

Unless stated otherwise in individual files, this project is released under the MIT License.
