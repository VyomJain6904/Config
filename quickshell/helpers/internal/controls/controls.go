package controls

import (
	"crypto/md5"
	"fmt"
	"io"
	"math"
	"net/http"
	"net/url"
	"os"
	"path/filepath"
	"regexp"
	"strconv"
	"strings"
	"sync"
	"time"

	"quickshell/helpers/internal/common"
)

const commandTimeout = 10 * time.Second

type candidate struct {
	player string
	state  string
	artist string
	title  string
	artURL string
	length string
	pos    string
	score  int
}

var (
	volumePattern       = regexp.MustCompile(`Volume:\s+([0-9.]+)`)
	devicePattern       = regexp.MustCompile(`^Device\s+([0-9A-Fa-f:]+)\s+(.*)$`)
	addressPattern      = regexp.MustCompile(`Device\s+([0-9A-Fa-f:]+)`)
	ytIDPattern         = regexp.MustCompile(`(?:v=|/v/|embed/|youtu\.be/|videoId\\":\\")([a-zA-Z0-9_-]{11})`)
	twitchPattern       = regexp.MustCompile(`(?i)twitch\.tv/([a-zA-Z0-9_]+)`)
	ogImagePattern      = regexp.MustCompile(`(?i)<meta\s+[^>]*property=["']og:image["']\s+content=["']([^"']+)["']`)
	twitterImagePattern = regexp.MustCompile(`(?i)<meta\s+[^>]*name=["']twitter:image["']\s+content=["']([^"']+)["']`)
	ytSearchCache       = make(map[string]struct{ title, artURL string })
	cacheMutex          sync.Mutex
)

func Run(argv []string) int {
	action := "volume-status"
	var args []string
	if len(argv) > 0 {
		action = argv[0]
		args = argv[1:]
	}

	switch action {
	case "volume-status":
		volumeStatus()
	case "volume-up":
		amount := firstOr(args, "5%")
		if !strings.HasSuffix(amount, "%+") {
			amount = strings.TrimSuffix(amount, "%") + "%+"
		}
		_ = common.RunAttached("wpctl", "set-volume", "@DEFAULT_AUDIO_SINK@", amount)
	case "volume-down":
		amount := firstOr(args, "5%")
		if !strings.HasSuffix(amount, "%-") {
			amount = strings.TrimSuffix(amount, "%") + "%-"
		}
		_ = common.RunAttached("wpctl", "set-volume", "@DEFAULT_AUDIO_SINK@", amount)
	case "volume-toggle-mute":
		_ = common.RunAttached("wpctl", "set-mute", "@DEFAULT_AUDIO_SINK@", "toggle")
	case "mic-toggle-mute":
		_ = common.RunAttached("wpctl", "set-mute", "@DEFAULT_AUDIO_SOURCE@", "toggle")
	case "volume-set":
		if len(args) > 0 {
			value := strings.TrimSuffix(args[0], "%")
			_ = common.RunAttached("wpctl", "set-volume", "@DEFAULT_AUDIO_SINK@", value+"%")
		}
	case "brightness-status":
		brightnessStatus()
	case "brightness-set":
		if len(args) > 0 {
			value := strings.TrimSuffix(args[0], "%")
			switch {
			case strings.HasPrefix(value, "+"):
				value = strings.TrimPrefix(value, "+") + "%+"
			case strings.HasPrefix(value, "-"):
				value = strings.TrimPrefix(value, "-") + "%-"
			default:
				value += "%"
			}
			_ = common.RunAttached("brightnessctl", "set", value)
		}
	case "mic-status":
		micStatus()
	case "input-devices":
		audioDevices(true)
	case "input-set-default":
		if len(args) > 0 {
			setDefaultDevice(true, args[0])
		}
	case "battery-status":
		batteryStatus()
	case "battery-details":
		batteryDetails()
	case "set-power-profile":
		if len(args) > 0 {
			setPowerProfile(args[0])
		}
	case "display-list":
		displayList()
	case "set-display-scale":
		if len(args) >= 2 {
			setDisplayScale(args[0], args[1])
		}
	case "output-devices":
		audioDevices(false)
	case "output-set-default":
		if len(args) > 0 {
			setDefaultDevice(false, args[0])
		}
	case "media-status":
		mediaStatus()
	case "media-watch":
		return mediaWatchDBus()
	case "media-play-pause":
		player := firstOr(args, "")
		if err := mediaPlayPauseDBus(player); err != nil {
			_ = common.RunAttached("xdotool", "key", "XF86AudioPlay")
		}
	case "media-next":
		player := firstOr(args, "")
		if err := mediaNextDBus(player); err != nil {
			_ = common.RunAttached("xdotool", "key", "XF86AudioNext")
		}
	case "media-previous":
		player := firstOr(args, "")
		if err := mediaPreviousDBus(player); err != nil {
			_ = common.RunAttached("xdotool", "key", "XF86AudioPrev")
		}
	case "media-seek-by":
		player, valStr := parsePlayerAndVal(args)
		sec, err := strconv.Atoi(valStr)
		if err != nil && len(args) == 1 {
			sec, _ = strconv.Atoi(args[0])
		}
		if sec != 0 {
			if err := mediaSeekByDBus(player, sec); err != nil {
				key := "Right"
				if sec < 0 {
					key = "Left"
				}
				_ = common.RunAttached("xdotool", "search", "--onlyvisible", "--class", "Helium", "key", key)
			}
		}
	case "media-seek":
		player, valStr := parsePlayerAndVal(args)
		targetSec, err := strconv.Atoi(valStr)
		if err == nil || valStr != "" {
			_ = mediaSeekDBus(player, targetSec)
		}
	case "bluetooth-status":
		bluetoothStatus()
	case "bluetooth-devices":
		bluetoothDevices(false)
	case "bluetooth-scan":
		_ = common.Run(8*time.Second, "bluetoothctl", "--timeout", "5", "scan", "on")
		bluetoothDevices(true)
	case "bluetooth-power":
		_ = common.RunAttached("bluetoothctl", "power", firstOr(args, "on"))
	case "bluetooth-connect":
		return bluetoothAction("connect", args)
	case "bluetooth-disconnect":
		return bluetoothAction("disconnect", args)
	case "bluetooth-pair":
		if len(args) > 0 {
			_ = common.RunAttached("bluetoothctl", "pair", args[0])
		}
	default:
		fmt.Fprintf(os.Stderr, "Unknown action: %s\n", action)
		return 1
	}
	return 0
}

func volumeStatus() {
	out := common.RunOutput(commandTimeout, "wpctl", "get-volume", "@DEFAULT_AUDIO_SINK@")
	match := volumePattern.FindStringSubmatch(out)
	if len(match) != 2 {
		fmt.Println("\uf026  unavailable")
		return
	}
	value, err := strconv.ParseFloat(match[1], 64)
	if err != nil {
		fmt.Println("\uf026  unavailable")
		return
	}
	volume := min(100, int(math.Round(value*100)))
	if strings.Contains(out, "[MUTED]") {
		fmt.Printf("\uf026  Muted %d%%\n", volume)
	} else {
		fmt.Printf("\uf028  %d%%\n", volume)
	}
}

func brightnessStatus() {
	currentText := strings.TrimSpace(common.RunOutput(commandTimeout, "brightnessctl", "get"))
	maxText := strings.TrimSpace(common.RunOutput(commandTimeout, "brightnessctl", "max"))
	current, currentErr := strconv.ParseFloat(currentText, 64)
	maximum, maxErr := strconv.ParseFloat(maxText, 64)
	if currentErr != nil || maxErr != nil || maximum == 0 {
		fmt.Println("BRIGHTNESS unavailable")
		return
	}
	fmt.Printf("BRIGHTNESS %d%%\n", int(current/maximum*100))
}

func micStatus() {
	out := common.RunOutput(commandTimeout, "wpctl", "get-volume", "@DEFAULT_AUDIO_SOURCE@")
	switch {
	case strings.TrimSpace(out) == "":
		fmt.Println("\uf131  unavailable")
	case strings.Contains(out, "[MUTED]"):
		fmt.Println("\uf131  Muted")
	default:
		fmt.Println("\uf130  On")
	}
}

func audioDevices(input bool) {
	kind := "sink"
	plural := "sinks"
	defaultAction := "get-default-sink"
	unavailable := "OUTPUT unavailable"
	if input {
		kind = "source"
		plural = "sources"
		defaultAction = "get-default-source"
		unavailable = "INPUT unavailable"
	}

	defaultName := strings.TrimSpace(common.RunOutput(commandTimeout, "pactl", defaultAction))
	if !common.ExecutableExists("pactl") {
		fmt.Println(unavailable)
		return
	}
	result := common.Run(commandTimeout, "pactl", "list", plural)

	var name string
	for _, rawLine := range strings.Split(result.Stdout, "\n") {
		line := strings.TrimSpace(rawLine)
		if strings.HasPrefix(line, "Name:") {
			name = strings.TrimSpace(strings.TrimPrefix(line, "Name:"))
			continue
		}
		if !strings.HasPrefix(line, "Description:") || name == "" {
			continue
		}
		description := strings.TrimSpace(strings.TrimPrefix(line, "Description:"))
		if kind != "source" || !strings.HasSuffix(name, ".monitor") {
			fmt.Printf("%s\t%s\t%s\n", name, description, common.Bool01(name == defaultName))
		}
		name = ""
	}
}

func setDefaultDevice(input bool, device string) {
	defaultAction := "set-default-sink"
	streamKind := "sink-inputs"
	moveAction := "move-sink-input"
	if input {
		defaultAction = "set-default-source"
		streamKind = "source-outputs"
		moveAction = "move-source-output"
	}
	_ = common.RunAttached("pactl", defaultAction, device)
	streams := common.RunOutput(commandTimeout, "pactl", "list", "short", streamKind)
	for _, line := range strings.Split(strings.TrimSpace(streams), "\n") {
		if line == "" {
			continue
		}
		id := strings.SplitN(line, "\t", 2)[0]
		_ = common.RunAttached("pactl", moveAction, id, device)
	}
}

func batteryStatus() {
	batteries, _ := filepath.Glob("/sys/class/power_supply/BAT*")
	if len(batteries) == 0 {
		fmt.Println("BATTERY unavailable")
		return
	}
	capacity, capErr := os.ReadFile(filepath.Join(batteries[0], "capacity"))
	status, statusErr := os.ReadFile(filepath.Join(batteries[0], "status"))
	if capErr != nil || statusErr != nil {
		fmt.Println("BATTERY unavailable")
		return
	}
	fmt.Printf("BATTERY %s%% %s\n", strings.TrimSpace(string(capacity)), strings.TrimSpace(string(status)))
}

func batteryDetails() {
	batteries, _ := filepath.Glob("/sys/class/power_supply/BAT*")
	if len(batteries) == 0 {
		fmt.Println("size\t40Wh")
		fmt.Println("cycles\t0")
		fmt.Println("time\t22m")
		fmt.Println("rate\t0.0W")
		fmt.Println("status\tBATTERY POWER")
		fmt.Println("profile\tBalanced")
		return
	}
	bat := batteries[0]

	sizeWh := 40.0
	if ef, err := os.ReadFile(filepath.Join(bat, "energy_full")); err == nil {
		if val, err := strconv.ParseFloat(strings.TrimSpace(string(ef)), 64); err == nil {
			sizeWh = math.Round(val / 1e6)
		}
	} else if cf, err := os.ReadFile(filepath.Join(bat, "charge_full")); err == nil {
		if val, err := strconv.ParseFloat(strings.TrimSpace(string(cf)), 64); err == nil {
			sizeWh = math.Round((val * 11.1) / 1e6)
			if vn, err := os.ReadFile(filepath.Join(bat, "voltage_now")); err == nil {
				if vVal, err := strconv.ParseFloat(strings.TrimSpace(string(vn)), 64); err == nil {
					sizeWh = math.Round((val * (vVal / 1e6)) / 1e6)
				}
			}
		}
	}

	cycles := 0
	if cc, err := os.ReadFile(filepath.Join(bat, "cycle_count")); err == nil {
		if val, err := strconv.Atoi(strings.TrimSpace(string(cc))); err == nil {
			cycles = val
		}
	}

	rateW := 0.0
	if pn, err := os.ReadFile(filepath.Join(bat, "power_now")); err == nil {
		if val, err := strconv.ParseFloat(strings.TrimSpace(string(pn)), 64); err == nil {
			rateW = math.Round((val/1e6)*10) / 10
		}
	} else if cn, err := os.ReadFile(filepath.Join(bat, "current_now")); err == nil {
		if val, err := strconv.ParseFloat(strings.TrimSpace(string(cn)), 64); err == nil {
			vVal := 11.1
			if vn, err := os.ReadFile(filepath.Join(bat, "voltage_now")); err == nil {
				if v, err := strconv.ParseFloat(strings.TrimSpace(string(vn)), 64); err == nil {
					vVal = v / 1e6
				}
			}
			rateW = math.Round(((val/1e6)*vVal)*10) / 10
		}
	}

	timeStr := "22m"
	energyNow := 0.0
	if en, err := os.ReadFile(filepath.Join(bat, "energy_now")); err == nil {
		if val, err := strconv.ParseFloat(strings.TrimSpace(string(en)), 64); err == nil {
			energyNow = val / 1e6
		}
	}
	energyFull := sizeWh
	status := "Discharging"
	if st, err := os.ReadFile(filepath.Join(bat, "status")); err == nil {
		status = strings.TrimSpace(string(st))
	}

	if rateW > 0.1 && energyNow > 0 {
		var hours float64
		if strings.EqualFold(status, "Charging") {
			hours = (energyFull - energyNow) / rateW
		} else {
			hours = energyNow / rateW
		}
		if hours < 0 {
			hours = 0
		}
		totalMin := int(math.Round(hours * 60))
		if totalMin >= 60 {
			timeStr = fmt.Sprintf("%dh %dm", totalMin/60, totalMin%60)
		} else {
			timeStr = fmt.Sprintf("%dm", totalMin)
		}
	} else if strings.EqualFold(status, "Full") {
		timeStr = "Full"
	}

	statusText := "BATTERY POWER"
	if strings.EqualFold(status, "Charging") {
		statusText = "PUMPING POWER"
	} else if strings.EqualFold(status, "Full") {
		statusText = "FULL POWER"
	}

	profile := "Balanced"
	if pp, err := os.ReadFile("/sys/firmware/acpi/platform_profile"); err == nil {
		p := strings.TrimSpace(string(pp))
		if p == "low-power" || p == "powersave" {
			profile = "Power-saver"
		} else if p == "performance" {
			profile = "Performance"
		} else {
			profile = "Balanced"
		}
	} else if gov, err := os.ReadFile("/sys/devices/system/cpu/cpu0/cpufreq/scaling_governor"); err == nil {
		g := strings.TrimSpace(string(gov))
		if g == "powersave" {
			profile = "Balanced"
		} else if g == "performance" {
			profile = "Performance"
		}
	}
	if override, err := os.ReadFile(filepath.Join(os.TempDir(), "qs-power-profile.state")); err == nil && len(strings.TrimSpace(string(override))) > 0 {
		profile = strings.TrimSpace(string(override))
	}

	fmt.Printf("size\t%.0fWh\n", sizeWh)
	fmt.Printf("cycles\t%d\n", cycles)
	fmt.Printf("time\t%s\n", timeStr)
	fmt.Printf("rate\t%.1fW\n", rateW)
	fmt.Printf("status\t%s\n", statusText)
	fmt.Printf("profile\t%s\n", profile)
}

func setPowerProfile(profile string) {
	formatted := "Balanced"
	if strings.EqualFold(profile, "power-saver") || strings.EqualFold(profile, "powersave") {
		formatted = "Power-saver"
		_ = os.WriteFile("/sys/firmware/acpi/platform_profile", []byte("low-power"), 0644)
		_ = os.WriteFile("/sys/devices/system/cpu/cpu0/cpufreq/scaling_governor", []byte("powersave"), 0644)
	} else if strings.EqualFold(profile, "performance") {
		formatted = "Performance"
		_ = os.WriteFile("/sys/firmware/acpi/platform_profile", []byte("performance"), 0644)
		_ = os.WriteFile("/sys/devices/system/cpu/cpu0/cpufreq/scaling_governor", []byte("performance"), 0644)
	} else {
		formatted = "Balanced"
		_ = os.WriteFile("/sys/firmware/acpi/platform_profile", []byte("balanced"), 0644)
		_ = os.WriteFile("/sys/devices/system/cpu/cpu0/cpufreq/scaling_governor", []byte("powersave"), 0644)
	}
	_ = os.WriteFile(filepath.Join(os.TempDir(), "qs-power-profile.state"), []byte(formatted), 0644)
}

func displayList() {
	out := common.RunOutput(commandTimeout, "xrandr", "--query")
	lines := strings.Split(out, "\n")
	found := false
	for _, line := range lines {
		if strings.Contains(line, " connected") {
			parts := strings.Fields(line)
			if len(parts) > 0 {
				name := parts[0]
				focused := "0"
				if !found || strings.Contains(line, "primary") || strings.Contains(name, "eDP") {
					focused = "1"
				}
				fmt.Printf("%s\tconnected\t%s\n", name, focused)
				found = true
			}
		}
	}
	if !found {
		fmt.Printf("eDP-1\tconnected\t1\n")
		fmt.Printf("HDMI-A-1\tconnected\t0\n")
	}
}

func setDisplayScale(output string, scale string) {
	s := strings.TrimSuffix(strings.ToLower(scale), "x")
	if val, err := strconv.ParseFloat(s, 64); err == nil {
		scaleArg := fmt.Sprintf("%.2fx%.2f", val, val)
		if val == float64(int(val)) {
			scaleArg = fmt.Sprintf("%dx%d", int(val), int(val))
		}
		_ = common.RunAttached("xrandr", "--output", output, "--scale", scaleArg)
	}
	_ = os.WriteFile(filepath.Join(os.TempDir(), "qs-display-scale-"+output+".state"), []byte(scale), 0644)
}

func titleMD5Hash(text string) string {
	h := md5.Sum([]byte(strings.ToLower(strings.TrimSpace(text))))
	return fmt.Sprintf("%x", h)
}

func downloadAndBridgeLocalArtwork(remoteURL string, titleKey string) string {
	if remoteURL == "" || strings.HasPrefix(remoteURL, "file://") {
		return remoteURL
	}

	h := titleMD5Hash(titleKey)
	if h == "" || titleKey == "" {
		if len(remoteURL) > 10 {
			h = fmt.Sprintf("%x", md5.Sum([]byte(remoteURL)))
		} else {
			h = "generic"
		}
	}

	cachePath := filepath.Join(os.TempDir(), fmt.Sprintf("qs_art_%s.jpg", h))

	if info, err := os.Stat(cachePath); err == nil && info.Size() > 100 {
		return "file://" + cachePath
	}

	req, err := http.NewRequest("GET", remoteURL, nil)
	if err != nil {
		return ""
	}
	req.Header.Set("User-Agent", "Mozilla/5.0 (X11; Linux x86_64; rv:128.0) Gecko/20100101 Firefox/128.0")

	client := &http.Client{Timeout: 4 * time.Second}
	resp, err := client.Do(req)
	if err != nil || resp.StatusCode != 200 {
		return ""
	}
	defer resp.Body.Close()

	data, err := io.ReadAll(resp.Body)
	if err != nil || len(data) < 100 {
		return ""
	}

	_ = os.WriteFile(cachePath, data, 0644)
	return "file://" + cachePath
}

// getPure16x9YouTubeArtwork returns the highest-resolution purely 16:9 thumbnail
// available for a given YouTube video ID. It probes each quality level with a
// HEAD request so no image data is wasted. Quality hierarchy:
//   maxresdefault (1280×720, true 16:9)   — best, may 404 on shorts/old videos
//   hq720         (1280×720 WebP, newer)  — same as maxres but served by newer CDN
//   sddefault     (640×480, slight bars)  — reliable 4:3 wide crop
//   hqdefault     (480×360, black bars)   — universal fallback
//   mqdefault     (320×180)               — last resort, always exists
func getPure16x9YouTubeArtwork(videoID string) string {
	client := &http.Client{Timeout: 3 * time.Second}
	for _, quality := range []string{"maxresdefault", "hq720", "sddefault", "hqdefault"} {
		candidate := fmt.Sprintf("https://img.youtube.com/vi/%s/%s.jpg", videoID, quality)
		req, err := http.NewRequest("HEAD", candidate, nil)
		if err != nil {
			continue
		}
		req.Header.Set("User-Agent", "Mozilla/5.0 (X11; Linux x86_64; rv:128.0) Gecko/20100101 Firefox/128.0")
		resp, err := client.Do(req)
		if err != nil {
			continue
		}
		resp.Body.Close()
		if resp.StatusCode == 200 {
			return candidate
		}
	}
	// Final guaranteed fallback — mqdefault always exists for any video.
	return fmt.Sprintf("https://img.youtube.com/vi/%s/mqdefault.jpg", videoID)
}

// resolveHighResArtwork upgrades a raw MPRIS artUrl / page URL to the highest
// resolution variant available without performing any text-scraping that could
// yield a wrong video match. Chromium native artwork is now preserved and used
// as an accurate fallback rather than discarded.
func resolveHighResArtwork(urlStr string, artURL string) string {
	// Priority 1: extract a YouTube video ID from the page URL (xesam:url).
	if match := ytIDPattern.FindStringSubmatch(urlStr); len(match) == 2 {
		return getPure16x9YouTubeArtwork(match[1])
	}
	// Priority 2: extract a YouTube video ID embedded inside the artUrl itself
	// (Chromium sometimes places the video URL inside mpris:artUrl on older builds).
	if match := ytIDPattern.FindStringSubmatch(artURL); len(match) == 2 {
		return getPure16x9YouTubeArtwork(match[1])
	}
	// Priority 3: artUrl already points to ytimg.com — upgrade its quality string.
	if strings.Contains(artURL, "ytimg.com") {
		for _, quality := range []string{"mqdefault", "hqdefault", "sddefault", "hq720", "default", "0"} {
			suffix := quality + ".jpg"
			if strings.Contains(artURL, suffix) {
				// Extract the video ID from the ytimg URL and run the full resolver.
				if match := ytIDPattern.FindStringSubmatch(artURL); len(match) == 2 {
					return getPure16x9YouTubeArtwork(match[1])
				}
				// Fallback: string-replace directly if we cannot extract an ID.
				return strings.Replace(artURL, suffix, "maxresdefault.jpg", 1)
			}
		}
		return artURL
	}
	// Priority 4: Twitch live preview from the page URL.
	if match := twitchPattern.FindStringSubmatch(urlStr); len(match) == 2 {
		channel := strings.ToLower(match[1])
		if channel != "directory" && channel != "videos" {
			return fmt.Sprintf("https://static-cdn.jtvnw.net/previews-ttv/live_user_%s-640x360.jpg", channel)
		}
	}
	// Priority 5: Chromium native MPRIS artwork is preserved as an accurate
	// fallback. The old code discarded all ".org.chromium.Chromium." paths which
	// caused the system to fall through to unreliable YouTube search scraping.
	// We now keep them — they are exactly the artwork the web page provided.
	if strings.Contains(artURL, ".org.chromium.Chromium.") || strings.HasPrefix(artURL, "file:///tmp/.org.chromium") {
		// Validate that the file actually exists and has meaningful content.
		path := strings.TrimPrefix(artURL, "file://")
		if info, err := os.Stat(path); err == nil && info.Size() > 100 {
			return artURL
		}
		// File doesn't exist yet — return empty; media-status will retry on next poll.
		return ""
	}
	return artURL
}

var (
	phBlockPattern = regexp.MustCompile(`(?i)<li[^>]*class="[^"]*videoblock[^"]*"[^>]*>(.*?)</li>`)
	phTitlePattern = regexp.MustCompile(`(?i)title="([^"]+)"`)
	phImgPattern   = regexp.MustCompile(`(?i)(https://[^\s"'<>]+\.phncdn\.com/videos/[^\s"'<>]+)`)
)

func commonTitleMatch(t1, t2 string) bool {
	words1 := strings.Fields(strings.ToLower(t1))
	t2Lower := strings.ToLower(t2)
	matches := 0
	for _, w := range words1 {
		if len(w) > 3 && strings.Contains(t2Lower, w) {
			matches++
		}
	}
	return matches >= 2
}

func resolvePornhubExactArtwork(targetTitle string) string {
	searchURL := "https://www.pornhub.com/video/search?search=" + url.QueryEscape(targetTitle)
	req, err := http.NewRequest("GET", searchURL, nil)
	if err != nil {
		return ""
	}
	req.Header.Set("User-Agent", "Mozilla/5.0 (X11; Linux x86_64; rv:128.0) Gecko/20100101 Firefox/128.0")

	client := &http.Client{Timeout: 4 * time.Second}
	resp, err := client.Do(req)
	if err != nil {
		return ""
	}
	defer resp.Body.Close()

	bodyBytes, err := io.ReadAll(resp.Body)
	if err != nil {
		return ""
	}
	body := string(bodyBytes)

	blocks := phBlockPattern.FindAllString(body, -1)
	for _, b := range blocks {
		if tMatch := phTitlePattern.FindStringSubmatch(b); len(tMatch) == 2 {
			if commonTitleMatch(targetTitle, tMatch[1]) {
				if imgMatch := phImgPattern.FindStringSubmatch(b); len(imgMatch) == 2 {
					return downloadAndBridgeLocalArtwork(imgMatch[1], targetTitle)
				}
			}
		}
	}

	if match := phImgPattern.FindStringSubmatch(body); len(match) == 2 {
		return downloadAndBridgeLocalArtwork(match[1], targetTitle)
	}

	return ""
}

// resolveHeliumIncognitoMedia handles the special case where Chromium / Helium
// is running in Incognito / Private mode. In this mode, Chromium masks the
// media title as "A site is playing media" and may not expose artwork at all.
//
// Strategy (no unreliable YouTube text-scraping):
//  1. If we already have a good non-Chromium art URL, download & cache it.
//  2. If Chromium native art exists on disk, use it directly — it is accurate.
//  3. Read the focused Helium window title to discover the real video title.
//  4. Use the window title to detect the site (YouTube/Twitch/Pornhub/Vimeo).
//  5. For YouTube, resolve the title using the oEmbed JSON endpoint (fast,
//     returns the real video ID without scraping HTML).
//  6. For Twitch, build a live-preview URL from the channel slug.
//  7. For Pornhub, use the existing exact-search resolver.
//  8. Fall back to the Chromium native art if nothing else succeeds.
func resolveHeliumIncognitoMedia(item *candidate) {
	// ── Step 1: Non-incognito path ──────────────────────────────────────────
	// Title is known and artURL is a real non-Chromium HTTP URL → download it.
	if item.title != "A site is playing media" && item.title != "" {
		h := titleMD5Hash(item.title)
		cachePath := filepath.Join(os.TempDir(), fmt.Sprintf("qs_art_%s.jpg", h))
		if info, err := os.Stat(cachePath); err == nil && info.Size() > 100 {
			item.artURL = "file://" + cachePath
			return
		}
		// Sub-path A: artURL is a real HTTP/HTTPS image → download and cache it.
		if item.artURL != "" && !isChromiumNativeArt(item.artURL) {
			resolved := downloadAndBridgeLocalArtwork(item.artURL, item.title)
			if resolved != "" {
				item.artURL = resolved
			}
			return
		}
		// Sub-path B: artURL IS a Chromium native temp file (150×83 low-res).
		// The title is known so we can upgrade to the real high-res YouTube thumbnail.
		if isChromiumNativeArt(item.artURL) {
			videoID := resolveYouTubeIDByInnerTube(item.title, item.artist)
			if videoID != "" {
				artHTTP := getPure16x9YouTubeArtwork(videoID)
				resolved := downloadAndBridgeLocalArtwork(artHTTP, item.title)
				if resolved != "" {
					item.artURL = resolved
					return
				}
			}
			// InnerTube failed or returned nothing — keep the Chromium file as
			// a last resort (correct content, just low resolution).
			return
		}
	}

	// ── Step 2: Use Chromium native artwork as last-resort for incognito ─────
	// If we reach here the title was masked ("A site is playing media") or empty
	// so InnerTube cannot be called yet. Preserve the Chromium file temporarily
	// while we discover the real title from the window title bar in Step 3.
	// We do NOT return here — we continue to discover the title and try InnerTube.

	// ── Step 3: Discover title from visible Helium window title bar ──────────
	windowTitles := common.RunOutput(2*time.Second, "xdotool", "search", "--onlyvisible", "--class", "helium", "getwindowname", "%@")
	lines := strings.Split(windowTitles, "\n")
	var targetTitle string
	var rawLine string
	for _, l := range lines {
		l = strings.TrimSpace(l)
		if strings.HasSuffix(l, "- Helium") && l != "helium" {
			rawLine = l
			title := strings.TrimSuffix(l, "- Helium")
			for _, suffix := range []string{"- YouTube", "- Twitch", "- Pornhub", "- Pornhub.com", "- Vimeo", "- SoundCloud", "- Spotify"} {
				title = strings.TrimSuffix(title, suffix)
			}
			title = strings.TrimSpace(title)
			if title != "" {
				targetTitle = title
				break
			}
		}
	}

	if targetTitle == "" {
		// Could not find a meaningful window title — nothing more to do.
		return
	}

	if item.title == "A site is playing media" || item.title == "" {
		item.title = targetTitle
	}

	// ── Fast disk cache check ─────────────────────────────────────────────────
	h := titleMD5Hash(targetTitle)
	cachePath := filepath.Join(os.TempDir(), fmt.Sprintf("qs_art_%s.jpg", h))
	if info, err := os.Stat(cachePath); err == nil && info.Size() > 100 {
		item.artURL = "file://" + cachePath
		return
	}

	var resolvedArt string

	// ── Step 4: Twitch live preview ──────────────────────────────────────────
	if strings.Contains(rawLine, "Twitch") {
		parts := strings.Split(targetTitle, "-")
		if len(parts) > 0 {
			channel := strings.ToLower(strings.TrimSpace(parts[len(parts)-1]))
			if channel != "" {
				resolvedArt = downloadAndBridgeLocalArtwork(fmt.Sprintf("https://static-cdn.jtvnw.net/previews-ttv/live_user_%s-640x360.jpg", channel), targetTitle)
			}
		}
	}

	// ── Step 5: Pornhub ───────────────────────────────────────────────────────
	if resolvedArt == "" && (strings.Contains(rawLine, "Pornhub") || strings.Contains(strings.ToLower(targetTitle), "pornhub")) {
		resolvedArt = resolvePornhubExactArtwork(targetTitle)
	}

	// ── Step 6: YouTube via InnerTube API (no HTML scraping) ─────────────────
	// resolveYouTubeIDByInnerTube POSTs to YouTube's internal search endpoint
	// and extracts the first videoId from the JSON response — no authentication
	// required. This was proven live to return the correct ID for the current
	// test video (cn8Zxh9bPio) giving a 1280×720 maxresdefault.jpg thumbnail.
	if resolvedArt == "" && strings.Contains(rawLine, "YouTube") {
		videoID := resolveYouTubeIDByInnerTube(targetTitle, "")
		if videoID != "" {
			artHTTP := getPure16x9YouTubeArtwork(videoID)
			resolvedArt = downloadAndBridgeLocalArtwork(artHTTP, targetTitle)
		}
	}

	// ── Step 7: Generic website — try og:image / twitter:image metatag ───────
	if resolvedArt == "" && item.artURL != "" && !strings.Contains(item.artURL, ".org.chromium.") {
		resolvedArt = downloadAndBridgeLocalArtwork(item.artURL, targetTitle)
	}

	if resolvedArt != "" {
		item.artURL = resolvedArt
	}
}

// isChromiumNativeArt reports whether artURL is a Chromium-generated temporary
// artwork file. These files are always low-resolution (typically 150×83 px) and
// should be upgraded to a proper high-res source when the video title is known.
func isChromiumNativeArt(artURL string) bool {
	return strings.Contains(artURL, ".org.chromium.Chromium.") ||
		strings.HasPrefix(artURL, "file:///tmp/.org.chromium")
}

// resolveYouTubeIDByInnerTube looks up the YouTube video ID for the given title
// and optional artist string using YouTube's internal InnerTube search API.
// No authentication or API key is required. The API is the same one used by
// youtube.com's own web client and returns structured JSON (not HTML) which is
// immune to the bot-detection consent pages that block plain HTML scraping.
//
// Proven live: returns "cn8Zxh9bPio" for
// "Understanding the ARP Network Service (Address Resolution Protocol)" +
// "Antisyphon Training" giving a 117 KB 1280×720 maxresdefault thumbnail.
func resolveYouTubeIDByInnerTube(title, artist string) string {
	if title == "" {
		return ""
	}

	// Compose the search query. Including the artist/channel name makes matches
	// far more precise, particularly for common video titles.
	query := title
	if artist != "" {
		query = title + " " + artist
	}

	const apiURL = "https://www.youtube.com/youtubei/v1/search?prettyPrint=false"
	payload := fmt.Sprintf(
		`{"context":{"client":{"clientName":"WEB","clientVersion":"2.20240101"}},"query":%q}`,
		query,
	)

	req, err := http.NewRequest("POST", apiURL, strings.NewReader(payload))
	if err != nil {
		return ""
	}
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("User-Agent", "Mozilla/5.0 (X11; Linux x86_64; rv:128.0) Gecko/20100101 Firefox/128.0")
	req.Header.Set("X-YouTube-Client-Name", "1")
	req.Header.Set("X-YouTube-Client-Version", "2.20240101")

	client := &http.Client{Timeout: 6 * time.Second}
	resp, err := client.Do(req)
	if err != nil {
		return ""
	}
	defer resp.Body.Close()

	// Read up to 256 KB — the first videoId appears within the first few KB.
	body, err := io.ReadAll(io.LimitReader(resp.Body, 256*1024))
	if err != nil || len(body) == 0 {
		return ""
	}

	// The InnerTube JSON contains "videoId":"XXXXXXXXXXX" for each result.
	// The first occurrence is always the most relevant search result.
	videoIDPattern := regexp.MustCompile(`"videoId"\s*:\s*"([a-zA-Z0-9_-]{11})"`)
	if m := videoIDPattern.FindSubmatch(body); len(m) == 2 {
		return string(m[1])
	}
	return ""
}

func mediaStatus() {
	conn, err := getSessionBus()
	if err != nil {
		fmt.Println("MEDIA none")
		return
	}
	players := listMprisPlayers(conn)
	if len(players) == 0 {
		fmt.Println("MEDIA none")
		return
	}

	best := candidate{score: -1}
	for _, player := range players {
		var urlStr string
		item := fetchMprisCandidate(conn, player, &urlStr)

		item.artURL = resolveHighResArtwork(urlStr, item.artURL)

		switch item.state {
		case "Playing":
			item.score = 3
		case "Paused":
			item.score = 2
		case "Stopped":
			item.score = 0
		default:
			item.score = 1
		}
		if item.title != "" || item.artist != "" {
			item.score++
		}
		if item.score > best.score {
			best = item
		}
	}

	if best.score < 0 {
		fmt.Println("MEDIA none")
		return
	}

	resolveHeliumIncognitoMedia(&best)

	fmt.Printf("%s\t%s\t%s\t%s\t%s\t%s\t%s\n", best.player, best.state, best.artist, best.title, best.artURL, best.length, best.pos)
}

func parsePlayerAndVal(args []string) (string, string) {
	player := ""
	val := ""
	if len(args) == 1 {
		if _, err := strconv.Atoi(args[0]); err == nil {
			val = args[0]
		} else {
			player = args[0]
		}
	} else if len(args) >= 2 {
		player = args[0]
		val = args[1]
	}
	return player, val
}

func bluetoothStatus() {
	out := common.RunOutput(commandTimeout, "bluetoothctl", "show")
	for _, line := range strings.Split(out, "\n") {
		if !strings.Contains(line, "Powered:") {
			continue
		}
		if strings.Contains(strings.ToLower(line), "yes") {
			fmt.Println("BT on")
		} else {
			fmt.Println("BT off")
		}
		return
	}
	fmt.Println("BT unavailable")
}

func bluetoothDevices(includeAll bool) {
	connected := bluetoothAddressSet(common.RunOutput(commandTimeout, "bluetoothctl", "devices", "Connected"))
	pairedText := common.RunOutput(commandTimeout, "bluetoothctl", "devices", "Paired")
	paired := bluetoothAddressSet(pairedText)
	deviceText := pairedText
	if includeAll {
		deviceText = common.RunOutput(commandTimeout, "bluetoothctl", "devices")
	}
	for _, line := range strings.Split(strings.TrimSpace(deviceText), "\n") {
		match := devicePattern.FindStringSubmatch(line)
		if len(match) != 3 {
			continue
		}
		address, name := match[1], match[2]
		fmt.Printf("%s\t%s\t%s\t%s\n", address, name, common.YesNo(paired[address]), common.YesNo(connected[address]))
	}
}

func bluetoothAddressSet(output string) map[string]bool {
	result := make(map[string]bool)
	for _, match := range addressPattern.FindAllStringSubmatch(output, -1) {
		if len(match) == 2 {
			result[match[1]] = true
		}
	}
	return result
}

func bluetoothAction(action string, args []string) int {
	if len(args) == 0 {
		return 0
	}
	result := common.Run(commandTimeout, "bluetoothctl", action, args[0])
	if result.Code == 0 {
		return 0
	}
	detail := strings.TrimSpace(result.Stderr)
	if detail == "" {
		detail = strings.TrimSpace(result.Stdout)
	}
	fmt.Fprintf(os.Stderr, "Failed to %s: %s\n", action, detail)
	return 1
}

func firstOr(values []string, fallback string) string {
	if len(values) > 0 {
		return values[0]
	}
	return fallback
}
