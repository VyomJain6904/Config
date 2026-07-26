package controls

import (
	"fmt"
	"math"
	"os"
	"path/filepath"
	"regexp"
	"strconv"
	"strings"
	"time"

	"quickshell/helpers/internal/common"
)

const commandTimeout = 10 * time.Second

var (
	volumePattern  = regexp.MustCompile(`Volume:\s+([0-9.]+)`)
	devicePattern  = regexp.MustCompile(`^Device\s+([0-9A-Fa-f:]+)\s+(.*)$`)
	addressPattern = regexp.MustCompile(`Device\s+([0-9A-Fa-f:]+)`)
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
	case "output-devices":
		audioDevices(false)
	case "output-set-default":
		if len(args) > 0 {
			setDefaultDevice(false, args[0])
		}
	case "media-status":
		mediaStatus()
	case "media-watch":
		err := common.ReplaceProcess(
			"playerctl",
			"--follow", "--all-players", "metadata",
			"--format", "{{playerName}}\t{{status}}\t{{xesam:artist}}\t{{xesam:title}}",
		)
		if err != nil {
			fmt.Fprintln(os.Stderr, err)
			return 1
		}
	case "media-play-pause":
		_ = common.RunAttached("playerctl", "play-pause")
	case "media-next":
		_ = common.RunAttached("playerctl", "next")
	case "media-previous":
		_ = common.RunAttached("playerctl", "previous")
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
		fmt.Println("VOL unavailable")
		return
	}
	value, err := strconv.ParseFloat(match[1], 64)
	if err != nil {
		fmt.Println("VOL unavailable")
		return
	}
	volume := min(100, int(math.Round(value*100)))
	if strings.Contains(out, "[MUTED]") {
		fmt.Printf("VOL muted %d%%\n", volume)
	} else {
		fmt.Printf("VOL %d%%\n", volume)
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
		fmt.Println("MIC unavailable")
	case strings.Contains(out, "[MUTED]"):
		fmt.Println("MIC muted")
	default:
		fmt.Println("MIC on")
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

func mediaStatus() {
	playersText := common.RunOutput(commandTimeout, "playerctl", "-l")
	var players []string
	for _, player := range strings.Split(playersText, "\n") {
		if player = strings.TrimSpace(player); player != "" {
			players = append(players, player)
		}
	}
	if len(players) == 0 {
		fmt.Println("MEDIA none")
		return
	}
	player := players[0]
	state := strings.TrimSpace(common.RunOutput(commandTimeout, "playerctl", "-p", player, "status"))
	artist := strings.TrimSpace(common.RunOutput(commandTimeout, "playerctl", "-p", player, "metadata", "xesam:artist"))
	title := strings.TrimSpace(common.RunOutput(commandTimeout, "playerctl", "-p", player, "metadata", "xesam:title"))
	fmt.Printf("%s\t%s\t%s\t%s\n", player, state, artist, title)
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
