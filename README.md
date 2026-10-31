# EasyTier for Omarchy

A small Omarchy bar widget showing EasyTier CLI status, the local node and peers, with IP copy actions and an optional system-service switch. It uses the existing `easytier-cli` RPC connection; no EasyTier GUI, tray daemon or persistent background service is required. Reading status does not need root.

## Requirements

- Omarchy shell with bar-widget plugin support
- Python 3 and `easytier-cli` on the shell's PATH; `wl-copy` for copying IP addresses
- A running EasyTier core with a reachable CLI RPC endpoint (the CLI's own default/configuration applies)
- For the optional system-service switch: systemd, `pkexec`, a polkit authentication agent, and a configured EasyTier system service

## Install

Install using `omarchy plugin add https://github.com/lszhe/omarchy-easytier --enable`, or place this directory in `~/.config/omarchy/plugins/local.easytier` and run:

```sh
omarchy plugin enable local.easytier
```

Move the widget with `omarchy bar move local.easytier --section right`. Left click opens the panel; `C` copies the local IP, `T` requests the service switch, `R` refreshes, and `Esc` closes. For a pending switch, use `Y` to confirm or `N` to cancel. Middle click refreshes from the bar. The default refresh interval is 30 seconds; it can be adjusted in widget settings.

The switch operates the **system** service named in the widget settings, defaulting to `easytier-omarchy.service` for the original setup. Set this to your actual service name before using the switch. Stopping it disconnects the associated EasyTier network. The panel asks for confirmation, then `pkexec` requests system authentication when required; the widget never stores a password. A missing, unknown or invalid service disables the switch. This does not control Clash, Tailscale, unrelated services, or GUI-managed instances.

The status says the CLI can reach the core, **not** that every peer or the internet is reachable. A missing CLI, unreachable RPC, or malformed response appears as unavailable. Node names and IP addresses are displayed locally; redact them before sharing screenshots. The helper discards the CLI's configuration output and only passes selected status fields to the widget.

## Development

```sh
python3 -m unittest discover -s tests
omarchy plugin validate .
```

The panel offers copy buttons for local and peer IP addresses. Copying strips any CIDR prefix from the address.

The small monochrome EasyTier icon is a simplified adaptation of the upstream icon; see [`assets/NOTICE.md`](assets/NOTICE.md) for attribution and its separate license.
