package metrics

import (
	"context"
	"os"
	"os/exec"
	"path/filepath"
	"regexp"
	"strconv"
	"strings"
	"time"
)

type FastData struct {
	BP   int    `json:"bp"`
	BS   string `json:"bs"`
	BC   bool   `json:"bc"`
	BF   bool   `json:"bf"`
	Temp int    `json:"temp"`
	Vol  int    `json:"vol"`
	Mute bool   `json:"mute"`
	Bri  int    `json:"bri"`
	WSS  string `json:"wss"`
	WON  bool   `json:"won"`
	BTON bool   `json:"bton"`
}

var volRe = regexp.MustCompile(`(\d+)%`)

func Collect() FastData {
	d := FastData{
		BP: 0, BS: "Unknown", BC: false, BF: false,
		Temp: 0, Vol: 75, Mute: false, Bri: 80,
		WSS: "", WON: true, BTON: false,
	}

	d.BP, d.BS, d.BC, d.BF = readBattery()
	d.Temp = readTemp()
	d.Vol = readVolume()
	d.Mute = readMute()
	d.Bri = readBrightness()
	d.WON = parseWiFiEnabled(run("nmcli", "radio", "wifi"))
	if d.WON {
		d.WSS = readWiFiSSID()
	}
	d.BTON = strings.TrimSpace(run("sh", "-lc", "bluetoothctl show 2>/dev/null | grep -c 'Powered: yes'")) == "1"

	return d
}

func run(name string, args ...string) string {
	ctx, cancel := context.WithTimeout(context.Background(), 1200*time.Millisecond)
	defer cancel()
	out, err := exec.CommandContext(ctx, name, args...).Output()
	if err != nil {
		return ""
	}
	return strings.TrimSpace(string(out))
}

func readFile(path string) string {
	b, err := os.ReadFile(path)
	if err != nil {
		return ""
	}
	return strings.TrimSpace(string(b))
}

func readBattery() (int, string, bool, bool) {
	battery := ""
	for _, b := range []string{"BAT0", "BAT1", "BAT"} {
		if _, err := os.Stat(filepath.Join("/sys/class/power_supply", b, "capacity")); err == nil {
			battery = b
			break
		}
	}
	if battery == "" {
		return 0, "Unknown", false, false
	}

	bp := atoiDefault(readFile(filepath.Join("/sys/class/power_supply", battery, "capacity")), 0)
	bs := readFile(filepath.Join("/sys/class/power_supply", battery, "status"))
	if bs == "" {
		bs = "Unknown"
	}
	bc := bs == "Charging"
	bf := bs == "Full"
	return bp, bs, bc, bf
}

func readTemp() int {
	maxTemp := 0
	for i := 0; i < 10; i++ {
		p := filepath.Join("/sys/class/thermal", "thermal_zone"+strconv.Itoa(i), "temp")
		raw := atoiDefault(readFile(p), 0)
		if raw > 1000 {
			t := raw / 1000
			if t > maxTemp {
				maxTemp = t
			}
		}
	}
	if maxTemp > 0 {
		return maxTemp
	}

	matches, _ := filepath.Glob("/sys/class/hwmon/hwmon*/temp*_input")
	for _, p := range matches {
		raw := atoiDefault(readFile(p), 0)
		if raw > 1000 {
			t := raw / 1000
			if t > maxTemp {
				maxTemp = t
			}
		}
	}
	return maxTemp
}

func readVolume() int {
	out := run("pactl", "get-sink-volume", "@DEFAULT_SINK@")
	return parseVolumePercent(out)
}

func parseVolumePercent(s string) int {
	m := volRe.FindStringSubmatch(s)
	if len(m) < 2 {
		return 75
	}
	return atoiDefault(m[1], 75)
}

func readMute() bool {
	out := strings.ToLower(run("pactl", "get-sink-mute", "@DEFAULT_SINK@"))
	return strings.Contains(out, "yes")
}

func readBrightness() int {
	mx := atoiDefault(run("brightnessctl", "max"), 100)
	cu := atoiDefault(run("brightnessctl", "get"), 80)
	if mx <= 0 {
		return 80
	}
	return cu * 100 / mx
}

func parseWiFiEnabled(s string) bool {
	return strings.Contains(strings.ToLower(s), "enabled")
}

func readWiFiSSID() string {
	return run("sh", "-lc", "nmcli -t -f active,ssid dev wifi 2>/dev/null | grep '^yes' | cut -d: -f2 | head -1")
}

func atoiDefault(s string, fallback int) int {
	n, err := strconv.Atoi(strings.TrimSpace(s))
	if err != nil {
		return fallback
	}
	return n
}
