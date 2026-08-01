package network

import (
	"bytes"
	"crypto/rand"
	"encoding/base64"
	"encoding/json"
	"fmt"
	"net"
	"net/http"
	"os"
	"path/filepath"
	"sort"
	"strconv"
	"strings"
	"sync"
	"time"

	"quickshell/helpers/internal/common"
)

const (
	hotspotName            = "Quickshell Hotspot"
	hotspotDevice          = "wlo1"
	hotspotAPInterface     = "ap0"
	hotspotFallbackChannel = "6"
	iwPath                 = "/usr/sbin/iw"
)

type hotspotConfig struct {
	SSID     string `json:"ssid"`
	Password string `json:"password"`
}

type upstream struct {
	SSID    string
	Channel string
}

type client struct {
	Name string
	IP   string
	MAC  string
}

func Run(argv []string) int {
	action := "status"
	var args []string
	if len(argv) > 0 {
		action = argv[0]
		args = argv[1:]
	}
	config := loadHotspotConfig()

	switch action {
	case "status":
		printStatus()
	case "devices":
		printDevices()
	case "connections":
		printConnections()
	case "hotspot-status":
		printHotspotStatus(config)
	case "hotspot-diagnose":
		printHotspotDiagnosis(config)
	case "hotspot-save", "hotspot-config":
		return saveHotspotAction(config, args)
	case "hotspot-start":
		return startHotspot(config)
	case "hotspot-stop":
		return stopHotspot()
	case "wifi-scan":
		printWiFiScan(args)
	case "wifi-rescan":
		_ = runResultTimeout(5*time.Second, "nmcli", "device", "wifi", "rescan")
	case "wifi-saved":
		printSavedWiFiNetworks()
	case "wifi-share":
		printWiFiShare(args)
	case "speedtest":
		return runSpeedTest()
	case "wifi-connect":
		if len(args) < 3 {
			return 1
		}
		ifname := args[0]
		ssid := args[2]
		password := ""
		if len(args) > 3 {
			password = strings.TrimSpace(args[3])
		}
		savedUUID := getSavedWiFiUUID(ssid)
		if savedUUID != "" && password == "" {
			return common.RunAttached("nmcli", "connection", "up", "uuid", savedUUID)
		} else if savedUUID != "" && password != "" {
			_ = common.RunAttached("nmcli", "connection", "modify", "uuid", savedUUID, "wifi-sec.psk", password)
			return common.RunAttached("nmcli", "connection", "up", "uuid", savedUUID)
		} else {
			command := []string{"device", "wifi", "connect", ssid, "ifname", ifname}
			if password != "" {
				command = append(command, "password", password)
			}
			return common.RunAttached("nmcli", command...)
		}
	case "connect":
		if len(args) > 0 {
			_ = common.RunAttached("nmcli", "connection", "up", "uuid", args[0])
		}
	case "disconnect":
		if len(args) > 0 {
			_ = common.RunAttached("nmcli", "device", "disconnect", args[0])
		}
	case "monitor":
		if err := common.ReplaceProcess("nmcli", "monitor"); err != nil {
			fmt.Fprintln(os.Stderr, err)
			return 1
		}
	case "editor":
		if err := common.StartDetached("nm-connection-editor"); err != nil {
			fmt.Fprintln(os.Stderr, err)
			return 1
		}
	default:
		fmt.Fprintf(os.Stderr, "Unknown action: %s\n", action)
		return 1
	}
	return 0
}

func configPath() string {
	return filepath.Join(common.HomeDir(), ".config", "quickshell", "hotspot.json")
}

func loadHotspotConfig() hotspotConfig {
	hostname, _ := os.Hostname()
	config := hotspotConfig{SSID: "Hotspot-" + hostname}
	_ = common.ReadJSON(configPath(), &config)
	if config.SSID == "" {
		config.SSID = "Hotspot-" + hostname
	}
	if config.Password == "" {
		config.Password = strings.TrimSpace(run(
			"nmcli", "-s", "-g", "802-11-wireless-security.psk",
			"connection", "show", hotspotName,
		))
		if config.Password == "" {
			random := make([]byte, 10)
			if _, err := rand.Read(random); err == nil {
				config.Password = base64.RawURLEncoding.EncodeToString(random)
			} else {
				config.Password = fmt.Sprintf("qs-%d", time.Now().UnixNano())
			}
		}
		_ = saveHotspotConfig(config)
	}
	return config
}

func saveHotspotConfig(config hotspotConfig) error {
	return common.WriteJSON(configPath(), config, 0o600)
}

func run(name string, args ...string) string {
	return common.RunOutput(10*time.Second, name, args...)
}

func runResult(name string, args ...string) common.Result {
	return common.Run(20*time.Second, name, args...)
}

func runResultTimeout(timeout time.Duration, name string, args ...string) common.Result {
	return common.Run(timeout, name, args...)
}

func splitTerse(line string) []string {
	var result []string
	var current strings.Builder
	for index := 0; index < len(line); index++ {
		char := line[index]
		if char == ':' && (index == 0 || line[index-1] != '\\') {
			result = append(result, strings.ReplaceAll(current.String(), `\:`, `:`))
			current.Reset()
			continue
		}
		current.WriteByte(char)
	}
	result = append(result, strings.ReplaceAll(current.String(), `\:`, `:`))
	return result
}

func apInterfaceExists() bool {
	info, err := os.Stat(filepath.Join("/sys/class/net", hotspotAPInterface))
	return err == nil && info.IsDir()
}

func deriveAPMAC() string {
	data, err := os.ReadFile(filepath.Join("/sys/class/net", hotspotDevice, "address"))
	if err != nil {
		return "da:80:83:05:33:d4"
	}
	mac, err := net.ParseMAC(strings.TrimSpace(string(data)))
	if err != nil || len(mac) != 6 {
		return "da:80:83:05:33:d4"
	}
	mac[0] |= 0x02
	mac[5]++
	return mac.String()
}

func createAPInterface() common.Result {
	if apInterfaceExists() {
		return common.Result{Code: 0, Stdout: hotspotAPInterface + " already exists\n"}
	}
	result := runResult(
		"sudo", iwPath, "dev", hotspotDevice, "interface", "add",
		hotspotAPInterface, "type", "__ap", "addr", deriveAPMAC(),
	)
	if result.Code == 0 {
		_ = runResult("sudo", "ip", "link", "set", hotspotAPInterface, "up")
	}
	return result
}

func destroyAPInterface() common.Result {
	if !apInterfaceExists() {
		return common.Result{Code: 0}
	}
	return runResult("sudo", iwPath, "dev", hotspotAPInterface, "del")
}

func setupForwarding() {
	_ = runResult("sudo", "iptables", "-I", "DOCKER-USER", "-i", hotspotAPInterface, "-j", "ACCEPT")
	_ = runResult(
		"sudo", "iptables", "-I", "DOCKER-USER", "-o", hotspotAPInterface,
		"-m", "state", "--state", "RELATED,ESTABLISHED", "-j", "ACCEPT",
	)
}

func teardownForwarding() {
	_ = runResult("sudo", "iptables", "-D", "DOCKER-USER", "-i", hotspotAPInterface, "-j", "ACCEPT")
	_ = runResult(
		"sudo", "iptables", "-D", "DOCKER-USER", "-o", hotspotAPInterface,
		"-m", "state", "--state", "RELATED,ESTABLISHED", "-j", "ACCEPT",
	)
}

func hotspotAvailable() bool {
	out := run("nmcli", "-t", "-f", "GENERAL.DEVICE,WIFI-PROPERTIES.AP", "device", "show", hotspotDevice)
	hasDevice := false
	hasAP := false
	for _, line := range strings.Split(strings.TrimSpace(out), "\n") {
		switch line {
		case "GENERAL.DEVICE:" + hotspotDevice:
			hasDevice = true
		case "WIFI-PROPERTIES.AP:yes":
			hasAP = true
		}
	}
	return hasDevice && hasAP && common.FileExists(iwPath)
}

func hotspotActiveDevice() string {
	out := run("nmcli", "-t", "-f", "NAME,TYPE,DEVICE", "connection", "show", "--active")
	for _, line := range strings.Split(strings.TrimSpace(out), "\n") {
		if line == "" {
			continue
		}
		parts := splitTerse(line)
		if len(parts) < 3 {
			continue
		}
		device := strings.Join(parts[2:], ":")
		if parts[0] == hotspotName && device != "" && device != "--" {
			return device
		}
	}
	return ""
}

func hotspotProfileExists() bool {
	return runResult("nmcli", "-t", "-f", "NAME", "connection", "show", hotspotName).Code == 0
}

func activeWiFiUpstream() upstream {
	var result upstream
	out := run("nmcli", "-t", "-f", "NAME,TYPE,DEVICE", "connection", "show", "--active")
	for _, line := range strings.Split(strings.TrimSpace(out), "\n") {
		if line == "" {
			continue
		}
		parts := splitTerse(line)
		if len(parts) < 3 {
			continue
		}
		device := strings.Join(parts[2:], ":")
		if parts[0] != hotspotName &&
			(parts[1] == "802-11-wireless" || parts[1] == "wifi") &&
			device == hotspotDevice {
			result.SSID = parts[0]
			break
		}
	}

	out = run("nmcli", "-t", "-f", "IN-USE,SSID,CHAN,FREQ,DEVICE", "device", "wifi", "list", "--rescan", "no")
	for _, line := range strings.Split(strings.TrimSpace(out), "\n") {
		if line == "" {
			continue
		}
		parts := splitTerse(line)
		if len(parts) < 5 {
			continue
		}
		device := strings.Join(parts[4:], ":")
		if parts[0] == "*" && device == hotspotDevice {
			if result.SSID == "" {
				result.SSID = parts[1]
			}
			result.Channel = parts[2]
			break
		}
	}
	return result
}

func channelBand(channel string) string {
	value, err := strconv.Atoi(channel)
	if err != nil || value <= 14 {
		return "bg"
	}
	return "a"
}

func hotspotChannel(value upstream) string {
	if value.Channel == "" {
		return hotspotFallbackChannel
	}
	if _, err := strconv.Atoi(value.Channel); err != nil {
		return hotspotFallbackChannel
	}
	return value.Channel
}

func hotspotSummary(available, active bool, value upstream, channel string) string {
	switch {
	case !available:
		return fmt.Sprintf("AP mode is not available on %s", hotspotDevice)
	case active && value.SSID != "":
		return fmt.Sprintf("Sharing Wi-Fi from %s on ch %s via %s", value.SSID, channel, hotspotAPInterface)
	case active:
		return fmt.Sprintf("Active on %s", hotspotAPInterface)
	case value.SSID != "" && channel != "":
		return fmt.Sprintf("Ready to share %s on channel %s", value.SSID, channel)
	default:
		return fmt.Sprintf("Ready on %s; no upstream Wi-Fi detected", hotspotDevice)
	}
}

func ensureHotspotProfile(config hotspotConfig, value upstream) common.Result {
	channel := hotspotChannel(value)
	if !hotspotProfileExists() {
		result := runResult(
			"nmcli", "connection", "add",
			"type", "wifi",
			"ifname", hotspotAPInterface,
			"con-name", hotspotName,
			"autoconnect", "no",
			"ssid", config.SSID,
		)
		if result.Code != 0 {
			return result
		}
	}
	return runResult(
		"nmcli", "connection", "modify", hotspotName,
		"connection.autoconnect", "no",
		"connection.interface-name", hotspotAPInterface,
		"802-11-wireless.mode", "ap",
		"802-11-wireless.ssid", config.SSID,
		"802-11-wireless.band", channelBand(channel),
		"802-11-wireless.channel", channel,
		"802-11-wireless.cloned-mac-address", deriveAPMAC(),
		"wifi-sec.key-mgmt", "wpa-psk",
		"wifi-sec.proto", "rsn",
		"wifi-sec.pairwise", "ccmp",
		"wifi-sec.group", "ccmp",
		"wifi-sec.pmf", "1",
		"wifi-sec.psk", config.Password,
		"ipv4.method", "shared",
		"ipv6.method", "disabled",
	)
}

func leaseClients() map[string]client {
	result := make(map[string]client)
	patterns := []string{
		filepath.Join("/var/lib/NetworkManager", "dnsmasq-"+hotspotAPInterface+".leases"),
		filepath.Join("/var/lib/NetworkManager", "dnsmasq-"+hotspotDevice+".leases"),
		"/run/NetworkManager/dnsmasq-*.leases",
		"/var/lib/misc/dnsmasq.leases",
	}
	seen := make(map[string]bool)
	var paths []string
	for _, pattern := range patterns {
		matches, _ := filepath.Glob(pattern)
		if len(matches) == 0 && !strings.ContainsAny(pattern, "*?[") {
			matches = []string{pattern}
		}
		for _, path := range matches {
			if !seen[path] {
				seen[path] = true
				paths = append(paths, path)
			}
		}
	}
	for _, path := range paths {
		content, err := os.ReadFile(path)
		if err != nil {
			content = []byte(run("sudo", "cat", path))
		}
		for _, line := range strings.Split(strings.TrimSpace(string(content)), "\n") {
			fields := strings.Fields(line)
			if len(fields) < 3 {
				continue
			}
			mac, ip := fields[1], fields[2]
			name := "Device (" + ip + ")"
			if len(fields) > 3 && fields[3] != "" && fields[3] != "*" && fields[3] != mac {
				name = fields[3]
			}
			result[ip] = client{Name: name, IP: ip, MAC: mac}
		}
	}
	return result
}

func neighborClients(device string) map[string]client {
	result := make(map[string]client)
	if device == "" {
		return result
	}
	out := run("ip", "neigh", "show", "dev", device)
	for _, line := range strings.Split(strings.TrimSpace(out), "\n") {
		fields := strings.Fields(line)
		if len(fields) == 0 {
			continue
		}
		ip := fields[0]
		mac := ""
		for index, field := range fields {
			if field == "lladdr" && index+1 < len(fields) {
				mac = fields[index+1]
				break
			}
		}
		if ip != "" && mac != "" {
			result[ip] = client{Name: "Device (" + ip + ")", IP: ip, MAC: mac}
		}
	}
	return result
}

func hotspotClients(device string) []client {
	byIP := leaseClients()
	for ip, row := range neighborClients(device) {
		if _, exists := byIP[ip]; !exists {
			byIP[ip] = row
		}
	}
	result := make([]client, 0, len(byIP))
	for _, row := range byIP {
		result = append(result, row)
	}
	sort.Slice(result, func(i, j int) bool { return result[i].IP < result[j].IP })
	return result
}

func printStatus() {
	out := run("nmcli", "-t", "-f", "TYPE,STATE,CONNECTION", "device", "status")
	status := "NET offline"
	for _, line := range strings.Split(strings.TrimSpace(out), "\n") {
		parts := splitTerse(line)
		if len(parts) < 3 || parts[1] != "connected" {
			continue
		}
		connection := strings.Join(parts[2:], ":")
		if parts[0] == "wifi" || parts[0] == "802-11-wireless" {
			status = "\uf1eb  " + connection
			break
		}
		if parts[0] == "ethernet" || parts[0] == "802-3-ethernet" {
			status = "\uf6ff  " + connection
			break
		}
	}
	fmt.Println(status)
}

func printDevices() {
	out := run("nmcli", "-t", "-f", "DEVICE,TYPE,STATE,CONNECTION", "device", "status")
	for _, line := range strings.Split(strings.TrimSpace(out), "\n") {
		if line == "" {
			continue
		}
		parts := splitTerse(line)
		if len(parts) >= 4 {
			fmt.Println(strings.Join(parts[:4], "\t"))
		}
	}
}

func getActiveWiFiSignals() map[string]string {
	signals := make(map[string]string)
	out := run("nmcli", "-t", "-f", "IN-USE,SSID,SIGNAL,DEVICE", "device", "wifi", "list", "--rescan", "no")
	for _, line := range strings.Split(strings.TrimSpace(out), "\n") {
		if line == "" {
			continue
		}
		parts := splitTerse(line)
		if len(parts) >= 3 && parts[0] == "*" {
			ssid := parts[1]
			sig := parts[2]
			if ssid != "" && ssid != "--" {
				signals[ssid] = sig
			}
			if len(parts) >= 4 {
				device := strings.Join(parts[3:], ":")
				if device != "" && device != "--" {
					signals["dev:"+device] = sig
				}
			}
		}
	}
	return signals
}

func printConnections() {
	activeSignals := getActiveWiFiSignals()
	out := run("nmcli", "-t", "-f", "NAME,UUID,TYPE,DEVICE", "connection", "show")
	for _, line := range strings.Split(strings.TrimSpace(out), "\n") {
		if line == "" {
			continue
		}
		parts := splitTerse(line)
		if len(parts) < 4 {
			continue
		}
		device := strings.Join(parts[3:], ":")
		active := device != "" && device != "--"
		deviceOutput := ""
		if active {
			deviceOutput = device
		}
		signal := "0"
		if active && (parts[2] == "802-11-wireless" || parts[2] == "wifi" || parts[2] == "wireless") {
			if s, ok := activeSignals[parts[0]]; ok && s != "" {
				signal = s
			} else if s, ok := activeSignals["dev:"+device]; ok && s != "" {
				signal = s
			}
		}
		fmt.Printf("%s\t%s\t%s\t%s\t%s\t%s\n", parts[0], parts[1], parts[2], common.YesNo(active), deviceOutput, signal)
	}
}

func printHotspotStatus(config hotspotConfig) {
	available := hotspotAvailable()
	device := hotspotActiveDevice()
	active := device != ""
	value := activeWiFiUpstream()
	channel := hotspotChannel(value)
	outputDevice := hotspotAPInterface
	if active {
		outputDevice = device
	}
	fmt.Println(strings.Join([]string{
		common.Bool01(available),
		common.Bool01(active),
		config.SSID,
		outputDevice,
		value.SSID,
		channel,
		channelBand(channel),
		hotspotSummary(available, active, value, channel),
		config.Password,
	}, "\t"))
	if active {
		for _, row := range hotspotClients(device) {
			fmt.Printf("client\t%s\t%s\t%s\n", row.Name, row.IP, row.MAC)
		}
	}
}

func printHotspotDiagnosis(config hotspotConfig) {
	available := hotspotAvailable()
	device := hotspotActiveDevice()
	value := activeWiFiUpstream()
	channel := hotspotChannel(value)
	outputDevice := device
	if outputDevice == "" {
		outputDevice = hotspotAPInterface
	}
	fmt.Printf("available\t%s\n", common.YesNo(available))
	fmt.Printf("active\t%s\n", common.YesNo(device != ""))
	fmt.Printf("hotspot_ssid\t%s\n", config.SSID)
	fmt.Printf("hotspot_device\t%s\n", outputDevice)
	fmt.Printf("physical_device\t%s\n", hotspotDevice)
	fmt.Printf("ap_interface\t%s\n", hotspotAPInterface)
	fmt.Printf("ap_exists\t%s\n", common.YesNo(apInterfaceExists()))
	fmt.Printf("upstream_ssid\t%s\n", value.SSID)
	fmt.Printf("upstream_channel\t%s\n", value.Channel)
	fmt.Printf("selected_channel\t%s\n", channel)
	fmt.Printf("selected_band\t%s\n", channelBand(channel))
	fmt.Printf("iw_path\t%s\n", iwPath)
	fmt.Printf("iw_available\t%s\n", common.YesNo(common.FileExists(iwPath)))
	fmt.Printf("summary\t%s\n", hotspotSummary(available, device != "", value, channel))
}

func saveHotspotAction(current hotspotConfig, args []string) int {
	config := current
	for index := 0; index < len(args); index++ {
		switch {
		case args[index] == "--ssid" && index+1 < len(args):
			config.SSID = args[index+1]
			index++
		case args[index] == "--password" && index+1 < len(args):
			config.Password = args[index+1]
			index++
		}
	}
	if len(config.Password) < 8 {
		fmt.Fprintln(os.Stderr, "Password must be at least 8 characters long")
		return 1
	}
	_ = saveHotspotConfig(config)
	if hotspotProfileExists() {
		_ = run(
			"nmcli", "connection", "modify", hotspotName,
			"802-11-wireless.ssid", config.SSID,
			"wifi-sec.psk", config.Password,
		)
	}
	if hotspotActiveDevice() != "" {
		_ = runResultTimeout(30*time.Second, "nmcli", "connection", "up", hotspotName)
	}
	fmt.Printf("Saved hotspot configuration: SSID='%s'\n", config.SSID)
	return 0
}

func startHotspot(config hotspotConfig) int {
	if !hotspotAvailable() {
		fmt.Fprintf(os.Stderr, "Hotspot is not available on %s\n", hotspotDevice)
		return 1
	}
	value := activeWiFiUpstream()
	result := createAPInterface()
	if result.Code != 0 {
		fmt.Fprintf(os.Stderr, "Failed to create virtual AP interface %s\n", hotspotAPInterface)
		common.PrintResult(result)
		return result.Code
	}
	result = ensureHotspotProfile(config, value)
	common.PrintResult(result)
	if result.Code != 0 {
		_ = destroyAPInterface()
		return result.Code
	}
	result = runResultTimeout(30*time.Second, "nmcli", "connection", "up", hotspotName)
	common.PrintResult(result)
	if result.Code != 0 {
		_ = destroyAPInterface()
		return result.Code
	}
	setupForwarding()
	if value.SSID != "" && activeWiFiUpstream().SSID == "" {
		fmt.Fprintf(os.Stderr, "Warning: upstream Wi-Fi on %s dropped after hotspot start.\n", hotspotDevice)
	}
	return 0
}

func stopHotspot() int {
	teardownForwarding()
	result := runResult("nmcli", "connection", "down", hotspotName)
	common.PrintResult(result)
	if result.Code != 0 && !strings.Contains(result.Stderr, "not an active connection") {
		_ = destroyAPInterface()
		return result.Code
	}
	_ = destroyAPInterface()
	return 0
}

type wifiRow struct {
	InUse    string
	BSSID    string
	SSID     string
	Signal   int
	Security string
	Channel  string
	Device   string
	Saved    bool
}

func getSavedWiFiSSIDs() map[string]string {
	out := common.RunOutput(3*time.Second, "nmcli", "-t", "-f", "NAME,UUID,TYPE", "connection", "show")
	saved := make(map[string]string)
	for _, line := range strings.Split(strings.TrimSpace(out), "\n") {
		if line == "" {
			continue
		}
		parts := splitTerse(line)
		if len(parts) >= 3 && (parts[2] == "802-11-wireless" || parts[2] == "wifi") && parts[0] != hotspotName {
			saved[parts[0]] = parts[1]
		}
	}
	return saved
}

func getSavedWiFiUUID(ssid string) string {
	return getSavedWiFiSSIDs()[ssid]
}

func printWiFiScan(args []string) {
	rescan := "no"
	for index := 0; index < len(args); index++ {
		if args[index] == "--rescan" && index+1 < len(args) {
			rescan = args[index+1]
			index++
		}
	}
	out := run(
		"nmcli", "-t", "-f", "IN-USE,BSSID,SSID,SIGNAL,SECURITY,CHAN,DEVICE",
		"device", "wifi", "list", "--rescan", rescan,
	)
	savedMap := getSavedWiFiSSIDs()
	bySSID := make(map[string]*wifiRow)
	for _, line := range strings.Split(strings.TrimSpace(out), "\n") {
		if line == "" {
			continue
		}
		parts := splitTerse(line)
		if len(parts) < 7 {
			continue
		}
		inUse := parts[0]
		bssid := parts[1]
		ssid := parts[2]
		signalStr := parts[3]
		security := parts[4]
		channel := parts[5]
		device := strings.Join(parts[6:], ":")

		if ssid == "" || ssid == "--" {
			if inUse == "*" {
				upstream := activeWiFiUpstream()
				if upstream.SSID != "" && upstream.SSID != "--" {
					ssid = upstream.SSID
				} else {
					ssid = "Connected Wi-Fi"
				}
			} else {
				continue
			}
		}

		signal, err := strconv.Atoi(signalStr)
		if err != nil {
			signal = 0
		}

		_, isSaved := savedMap[ssid]

		existing, ok := bySSID[ssid]
		if !ok {
			bySSID[ssid] = &wifiRow{
				InUse:    inUse,
				BSSID:    bssid,
				SSID:     ssid,
				Signal:   signal,
				Security: security,
				Channel:  channel,
				Device:   device,
				Saved:    isSaved,
			}
		} else {
			if inUse == "*" {
				existing.InUse = "*"
			}
			if signal > existing.Signal {
				existing.BSSID = bssid
				existing.Signal = signal
				existing.Channel = channel
				if device != "" && device != "--" {
					existing.Device = device
				}
				if security != "" && security != "--" {
					existing.Security = security
				}
			}
		}
	}

	activeUpstream := activeWiFiUpstream()
	rows := make([]wifiRow, 0, len(bySSID))
	for _, row := range bySSID {
		if activeUpstream.SSID != "" && activeUpstream.SSID != "--" {
			if row.SSID == activeUpstream.SSID {
				row.InUse = "*"
			} else {
				row.InUse = " "
			}
		}
		rows = append(rows, *row)
	}

	sort.Slice(rows, func(i, j int) bool {
		if rows[i].InUse == "*" && rows[j].InUse != "*" {
			return true
		}
		if rows[i].InUse != "*" && rows[j].InUse == "*" {
			return false
		}
		if rows[i].Signal != rows[j].Signal {
			return rows[i].Signal > rows[j].Signal
		}
		return strings.ToLower(rows[i].SSID) < strings.ToLower(rows[j].SSID)
	})

	for _, row := range rows {
		savedFlag := "no"
		if row.Saved {
			savedFlag = "yes"
		}
		fmt.Printf(
			"%s\t%s\t%s\t%d\t%s\t%s\t%s\t%s\n",
			row.InUse, row.BSSID, row.SSID, row.Signal, row.Security, row.Channel, row.Device, savedFlag,
		)
	}
}

type savedWiFiRow struct {
	Name        string
	UUID        string
	Active      bool
	Device      string
	Autoconnect bool
	Password    string
}

func printSavedWiFiNetworks() {
	out := common.RunOutput(5*time.Second, "nmcli", "-t", "-f", "NAME,UUID,TYPE,DEVICE,ACTIVE,AUTOCONNECT", "connection", "show")
	var items []*savedWiFiRow
	for _, line := range strings.Split(strings.TrimSpace(out), "\n") {
		if line == "" {
			continue
		}
		parts := splitTerse(line)
		if len(parts) < 6 {
			continue
		}
		name := parts[0]
		uuid := parts[1]
		connType := parts[2]
		device := parts[3]
		active := parts[4] == "yes" || parts[4] == "true" || parts[4] == "1"
		autoconnect := parts[5] == "yes" || parts[5] == "true" || parts[5] == "1"

		if (connType == "802-11-wireless" || connType == "wifi") && name != hotspotName && name != "lo" {
			items = append(items, &savedWiFiRow{
				Name:        name,
				UUID:        uuid,
				Active:      active,
				Device:      device,
				Autoconnect: autoconnect,
			})
		}
	}

	var wg sync.WaitGroup
	for _, item := range items {
		wg.Add(1)
		go func(row *savedWiFiRow) {
			defer wg.Done()
			res := common.RunOutput(3*time.Second, "nmcli", "-s", "-g", "802-11-wireless-security.psk", "connection", "show", "uuid", row.UUID)
			row.Password = strings.TrimSpace(res)
		}(item)
	}
	wg.Wait()

	sort.Slice(items, func(i, j int) bool {
		if items[i].Active && !items[j].Active {
			return true
		}
		if !items[i].Active && items[j].Active {
			return false
		}
		return strings.ToLower(items[i].Name) < strings.ToLower(items[j].Name)
	})

	for _, item := range items {
		activeStr := "no"
		if item.Active {
			activeStr = "yes"
		}
		autoStr := "no"
		if item.Autoconnect {
			autoStr = "yes"
		}
		fmt.Printf("%s\t%s\t%s\t%s\t%s\t%s\n", item.Name, item.UUID, activeStr, item.Device, autoStr, item.Password)
	}
}

func runSpeedTest() int {
	bestPing := time.Hour
	for i := 0; i < 3; i++ {
		start := time.Now()
		conn, err := net.DialTimeout("tcp", "1.1.1.1:80", 2*time.Second)
		if err == nil {
			rtt := time.Since(start)
			conn.Close()
			if rtt < bestPing {
				bestPing = rtt
			}
		} else {
			start = time.Now()
			conn2, err2 := net.DialTimeout("tcp", "www.google.com:80", 2*time.Second)
			if err2 == nil {
				rtt := time.Since(start)
				conn2.Close()
				if rtt < bestPing {
					bestPing = rtt
				}
			}
		}
		time.Sleep(50 * time.Millisecond)
	}
	pingStr := "-- ms"
	if bestPing != time.Hour {
		pingStr = fmt.Sprintf("%d ms", bestPing.Milliseconds())
	}

	client := &http.Client{
		Timeout: 6 * time.Second,
	}

	downSpeedStr := "-- Mbps"
	start := time.Now()
	reqDown, _ := http.NewRequest("GET", "https://speed.cloudflare.com/__down?bytes=10000000", nil)
	if reqDown != nil {
		reqDown.Header.Set("User-Agent", "Mozilla/5.0 (X11; Linux x86_64)")
		resp, err := client.Do(reqDown)
		if err == nil && resp.StatusCode == 200 {
			buf := make([]byte, 32*1024)
			var totalBytes int64
			for {
				n, readErr := resp.Body.Read(buf)
				if n > 0 {
					totalBytes += int64(n)
				}
				if readErr != nil || time.Since(start) >= 5*time.Second {
					break
				}
			}
			resp.Body.Close()
			duration := time.Since(start).Seconds()
			if duration > 0.1 && totalBytes > 0 {
				mbps := (float64(totalBytes) * 8.0) / (duration * 1000000.0)
				downSpeedStr = fmt.Sprintf("%.1f Mbps", mbps)
			}
		}
	}
	if downSpeedStr == "-- Mbps" {
		start = time.Now()
		resp, err := client.Get("http://proof.ovh.net/files/10Mb.dat")
		if err == nil && resp.StatusCode == 200 {
			buf := make([]byte, 32*1024)
			var totalBytes int64
			for {
				n, readErr := resp.Body.Read(buf)
				if n > 0 {
					totalBytes += int64(n)
				}
				if readErr != nil || time.Since(start) >= 5*time.Second {
					break
				}
			}
			resp.Body.Close()
			duration := time.Since(start).Seconds()
			if duration > 0.1 && totalBytes > 0 {
				mbps := (float64(totalBytes) * 8.0) / (duration * 1000000.0)
				downSpeedStr = fmt.Sprintf("%.1f Mbps", mbps)
			}
		}
	}

	upSpeedStr := "-- Mbps"
	payload := make([]byte, 3000000)
	start = time.Now()
	req, reqErr := http.NewRequest("POST", "https://speed.cloudflare.com/__up", bytes.NewReader(payload))
	if reqErr == nil {
		req.Header.Set("Content-Type", "application/octet-stream")
		req.ContentLength = int64(len(payload))
		respUp, upErr := client.Do(req)
		if upErr == nil && (respUp.StatusCode == 200 || respUp.StatusCode == 201) {
			duration := time.Since(start).Seconds()
			if duration > 0.1 {
				mbps := (float64(len(payload)) * 8.0) / (duration * 1000000.0)
				upSpeedStr = fmt.Sprintf("%.1f Mbps", mbps)
			}
			respUp.Body.Close()
		}
	}

	fmt.Printf("%s\t%s\t%s\n", pingStr, downSpeedStr, upSpeedStr)
	return 0
}

type wifiShareResult struct {
	SSID     string `json:"ssid"`
	Password string `json:"password"`
	QRPath   string `json:"qrPath"`
	Success  bool   `json:"success"`
	Error    string `json:"error,omitempty"`
}

func printWiFiShare(args []string) {
	res := wifiShareResult{Success: false}
	defer func() {
		data, _ := json.Marshal(res)
		fmt.Println(string(data))
	}()

	var ssid, uuid string
	if len(args) > 0 && strings.TrimSpace(args[0]) != "" {
		target := strings.TrimSpace(args[0])
		out := common.RunOutput(3*time.Second, "nmcli", "-t", "-f", "NAME,UUID,TYPE", "connection", "show")
		for _, line := range strings.Split(strings.TrimSpace(out), "\n") {
			parts := splitTerse(line)
			if len(parts) >= 3 && (parts[2] == "802-11-wireless" || parts[2] == "wifi" || parts[2] == "wireless") {
				if parts[1] == target || parts[0] == target {
					ssid = parts[0]
					uuid = parts[1]
					break
				}
			}
		}
	}

	if ssid == "" || uuid == "" {
		out := common.RunOutput(3*time.Second, "nmcli", "-t", "-f", "NAME,UUID,TYPE,ACTIVE", "connection", "show")
		for _, line := range strings.Split(strings.TrimSpace(out), "\n") {
			parts := splitTerse(line)
			if len(parts) >= 4 && (parts[2] == "802-11-wireless" || parts[2] == "wifi" || parts[2] == "wireless") && (parts[3] == "yes" || parts[3] == "true" || parts[3] == "1") && parts[0] != hotspotName {
				ssid = parts[0]
				uuid = parts[1]
				break
			}
		}
	}

	if ssid == "" {
		res.Error = "No active Wi-Fi connection found"
		return
	}

	psk := strings.TrimSpace(common.RunOutput(3*time.Second, "nmcli", "-s", "-g", "802-11-wireless-security.psk", "connection", "show", "uuid", uuid))

	var qrString string
	if psk != "" {
		qrString = fmt.Sprintf("WIFI:T:WPA;S:%s;P:%s;;", ssid, psk)
	} else {
		qrString = fmt.Sprintf("WIFI:T:nopass;S:%s;;", ssid)
	}

	uid := fmt.Sprintf("%d", os.Getuid())
	imgPath := fmt.Sprintf("/run/user/%s/quickshell_wifi_share.png", uid)
	_ = common.RunOutput(3*time.Second, "qrencode", "-s", "8", "-l", "H", "-o", imgPath, qrString)
	if _, err := os.Stat(imgPath); err != nil {
		res.Error = "Failed to create QR code image"
		return
	}

	res.SSID = ssid
	res.Password = psk
	res.QRPath = fmt.Sprintf("file://%s", imgPath)
	res.Success = true
}
