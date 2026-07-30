package clipboard

import (
	"fmt"
	"os"
	"os/exec"
	"strings"
)

func Run(argv []string) int {
	action := "copy"
	var args []string
	if len(argv) > 0 {
		action = argv[0]
		args = argv[1:]
	}

	switch action {
	case "copy":
		if len(args) == 0 {
			fmt.Fprintln(os.Stderr, "Missing clipboard text")
			return 2
		}
		text := strings.Join(args, " ")
		if code := copyToClipboard(text); code != 0 {
			return code
		}
		return 0
	default:
		fmt.Fprintf(os.Stderr, "Unknown action: %s\n", action)
		return 2
	}
}

func copyToClipboard(text string) int {
	candidates := []struct {
		name string
		args []string
	}{
		{name: "/usr/bin/wl-copy", args: []string{}},
		{name: "/usr/bin/xclip", args: []string{"-selection", "clipboard"}},
		{name: "/usr/bin/xsel", args: []string{"--clipboard", "--input"}},
	}

	var failures []string
	for _, candidate := range candidates {
		if err := writeClipboardInput(candidate.name, candidate.args, text); err == nil {
			return 0
		} else {
			failures = append(failures, fmt.Sprintf("%s: %v", candidate.name, err))
		}
	}
	fmt.Fprintln(os.Stderr, "Unable to copy to clipboard")
	for _, failure := range failures {
		fmt.Fprintln(os.Stderr, "  "+failure)
	}
	return 1
}

func writeClipboardInput(name string, args []string, text string) error {
	cmd := exec.Command(name, args...)
	cmd.Stdin = strings.NewReader(text)
	cmd.Stdout = nil
	cmd.Stderr = nil
	return cmd.Run()
}
