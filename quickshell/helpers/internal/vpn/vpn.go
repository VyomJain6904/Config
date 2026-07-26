package vpn

import (
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"sort"
	"strings"
	"time"

	"quickshell/helpers/internal/common"
)

const (
	warpCommand          = "warp-cli"
	warpSystemService    = "warp-svc.service"
	warpUserService      = "warp-taskbar.service"
	targetFile           = "/tmp/qs_vpn_target.json"
	stateFile            = "/tmp/qs_vpn_state.json"
	cloudflareProfile    = "Cloudflare"
	cloudflareProfileKey = "cloudflare-warp"
	cloudflareLabel      = "Cloudflare WARP"
	polkitAgent          = "/usr/lib/x86_64-linux-gnu/ukui-polkit/polkit-ukui-authentication-agent-1"
)

var logoMap = map[string]string{
	"hackthebox":        "htb.svg",
	"htb":               "htb.svg",
	"tryhackme":         "tryhackme.svg",
	"thm":               "tryhackme.svg",
	"pwnedlabs":         "pwnedlabs.svg",
	"pwnedlab":          "pwnedlabs.svg",
	"hacksmarter":       "HackSmarter.svg",
	"offsec":            "offsec.svg",
	"offensivesecurity": "offsec.svg",
	"cloudflare":        "cloudflare.svg",
}

type profile struct {
	Name string
	Path string
}

func Run(argv []string) int {
	action := "status"
	var args []string
	if len(argv) > 0 {
		action = argv[0]
		args = argv[1:]
	}

	switch action {
	case "status":
		printStatus()
		return 0
	case "list":
		listProfiles()
		return 0
	case "connect":
		return connect(args)
	case "disconnect":
		return disconnect()
	default:
		fmt.Fprintf(os.Stderr, "Unknown action: %s\n", action)
		return 2
	}
}

func vpnDir() string {
	return filepath.Join(common.HomeDir(), "vpn")
}

func vpnCommand() string {
	return filepath.Join(common.HomeDir(), ".local", "bin", "vpn")
}

func polkitStylesheet() string {
	return filepath.Join(common.HomeDir(), ".config", "ukui-polkit", "polkit-dark.qss")
}

func readObject(path string) map[string]any {
	result := make(map[string]any)
	if err := common.ReadJSON(path, &result); err != nil {
		return map[string]any{}
	}
	return result
}

func stringValue(object map[string]any, key string) string {
	value, _ := object[key].(string)
	return value
}

func vpnIP() string {
	result := common.Run(10*time.Second, "ip", "-4", "addr", "show", "tun0")
	if result.Code != 0 {
		return ""
	}
	for _, rawLine := range strings.Split(result.Stdout, "\n") {
		line := strings.TrimSpace(rawLine)
		if !strings.HasPrefix(line, "inet ") {
			continue
		}
		fields := strings.Fields(line)
		if len(fields) > 1 {
			return strings.SplitN(fields[1], "/", 2)[0]
		}
	}
	return ""
}

func warpAvailable() bool {
	return common.ExecutableExists(warpCommand)
}

func warpResult(args ...string) common.Result {
	if !warpAvailable() {
		return common.Result{Code: 127, Stderr: "warp-cli is not installed"}
	}
	fullArgs := append([]string{"--no-ansi", "--no-paginate"}, args...)
	return common.Run(20*time.Second, warpCommand, fullArgs...)
}

func warpConnected() bool {
	result := warpResult("status")
	if result.Code != 0 {
		return false
	}
	for _, line := range strings.Split(result.Stdout, "\n") {
		text := strings.ToLower(strings.TrimSpace(line))
		if text == "" {
			continue
		}
		if strings.Contains(text, "disconnected") {
			return false
		}
		if text == "connected" || strings.Contains(text, "status update: connected") || strings.HasPrefix(text, "connected") {
			return true
		}
	}
	return false
}

func printStatus() {
	ip := vpnIP()
	if ip != "" {
		target := stringValue(readObject(targetFile), "targetIp")
		activeProfile := stringValue(readObject(stateFile), "activeProfile")
		fmt.Printf("1\t%s\t%s\t%s\n", ip, target, activeProfile)
		return
	}
	if warpConnected() {
		fmt.Printf("1\t%s\t\t%s\n", cloudflareLabel, cloudflareProfile)
		return
	}
	fmt.Println("0\t\t\t")
}

func profiles() []profile {
	paths, _ := filepath.Glob(filepath.Join(vpnDir(), "*.ovpn"))
	sort.Strings(paths)
	result := make([]profile, 0, len(paths))
	for _, path := range paths {
		name := strings.TrimSuffix(filepath.Base(path), filepath.Ext(path))
		result = append(result, profile{Name: name, Path: path})
	}
	return result
}

func logoPath(name string) string {
	var normalized strings.Builder
	for _, char := range strings.ToLower(name) {
		if char >= 'a' && char <= 'z' || char >= '0' && char <= '9' {
			normalized.WriteRune(char)
		}
	}
	logo := logoMap[normalized.String()]
	if logo == "" {
		return ""
	}
	path := filepath.Join(vpnDir(), "img", logo)
	if common.FileExists(path) {
		return path
	}
	return ""
}

func listProfiles() {
	activeProfile := stringValue(readObject(stateFile), "activeProfile")
	ip := vpnIP()
	for _, item := range profiles() {
		active := item.Name == activeProfile && ip != ""
		fmt.Printf("%s\t%s\t%s\t%s\n", item.Name, item.Path, common.Bool01(active), logoPath(item.Name))
	}
	if warpAvailable() {
		fmt.Printf(
			"%s\t%s\t%s\t%s\n",
			cloudflareProfile,
			cloudflareProfileKey,
			common.Bool01(warpConnected()),
			logoPath(cloudflareProfile),
		)
	}
}

func validateProfile(path string) (string, error) {
	resolved, err := filepath.EvalSymlinks(path)
	if err != nil {
		return "", fmt.Errorf("VPN profile does not exist")
	}
	resolved, err = filepath.Abs(resolved)
	if err != nil {
		return "", fmt.Errorf("Invalid VPN profile")
	}
	root, err := filepath.EvalSymlinks(vpnDir())
	if err != nil {
		root = vpnDir()
	}
	root, _ = filepath.Abs(root)
	if filepath.Ext(resolved) != ".ovpn" || !strings.HasPrefix(resolved, root+string(os.PathSeparator)) {
		return "", fmt.Errorf("Invalid VPN profile")
	}
	info, err := os.Stat(resolved)
	if err != nil || !info.Mode().IsRegular() {
		return "", fmt.Errorf("VPN profile does not exist")
	}
	return resolved, nil
}

func connect(args []string) int {
	if len(args) < 1 {
		fmt.Fprintln(os.Stderr, "Missing VPN profile")
		return 2
	}
	if args[0] == cloudflareProfileKey {
		if code := startWarpServices(); code != 0 {
			return code
		}
		return runWarp("connect")
	}

	profilePath, err := validateProfile(args[0])
	if err != nil {
		fmt.Fprintln(os.Stderr, err)
		return 2
	}
	targetIP := ""
	if len(args) > 1 {
		targetIP = args[1]
	}
	return runVPN(vpnCommand(), "--target-ip", targetIP, "--", profilePath)
}

func disconnect() int {
	code := 0
	openVPNActive := vpnIP() != ""
	wasWarpConnected := warpConnected()
	shouldStopWarp := wasWarpConnected || (!openVPNActive && warpResult("status").Code == 0)

	if openVPNActive {
		code = runVPN(vpnCommand(), "--disconnect")
	}
	if wasWarpConnected {
		warpCode := runWarp("disconnect")
		if code == 0 {
			code = warpCode
		}
	}
	if shouldStopWarp {
		stopCode := stopWarpServices()
		if code == 0 {
			code = stopCode
		}
	}
	return code
}

func runVPN(name string, args ...string) int {
	return common.RunAttached(name, args...)
}

func runWarp(args ...string) int {
	result := warpResult(args...)
	common.PrintResult(result)
	return result.Code
}

func ensurePolkitAgent() {
	uid := fmt.Sprintf("%d", os.Getuid())
	if common.Run(3*time.Second, "pgrep", "-u", uid, "-f", "polkit.*authentication.*agent|polkit-.*agent").Code == 0 {
		return
	}
	info, err := os.Stat(polkitAgent)
	if err != nil || info.Mode()&0o111 == 0 {
		return
	}
	args := []string{}
	if common.FileExists(polkitStylesheet()) {
		args = append(args, "-stylesheet", polkitStylesheet())
	}
	if common.StartDetached(polkitAgent, args...) == nil {
		time.Sleep(200 * time.Millisecond)
	}
}

func runUserService(action string) int {
	systemctl, err := exec.LookPath("systemctl")
	if err != nil {
		fmt.Fprintln(os.Stderr, "systemctl is required for Cloudflare WARP service control")
		return 1
	}
	result := common.Run(30*time.Second, systemctl, "--user", action, warpUserService)
	common.PrintResult(result)
	return result.Code
}

func runSystemService(action string) int {
	systemctl, systemctlErr := exec.LookPath("systemctl")
	if systemctlErr != nil {
		fmt.Fprintln(os.Stderr, "systemctl is required for Cloudflare WARP service control")
		return 1
	}
	pkexec, pkexecErr := exec.LookPath("pkexec")
	if pkexecErr != nil {
		fmt.Fprintln(os.Stderr, "pkexec is required for Cloudflare WARP service control")
		return 1
	}
	ensurePolkitAgent()
	result := common.Run(2*time.Minute, pkexec, systemctl, action, warpSystemService)
	common.PrintResult(result)
	return result.Code
}

func waitForWarpDaemon() bool {
	deadline := time.Now().Add(6 * time.Second)
	for time.Now().Before(deadline) {
		if warpResult("status").Code == 0 {
			return true
		}
		time.Sleep(250 * time.Millisecond)
	}
	return warpResult("status").Code == 0
}

func startWarpServices() int {
	if code := runSystemService("start"); code != 0 {
		return code
	}
	if !waitForWarpDaemon() {
		fmt.Fprintln(os.Stderr, "Cloudflare WARP daemon did not become ready")
		return 1
	}
	return runUserService("start")
}

func stopWarpServices() int {
	userCode := runUserService("stop")
	if common.ExecutableExists("pkill") {
		_ = common.Run(5*time.Second, "pkill", "-x", "warp-taskbar")
	}
	systemCode := runSystemService("stop")
	if systemCode != 0 {
		return systemCode
	}
	return userCode
}
