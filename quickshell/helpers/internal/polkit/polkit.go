package polkit

import (
	"fmt"
	"os"

	"quickshell/helpers/internal/common"
)

func Run(argv []string) int {
	action := "ensure"
	if len(argv) > 0 {
		action = argv[0]
	}
	switch action {
	case "ensure", "verify":
		if common.EnsurePolkitAgent() {
			fmt.Println("POLKIT active")
			return 0
		}
		fmt.Fprintln(os.Stderr, "POLKIT inactive: failed to launch UKUI polkit authentication agent")
		return 1
	case "status":
		if common.IsPolkitAgentRunning() {
			fmt.Println("running")
			return 0
		}
		fmt.Println("stopped")
		return 1
	default:
		fmt.Fprintf(os.Stderr, "unknown polkit action: %s\n", action)
		return 2
	}
}
