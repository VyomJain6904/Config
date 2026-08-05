package wallpaper

import (
	"crypto/md5"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"math/rand"
	"os"
	"os/exec"
	"path/filepath"
	"regexp"
	"sort"
	"strings"
	"sync"
	"time"
)

// WallpaperState captures active background configuration parameters.
type WallpaperState struct {
	Path          string `json:"path"`
	Mode          string `json:"mode"`
	Color         string `json:"color"`
	ComputedColor string `json:"computedColor,omitempty"`
}

// WallpaperItem represents an individual catalog image file and its thumbnail URL.
type WallpaperItem struct {
	Name      string `json:"name"`
	Path      string `json:"path"`
	URL       string `json:"url"`
	Thumbnail string `json:"thumbnail"`
	SizeBytes int64  `json:"sizeBytes"`
	Active    bool   `json:"active"`
}

// ListOutput structures the JSON payload for QML consumption.
type ListOutput struct {
	Current    WallpaperState  `json:"current"`
	Wallpapers []WallpaperItem `json:"wallpapers"`
	Count      int             `json:"count"`
}

var supportedExtensions = map[string]bool{
	".jpg":  true,
	".jpeg": true,
	".png":  true,
	".webp": true,
	".bmp":  true,
}

func getPaths() (wallpaperDir, cacheDir, stateFile, i3Config string) {
	home, _ := os.UserHomeDir()
	wallpaperDir = filepath.Join(home, "Pictures", "Wallpapers")
	cacheDir = filepath.Join(home, ".cache", "quickshell", "wallpaper_thumbnails")
	stateDir := filepath.Join(home, ".local", "state", "quickshell")
	os.MkdirAll(stateDir, 0755)
	stateFile = filepath.Join(stateDir, "wallpaper_state.json")
	i3Config = filepath.Join(home, ".config", "i3", "config")
	return
}

func getCurrentState() WallpaperState {
	_, _, stateFile, i3Config := getPaths()
	state := WallpaperState{Mode: "fill", Color: "#000000"}

	// 1. Try reading saved state JSON
	if data, err := os.ReadFile(stateFile); err == nil {
		var s WallpaperState
		if err := json.Unmarshal(data, &s); err == nil {
			if _, err := os.Stat(s.Path); err == nil && s.Path != "" {
				if s.Mode == "" {
					s.Mode = "fill"
				}
				if s.Color == "" {
					s.Color = "#000000"
				}
				if strings.ToLower(s.Color) == "auto" {
					s.ComputedColor = getAutoColor(s.Path)
				} else {
					s.ComputedColor = s.Color
				}
				return s
			}
		}
	}

	// 2. Fallback to extracting from i3/config
	if data, err := os.ReadFile(i3Config); err == nil {
		content := string(data)
		re := regexp.MustCompile(`feh\s+(?:--image-bg\s+['"]?([^\s'"]+)['"]?\s+)?--bg-(fill|max|scale|center|tile)\s+([^\s\r\n]+)`)
		matches := re.FindStringSubmatch(content)
		if len(matches) == 0 {
			re = regexp.MustCompile(`feh\s+--bg-(fill|max|scale|center|tile)(?:\s+--image-bg\s+['"]?([^\s'"]+)['"]?)?\s+([^\s\r\n]+)`)
			matches = re.FindStringSubmatch(content)
			if len(matches) > 3 {
				state.Mode = matches[1]
				if matches[2] != "" {
					state.Color = matches[2]
				}
				state.Path = expandUser(matches[3])
			}
		} else if len(matches) > 3 {
			if matches[1] != "" {
				state.Color = matches[1]
			}
			state.Mode = matches[2]
			state.Path = expandUser(matches[3])
		}
	}

	// 3. Fallback to first available image in directory
	if state.Path == "" || !fileExists(state.Path) {
		wallpaperDir, _, _, _ := getPaths()
		entries, _ := os.ReadDir(wallpaperDir)
		for _, e := range entries {
			if !e.IsDir() && supportedExtensions[strings.ToLower(filepath.Ext(e.Name()))] {
				state.Path = filepath.Join(wallpaperDir, e.Name())
				break
			}
		}
	}

	saveState(state)
	if strings.ToLower(state.Color) == "auto" {
		state.ComputedColor = getAutoColor(state.Path)
	} else {
		state.ComputedColor = state.Color
	}
	return state
}

func saveState(state WallpaperState) {
	_, _, stateFile, _ := getPaths()
	data, _ := json.MarshalIndent(state, "", "  ")
	tmpFile := stateFile + ".tmp"
	if err := os.WriteFile(tmpFile, data, 0644); err == nil {
		os.Rename(tmpFile, stateFile)
	}
}

func updateI3Config(path, mode, color string) {
	_, _, _, i3Config := getPaths()
	data, err := os.ReadFile(i3Config)
	if err != nil {
		return
	}

	lines := strings.Split(string(data), "\n")
	updated := false
	newCmd := fmt.Sprintf("exec_always --no-startup-id feh --bg-%s --image-bg '%s' %s", mode, color, path)

	for i, line := range lines {
		if strings.Contains(line, "feh ") && strings.Contains(line, "--bg-") {
			indent := regexp.MustCompile(`^\s*`).FindString(line)
			lines[i] = indent + newCmd
			updated = true
			break
		}
	}

	if !updated {
		lines = append(lines, "", "# Desktop Wallpaper", newCmd)
	}

	tmpConfig := i3Config + ".tmp"
	if err := os.WriteFile(tmpConfig, []byte(strings.Join(lines, "\n")), 0644); err == nil {
		os.Rename(tmpConfig, i3Config)
	}
}

func expandUser(path string) string {
	if strings.HasPrefix(path, "~/") {
		home, _ := os.UserHomeDir()
		return filepath.Join(home, path[2:])
	}
	return path
}

func fileExists(path string) bool {
	_, err := os.Stat(path)
	return err == nil
}

func md5Hash(text string) string {
	hash := md5.Sum([]byte(text))
	return hex.EncodeToString(hash[:])
}

func getAutoColor(imagePath string) string {
	_, cacheDir, _, _ := getPaths()
	thumbPath := filepath.Join(cacheDir, md5Hash(imagePath)+".thumb.jpg")
	target := imagePath
	if fileExists(thumbPath) {
		target = thumbPath
	}
	out, err := exec.Command("magick", target, "-resize", "1x1", "-format", "#%[hex:u]\n", "info:").Output()
	if err != nil || len(out) == 0 {
		return "#000000"
	}
	color := strings.TrimSpace(string(out))
	if !strings.HasPrefix(color, "#") || (len(color) != 7 && len(color) != 4) {
		return "#000000"
	}
	return strings.ToLower(color)
}

func runList() int {
	wallpaperDir, cacheDir, _, _ := getPaths()
	os.MkdirAll(wallpaperDir, 0755)
	os.MkdirAll(cacheDir, 0755)

	curr := getCurrentState()
	entries, err := os.ReadDir(wallpaperDir)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error reading directory: %v\n", err)
		return 1
	}

	var items []WallpaperItem
	var missing []string

	for _, e := range entries {
		if e.IsDir() {
			continue
		}
		ext := strings.ToLower(filepath.Ext(e.Name()))
		if !supportedExtensions[ext] {
			continue
		}
		absPath := filepath.Join(wallpaperDir, e.Name())
		info, err := e.Info()
		if err != nil {
			continue
		}

		thumbName := md5Hash(absPath) + ".thumb.jpg"
		thumbPath := filepath.Join(cacheDir, thumbName)
		thumbURL := "file://" + absPath

		if tInfo, err := os.Stat(thumbPath); err == nil && !tInfo.ModTime().Before(info.ModTime()) {
			thumbURL = "file://" + thumbPath
		} else {
			missing = append(missing, absPath)
		}

		items = append(items, WallpaperItem{
			Name:      e.Name(),
			Path:      absPath,
			URL:       "file://" + absPath,
			Thumbnail: thumbURL,
			SizeBytes: info.Size(),
			Active:    (absPath == curr.Path),
		})
	}

	sort.Slice(items, func(i, j int) bool {
		return strings.ToLower(items[i].Name) < strings.ToLower(items[j].Name)
	})

	out := ListOutput{
		Current:    curr,
		Wallpapers: items,
		Count:      len(items),
	}

	jsonBytes, _ := json.Marshal(out)
	fmt.Println(string(jsonBytes))

	// Spawn detached async background worker for missing thumbnails
	if len(missing) > 0 {
		args := append([]string{"wallpaper", "--worker"}, missing...)
		cmd := exec.Command(os.Args[0], args...)
		cmd.Stdin = nil
		cmd.Stdout = nil
		cmd.Stderr = nil
		cmd.Start()
	}

	return 0
}

func runWorker(paths []string) int {
	_, cacheDir, _, _ := getPaths()
	os.MkdirAll(cacheDir, 0755)

	var wg sync.WaitGroup
	sem := make(chan struct{}, 4) // Bounded concurrency semaphore

	for _, src := range paths {
		info, err := os.Stat(src)
		if err != nil {
			continue
		}
		thumbPath := filepath.Join(cacheDir, md5Hash(src)+".thumb.jpg")
		if tInfo, err := os.Stat(thumbPath); err == nil && !tInfo.ModTime().Before(info.ModTime()) {
			continue
		}

		wg.Add(1)
		sem <- struct{}{}
		go func(source, dest string) {
			defer wg.Done()
			cmd := exec.Command("magick", "convert", source, "-thumbnail", "350x220", "-quality", "85", dest)
			cmd.Run()
			<-sem
		}(src, thumbPath)
	}
	wg.Wait()
	return 0
}

func runSet(pathArg, mode, color string) int {
	if mode == "" {
		mode = "fill"
	}
	if color == "" || (!strings.HasPrefix(color, "#") && strings.ToLower(color) != "auto") {
		color = "#000000"
	}
	if pathArg == "" {
		pathArg = getCurrentState().Path
	} else if !filepath.IsAbs(pathArg) {
		wallpaperDir, _, _, _ := getPaths()
		pathArg = filepath.Join(wallpaperDir, pathArg)
	}

	if !fileExists(pathArg) {
		fmt.Fprintf(os.Stderr, "File not found: %s\n", pathArg)
		return 1
	}

	actualColor := color
	computedColor := color
	if strings.ToLower(color) == "auto" {
		actualColor = getAutoColor(pathArg)
		computedColor = actualColor
	}
	exec.Command("feh", "--bg-"+mode, "--image-bg", actualColor, pathArg).Run()

	state := WallpaperState{Path: pathArg, Mode: mode, Color: color, ComputedColor: computedColor}
	saveState(state)
	updateI3Config(pathArg, mode, actualColor)

	jsonBytes, _ := json.Marshal(map[string]WallpaperState{"current": state})
	fmt.Println(string(jsonBytes))
	return 0
}

func runRandom(mode, color string) int {
	wallpaperDir, _, _, _ := getPaths()
	entries, err := os.ReadDir(wallpaperDir)
	if err != nil {
		return 1
	}
	var valid []string
	for _, e := range entries {
		if !e.IsDir() && supportedExtensions[strings.ToLower(filepath.Ext(e.Name()))] {
			valid = append(valid, filepath.Join(wallpaperDir, e.Name()))
		}
	}
	if len(valid) == 0 {
		return 1
	}
	rand.Seed(time.Now().UnixNano())
	chosen := valid[rand.Intn(len(valid))]
	return runSet(chosen, mode, color)
}

// Run executes wallpaper management commands.
func Run(args []string) int {
	if len(args) == 0 || args[0] == "list" {
		return runList()
	}
	switch args[0] {
	case "--worker":
		return runWorker(args[1:])
	case "current":
		data, _ := json.Marshal(map[string]WallpaperState{"current": getCurrentState()})
		fmt.Println(string(data))
		return 0
	case "set":
		path := ""
		mode := "fill"
		color := "#000000"
		if len(args) > 1 {
			path = args[1]
		}
		if len(args) > 2 {
			mode = args[2]
		}
		if len(args) > 3 {
			color = args[3]
		}
		return runSet(path, mode, color)
	case "random":
		mode := ""
		color := ""
		if len(args) > 1 {
			mode = args[1]
		}
		if len(args) > 2 {
			color = args[2]
		}
		return runRandom(mode, color)
	default:
		fmt.Fprintf(os.Stderr, "Unknown wallpaper command: %s\n", args[0])
		return 2
	}
}
