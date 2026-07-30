package main

import (
	"fmt"
	"os"

	"quickshell/helpers/internal/calendar"
	"quickshell/helpers/internal/clipboard"
	"quickshell/helpers/internal/controls"
	"quickshell/helpers/internal/network"
	"quickshell/helpers/internal/vpn"
)

func main() {
	if len(os.Args) < 2 {
		fmt.Fprintln(os.Stderr, "usage: qs-helper <clipboard|controls|network|vpn|calendar> [action] [args...]")
		os.Exit(2)
	}

	var code int
	switch os.Args[1] {
	case "clipboard":
		code = clipboard.Run(os.Args[2:])
	case "controls":
		code = controls.Run(os.Args[2:])
	case "network":
		code = network.Run(os.Args[2:])
	case "vpn":
		code = vpn.Run(os.Args[2:])
	case "calendar":
		code = calendar.Run(os.Args[2:])
	default:
		fmt.Fprintf(os.Stderr, "unknown helper: %s\n", os.Args[1])
		code = 2
	}
	os.Exit(code)
}
