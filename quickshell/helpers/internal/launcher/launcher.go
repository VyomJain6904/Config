package launcher

import (
	"bufio"
	"fmt"
	"os"
	"path/filepath"
	"sort"
	"strings"

	"quickshell/helpers/internal/common"
)

type AppEntry struct {
	Name     string
	Icon     string
	Exec     string
	Terminal bool
	Metadata string
	ID       string
}

func Run(args []string) int {
	if len(args) == 0 {
		fmt.Fprintln(os.Stderr, "usage: qs-helper launcher <list|launch> [args...]")
		return 2
	}

	switch args[0] {
	case "list":
		return listApps()
	case "launch":
		if len(args) < 2 {
			fmt.Fprintln(os.Stderr, "usage: qs-helper launcher launch <exec> [terminal_0_or_1]")
			return 2
		}
		execStr := args[1]
		term := false
		if len(args) > 2 && (args[2] == "1" || args[2] == "true" || args[2] == "yes") {
			term = true
		}
		return launchApp(execStr, term)
	default:
		fmt.Fprintf(os.Stderr, "unknown action: %s\n", args[0])
		return 2
	}
}

func appDirs() []string {
	home := common.HomeDir()

	dataHome := os.Getenv("XDG_DATA_HOME")
	if dataHome == "" {
		dataHome = filepath.Join(home, ".local", "share")
	}

	dataDirs := os.Getenv("XDG_DATA_DIRS")
	if dataDirs == "" {
		dataDirs = "/usr/local/share:/usr/share"
	}

	var dirs []string
	dirs = append(dirs, filepath.Join(dataHome, "applications"))
	for _, d := range strings.Split(dataDirs, ":") {
		if d == "" {
			continue
		}
		dirs = append(dirs, filepath.Join(d, "applications"))
	}

	return dirs
}

func listApps() int {
	dirs := appDirs()

	appMap := make(map[string]AppEntry)

	for _, dir := range dirs {
		if !common.FileExists(dir) && !isDir(dir) {
			continue
		}
		_ = filepath.Walk(dir, func(path string, info os.FileInfo, err error) error {
			if err != nil || info.IsDir() || !strings.HasSuffix(path, ".desktop") {
				return nil
			}
			id := info.Name()
			if _, exists := appMap[id]; exists {
				return nil // Prefer system or already discovered entry
			}
			if entry, ok := parseDesktopFile(path); ok {
				appMap[id] = entry
			}
			return nil
		})
	}

	apps := make([]AppEntry, 0, len(appMap))
	for _, app := range appMap {
		apps = append(apps, app)
	}

	sort.Slice(apps, func(i, j int) bool {
		return strings.ToLower(apps[i].Name) < strings.ToLower(apps[j].Name)
	})

	for _, app := range apps {
		termStr := "0"
		if app.Terminal {
			termStr = "1"
		}
		fmt.Printf("%s\t%s\t%s\t%s\t%s\t%s\n",
			cleanField(app.Name),
			cleanField(app.Icon),
			cleanField(app.Exec),
			termStr,
			cleanField(app.Metadata),
			cleanField(app.ID),
		)
	}

	return 0
}

func parseDesktopFile(path string) (AppEntry, bool) {
	file, err := os.Open(path)
	if err != nil {
		return AppEntry{}, false
	}
	defer file.Close()

	var name, icon, execStr, comment, categories, keywords string
	var terminal, noDisplay, hidden, isApp bool
	inDesktopEntry := false

	scanner := bufio.NewScanner(file)
	for scanner.Scan() {
		line := strings.TrimSpace(scanner.Text())
		if strings.HasPrefix(line, "#") || line == "" {
			continue
		}
		if strings.HasPrefix(line, "[") {
			inDesktopEntry = line == "[Desktop Entry]"
			continue
		}
		if !inDesktopEntry {
			continue
		}

		parts := strings.SplitN(line, "=", 2)
		if len(parts) < 2 {
			continue
		}
		key := strings.TrimSpace(parts[0])
		val := strings.TrimSpace(parts[1])

		switch key {
		case "Type":
			isApp = val == "Application"
		case "Name":
			if name == "" {
				name = val
			}
		case "Icon":
			icon = val
		case "Exec":
			execStr = val
		case "Comment":
			comment = val
		case "Categories":
			categories = val
		case "Keywords":
			keywords = val
		case "Terminal":
			terminal = strings.ToLower(val) == "true"
		case "NoDisplay":
			noDisplay = strings.ToLower(val) == "true"
		case "Hidden":
			hidden = strings.ToLower(val) == "true"
		}
	}

	if !isApp || noDisplay || hidden || name == "" || execStr == "" || name == "Advanced Network Configuration" || filepath.Base(path) == "nm-connection-editor.desktop" {
		return AppEntry{}, false
	}

	cleanExec := removeFieldCodes(execStr)
	meta := strings.ToLower(fmt.Sprintf("%s %s %s %s %s", name, comment, categories, keywords, cleanExec))

	return AppEntry{
		Name:     name,
		Icon:     resolveMacTahoeIcon(icon),
		Exec:     cleanExec,
		Terminal: terminal,
		Metadata: meta,
		ID:       filepath.Base(path),
	}, true
}

func resolveMacTahoeIcon(iconName string) string {
	fallback := "/usr/share/icons/MacTahoe/apps/scalable/preferences-system.svg"
	if iconName == "" {
		return fallback
	}

	// If it's already an absolute path inside MacTahoe and exists
	if strings.HasPrefix(iconName, "/") {
		if strings.Contains(iconName, "MacTahoe") && common.FileExists(iconName) {
			return iconName
		}
		// If it's outside MacTahoe or doesn't exist, extract base filename without extension to check MacTahoe
		base := filepath.Base(iconName)
		idx := strings.LastIndex(base, ".")
		if idx > 0 {
			iconName = base[:idx]
		} else {
			iconName = base
		}
	}

	prefixes := []string{
		"/usr/share/icons/MacTahoe/apps/scalable/",
		"/usr/share/icons/MacTahoe/preferences/32/",
		"/usr/share/icons/MacTahoe/status/32/",
		"/usr/share/icons/MacTahoe/devices/32/",
	}

	variants := []string{
		iconName,
		iconName + "-clear",
		iconName + "-mc",
		strings.TrimSuffix(iconName, "-desktop"),
		strings.TrimSuffix(iconName, "-symbolic"),
	}

	extensions := []string{".svg", ".png", ".icns", ".xpm"}

	for _, p := range prefixes {
		for _, v := range variants {
			for _, ext := range extensions {
				candidate := p + v + ext
				if common.FileExists(candidate) {
					return candidate
				}
			}
		}
	}

	return fallback
}

func removeFieldCodes(execStr string) string {
	parts := strings.Fields(execStr)
	clean := make([]string, 0, len(parts))
	for _, p := range parts {
		if strings.HasPrefix(p, "%") && len(p) == 2 {
			continue
		}
		clean = append(clean, p)
	}
	return strings.Join(clean, " ")
}

func cleanField(val string) string {
	s := strings.ReplaceAll(val, "\t", " ")
	s = strings.ReplaceAll(s, "\n", " ")
	return strings.TrimSpace(s)
}

func isDir(path string) bool {
	info, err := os.Stat(path)
	return err == nil && info.IsDir()
}

func launchApp(execStr string, term bool) int {
	if !term {
		err := common.StartDetached("sh", "-c", execStr)
		if err != nil {
			fmt.Fprintf(os.Stderr, "failed to start %s: %v\n", execStr, err)
			return 1
		}
		return 0
	}

	terminals := []string{
		"i3-sensible-terminal",
		"alacritty",
		"kitty",
		"x-terminal-emulator",
		"gnome-terminal",
	}

	for _, t := range terminals {
		if common.ExecutableExists(t) {
			err := common.StartDetached(t, "-e", "sh", "-c", execStr)
			if err == nil {
				return 0
			}
		}
	}

	// Fallback without terminal if no terminalemulator found
	_ = common.StartDetached("sh", "-c", execStr)
	return 0
}
