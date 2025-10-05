# Visible TTL Bypass Helper

Helper script for applying the nftables-based TTL/HopLimit adjustments described in
[Restoring Carrier Throttle Bypass After OpenWrt Update (Visible Network TTL Fix)](https://black.jmyntrn.com/2025/10/05/openwrt-visible-network-ttl-bypass-fix/).

## What It Does

- Adds IPv4 and IPv6 rules to the default `inet fw4 mangle_forward` chain
- Sets TTL/HopLimit to 117 (Visible Wireless recommendation)
- Tags rules with comments so they can be removed cleanly
- Supports custom interface names and TTL values
- Provides a status view and clean removal option

## Requirements

- OpenWrt using `fw4`/nftables (22.03+)
- `nft` binary installed (default in modern OpenWrt builds)
- The interface you intend to manipulate (defaults to `usb0`, adjust as needed)

## Installation

1. Copy `nft-ttl-adjust.sh` to your router, e.g. `/root/Scripts/visible-ttl-fix/`:

   ```sh
   mkdir -p /root/Scripts/visible-ttl-fix
   scp Scripts/visible-ttl-fix/nft-ttl-adjust.sh \
      root@router-ip:/root/Scripts/visible-ttl-fix/
   chmod +x /root/Scripts/visible-ttl-fix/nft-ttl-adjust.sh
   ```

2. (Optional) Place a wrapper call in `/etc/rc.local` or a procd init script if you
   want the rules restored on every boot.

## Usage

### Apply (default)

```sh
/root/Scripts/visible-ttl-fix/nft-ttl-adjust.sh --interface usb0 --ttl 117
```

### Remove the rules

```sh
/root/Scripts/visible-ttl-fix/nft-ttl-adjust.sh --remove
```

### Check status

```sh
/root/Scripts/visible-ttl-fix/nft-ttl-adjust.sh --status
```

### Quiet mode

Suppress informational logs (suitable for cron):

```sh
/root/Scripts/visible-ttl-fix/nft-ttl-adjust.sh --quiet
```

## Automating at Boot

Add to `/etc/rc.local` before the `exit 0` line:

```sh
/root/Scripts/visible-ttl-fix/nft-ttl-adjust.sh --quiet
```

Or create a simple procd init script similar to the tether monitor to call the script during startup.

## Troubleshooting

- Ensure `nft list chain inet fw4 mangle_forward` succeeds (fw4 running)
- Confirm the interface name matches your WAN uplink (e.g. `wan`, `wwan0`, `usb0`)
- Run with `--status` to verify the rules were inserted
- Use `--remove` if you need to clean up before experimenting with different values
