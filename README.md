
# OpenWrt helper scripts

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](./LICENSE)

Lightweight collection of small shell scripts and helpers aimed at OpenWrt-based routers and devices. Each script is self-contained and lives under `Scripts/` with its own README detailing options and examples.

## Contents

- `Scripts/nft-ttl-adjust/` - Helper to adjust packet TTLs (nftables-based helper). See `Scripts/nft-ttl-adjust/README.md` for details and usage examples.
- `Scripts/usb-tether-monitor/` - Monitor USB tethering state and run user-defined hooks (bring interface up/down, notify, log). See `Scripts/usb-tether-monitor/README.md` for details.

## Intended use / contract

- Inputs: shell environment on an OpenWrt or Linux-based router, installed dependencies noted in each script's README (usually `nft`, `ip`, `grep`, `awk`, busybox utilities).
- Outputs: script-specific actions (nft rules adjustments, interface state changes, logs) and informative exit codes (0 on success, non-zero on error).
- Error modes: missing dependencies, insufficient permissions (scripts need to run as root), unsupported kernel/netfilter configuration.

If something needs root privileges the script will usually indicate it — run under root or via an init/hotplug mechanism on OpenWrt.

## Quick start


1. Inspect the per-script README files for configuration and examples:

    - `Scripts/nft-ttl-adjust/README.md`
    - `Scripts/usb-tether-monitor/README.md`

1. Make a copy to your router and mark executable:

```sh
# copy to router (example using scp)
scp -r Scripts/* root@your-router:/usr/local/bin/

# on the router
chmod +x /usr/local/bin/nft-ttl-adjust.sh
chmod +x /usr/local/bin/usb-tether-monitor.sh
```

1. Run manually for testing, then install as a service, hotplug or cron job as appropriate for your setup. On OpenWrt you can integrate scripts via `/etc/init.d/` or add them to hotplug events.

## Examples

See the embedded README in each script's folder for concrete command-line examples. Example (testing on a router shell):

```sh
# run the USB tether monitor once (interactive test)
/usr/local/bin/usb-tether-monitor.sh --test

# show nft-ttl-adjust help
/usr/local/bin/nft-ttl-adjust.sh --help
```

## Requirements

- OpenWrt or a Linux-based router
- `nft` (nftables) for `nft-ttl-adjust` if you plan to use nft-based rules
- BusyBox coreutils (installed by default on OpenWrt)
- Root or equivalent privileges to modify interfaces and firewall/nft rules

If you're missing a tool, check the per-script README where common requirements are listed.

## Troubleshooting

- Script exits with permission errors: re-run as root or via sudo/procd/init.d.
- nft operations fail: verify `nft` is installed and kernel supports nftables.
- USB tethering not detected: check `dmesg` and `logread` on OpenWrt; ensure your device enumerates as a network interface.

For persistent issues, enable debug/logging shown in each script's README and file an issue with logs attached.

## Contributing

Contributions are welcome. Please open a pull request with:

- A short description of the change
- Why it's needed (bug, feature, portability)
- Minimal test instructions

Keep changes small and script-compatible with BusyBox shells where possible.

## License

These scripts are provided under the MIT License — see `LICENSE` if present in this repository. If no license file exists, contact the repository owner for clarification before reuse in production.

## Notes / assumptions

- These scripts were written as small utilities for OpenWrt-style environments; they assume a POSIX-like shell and common utilities are available.
- For full, authoritative usage follow each script's README in `Scripts/<script-name>/README.md`.

---

If you'd like, I can also:

- Extract and summarize the usage examples from each script's README and embed them into this root README.
- Add an explicit `LICENSE` file (MIT) if you want to publish this repository with permissive licensing.


