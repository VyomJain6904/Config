# Quickshell Go helper

`qs-helper` is the native backend for the controls, network, VPN, and calendar
QML models. Quickshell invokes one binary with a domain and the existing action:

```text
qs-helper controls volume-status
qs-helper network wifi-scan --rescan no
qs-helper vpn status
qs-helper calendar events 7 2026
```

The helper keeps the existing stdout and exit-code contracts used by the QML
models. It still delegates desktop integration to the system tools already used
by the previous helpers: `wpctl`, `pactl`, `brightnessctl`, `playerctl`,
`bluetoothctl`, `nmcli`, `iw`, `ip`, `iptables`, `warp-cli`, `systemctl`, and
the local OpenVPN wrapper.

Build and test:

```sh
make test
make build
```

The binary is written to `helpers/bin/qs-helper`. The build artifact is ignored
by Git because it is architecture-specific.
