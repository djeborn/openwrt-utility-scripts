# TTL Bypass Helper

Version: 0.1.0

Helper script for applying nftables-based TTL/HopLimit adjustments. See
external write-ups on carrier TTL/workarounds for background reading.

## What It Does

This version uses fw4 "chain-pre" snippets instead of directly adding rules
with `nft`.

- Writes a snippet file under `/usr/share/nftables.d/chain-pre/mangle_postrouting`
   containing the TTL/HopLimit rewrite lines.
- Reloads `fw4` to apply changes.
- Supports `--create` to create the parent directory when needed.

## Local summary

This helper implements a simple ttl/hoplimit rewrite using fw4 snippets. The
snippet contains simple nft expressions which are evaluated in the
`mangle_postrouting` chain context by fw4. Key points:

- The snippet contains the expressions `ip ttl set <value>` and
  `ip6 hoplimit set <value>`.
- Changes are applied via `fw4 reload` so they integrate with fw4-managed
  tables and other snippets.
- The default TTL is `65` but you can change it with `--ttl`.

Example snippet (conceptual):

```sh
ip ttl set 65
ip6 hoplimit set 65
```

## Requirements

- OpenWrt using `fw4`/nftables (22.03+)
- `fw4` helper installed (default in modern OpenWrt builds)
- Permission to write to `/usr/share/nftables.d/chain-pre/mangle_postrouting`

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
/root/Scripts/nft-ttl-adjust/nft-ttl-adjust.sh --interface usb0 --ttl 65
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
