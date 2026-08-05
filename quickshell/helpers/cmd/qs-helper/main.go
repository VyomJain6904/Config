package main

import (
	"fmt"
	"os"

	"quickshell/helpers/internal/ai"
	"quickshell/helpers/internal/calendar"
	"quickshell/helpers/internal/clipboard"
	"quickshell/helpers/internal/controls"
	"quickshell/helpers/internal/launcher"
	"quickshell/helpers/internal/network"
	"quickshell/helpers/internal/polkit"
	"quickshell/helpers/internal/vpn"
	"quickshell/helpers/internal/wallpaper"
)

func main() {
	if len(os.Args) < 2 {
		fmt.Fprintln(os.Stderr, "usage: qs-helper <clipboard|controls|launcher|network|vpn|calendar|ai|wallpaper> [action] [args...]")
		os.Exit(2)
	}

	var code int
	switch os.Args[1] {
	case "clipboard":
		code = clipboard.Run(os.Args[2:])
	case "controls":
		code = controls.Run(os.Args[2:])
	case "launcher":
		code = launcher.Run(os.Args[2:])
	case "network":
		code = network.Run(os.Args[2:])
	case "vpn":
		code = vpn.Run(os.Args[2:])
	case "polkit":
		code = polkit.Run(os.Args[2:])
	case "calendar":
		code = calendar.Run(os.Args[2:])
	case "ai":
		code = ai.Run(os.Args[2:])
	case "wallpaper":
		code = wallpaper.Run(os.Args[2:])
	default:
		fmt.Fprintf(os.Stderr, "unknown helper: %s\n", os.Args[1])
		code = 2
	}
	os.Exit(code)
}
