# TTL Bypass Helper

Helper script for applying nftables-based TTL/HopLimit adjustments. See
external write-ups on carrier TTL/workarounds for background reading.

## What It Does

- Adds IPv4 and IPv6 rules to the default `inet fw4 mangle_forward` chain
- Sets TTL/HopLimit to 117 (common carrier recommendation)
- Tags rules with comments so they can be removed cleanly
- Supports custom interface names and TTL values
- Provides a status view and clean removal option

## Local summary

This helper implements a simple ttl/hoplimit rewrite using nftables. The
approach matches outgoing packets on a specified interface and sets the IPv4
TTL or IPv6 HopLimit to a fixed value so that downstream carrier systems see
the packet as if it originated from a handset. Key points:

- Rules are added to the `inet fw4 mangle_forward` chain and match by
   `oifname <interface>`.
- IPv4 uses `ip ttl set <value>`, IPv6 uses `ip6 hoplimit set <value>`.
- Rules are inserted with unique comments so the script can find and remove
   them cleanly later.
- The default value `117` is commonly used by several carriers; change it if
   you have a different recommended value.

Example nft rule (conceptual):

```nft
# IPv4
nft add rule inet fw4 mangle_forward oifname "usb0" ip ttl set 117 comment "ttl-adjust-ipv4"
# IPv6
nft add rule inet fw4 mangle_forward oifname "usb0" ip6 hoplimit set 117 comment "ttl-adjust-ipv6"
```

## Requirements

- OpenWrt using `fw4`/nftables (22.03+)
- `nft` binary installed (default in modern OpenWrt builds)
- The interface you intend to manipulate (defaults to `usb0`, adjust as needed)

## Installation

1. Copy `nft-ttl-adjust.sh` to your router, e.g. `/root/Scripts/nft-ttl-adjust/`:

   ```sh
   mkdir -p /root/Scripts/nft-ttl-adjust
   scp Scripts/nft-ttl-adjust/nft-ttl-adjust.sh \
      root@router-ip:/root/Scripts/nft-ttl-adjust/
   chmod +x /root/Scripts/nft-ttl-adjust/nft-ttl-adjust.sh
   ```

2. (Optional) Place a wrapper call in `/etc/rc.local` or a procd init script if you
   want the rules restored on every boot.

## Usage

### Apply (default)

```sh
/root/Scripts/nft-ttl-adjust/nft-ttl-adjust.sh --interface usb0 --ttl 117
```

### Remove the rules

```sh
/root/Scripts/nft-ttl-adjust/nft-ttl-adjust.sh --remove
```

### Check status

```sh
/root/Scripts/nft-ttl-adjust/nft-ttl-adjust.sh --status
```

### Quiet mode

Suppress informational logs (suitable for cron):

```sh
/root/Scripts/nft-ttl-adjust/nft-ttl-adjust.sh --quiet
```

## Automating at Boot

Add to `/etc/rc.local` before the `exit 0` line:

```sh
/root/Scripts/nft-ttl-adjust/nft-ttl-adjust.sh --quiet
```

Or create a simple procd init script similar to the tether monitor to call the script during startup.

## Troubleshooting

- Ensure `nft list chain inet fw4 mangle_forward` succeeds (fw4 running)
- Confirm the interface name matches your WAN uplink (e.g. `wan`, `wwan0`, `usb0`)
- Run with `--status` to verify the rules were inserted
- Use `--remove` if you need to clean up before experimenting with different values
