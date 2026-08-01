package ai

import (
	"context"
	"crypto/tls"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"math"
	"net/http"
	"os"
	"os/exec"
	"path/filepath"
	"regexp"
	"sort"
	"strconv"
	"strings"
	"syscall"
	"time"

	"github.com/creack/pty"
)

const (
	antigravityCLISource      = "Antigravity CLI localhost"
	antigravityQuotaPath      = "/exa.language_server_pb.LanguageServerService/RetrieveUserQuotaSummary"
	antigravityUserStatusPath = "/exa.language_server_pb.LanguageServerService/GetUserStatus"
)

type agyQuotaSummaryResponse struct {
	Response struct {
		Groups []agyQuotaGroup `json:"groups"`
	} `json:"response"`
}

type agyQuotaGroup struct {
	DisplayName string           `json:"displayName"`
	Buckets     []agyQuotaBucket `json:"buckets"`
}

type agyQuotaBucket struct {
	BucketID          string   `json:"bucketId"`
	DisplayName       string   `json:"displayName"`
	Window            string   `json:"window"`
	RemainingFraction *float64 `json:"remainingFraction"`
	Disabled          bool     `json:"disabled"`
	ResetTime         string   `json:"resetTime"`
}

type agyUserStatusResponse struct {
	UserStatus struct {
		PlanStatus struct {
			PlanInfo struct {
				PlanName string `json:"planName"`
			} `json:"planInfo"`
		} `json:"planStatus"`
		UserTier struct {
			Name string `json:"name"`
		} `json:"userTier"`
		CascadeModelConfigData struct {
			ClientModelConfigs []agyModelConfig `json:"clientModelConfigs"`
			ClientModelSorts   []struct {
				Groups []struct {
					ModelLabels []string `json:"modelLabels"`
				} `json:"groups"`
			} `json:"clientModelSorts"`
		} `json:"cascadeModelConfigData"`
	} `json:"userStatus"`
}

type agyModelConfig struct {
	Label        string `json:"label"`
	ModelID      string `json:"modelId"`
	ModelOrAlias struct {
		Model string `json:"model"`
	} `json:"modelOrAlias"`
	QuotaInfo *struct {
		RemainingFraction *float64 `json:"remainingFraction"`
		ResetTime         string   `json:"resetTime"`
	} `json:"quotaInfo"`
}

func collectAntigravity(ctx context.Context, mode remoteMode) PlatformUsage {
	if mode != remoteFull {
		if cached, ok := cachedAntigravityCLI(6 * time.Minute); ok {
			cached.State = "cached"
			return cached
		}
		return collectAntigravityIDE()
	}

	live, err := collectAntigravityCLI(ctx)
	if err == nil {
		return live
	}
	message := "Antigravity CLI quota unavailable: " + err.Error()
	if cached, ok := cachedAntigravityCLI(30 * time.Minute); ok {
		cached.State = "cached"
		cached.Error = message + "; showing last verified CLI data"
		return cached
	}

	fallback := collectAntigravityIDE()
	if fallback.State != "unavailable" {
		fallback.State = "cached"
		fallback.Error = message + "; showing Antigravity IDE fallback"
		return fallback
	}
	if fallback.Error != "" {
		message += "; " + fallback.Error
	}
	fallback.Error = message
	return fallback
}

func cachedAntigravityCLI(maxAge time.Duration) (PlatformUsage, bool) {
	snapshot, ok := readSnapshotCache()
	if !ok {
		return PlatformUsage{}, false
	}
	now := time.Now()
	for _, platform := range snapshot.Platforms {
		if platform.ID != "antigravity" || platform.Source != antigravityCLISource || len(platform.Models) == 0 {
			continue
		}
		updated := time.Unix(platform.UpdatedAt, 0)
		if updated.After(now.Add(time.Minute)) || now.Sub(updated) > maxAge {
			return PlatformUsage{}, false
		}
		return platform, true
	}
	return PlatformUsage{}, false
}

func collectAntigravityCLI(ctx context.Context) (PlatformUsage, error) {
	binary, err := resolveAgyBinary()
	if err != nil {
		return PlatformUsage{}, err
	}

	for _, pid := range matchingAgyPIDs(binary) {
		if result, fetchErr := fetchAgySnapshot(ctx, pid); fetchErr == nil {
			return result, nil
		}
	}

	cmd := exec.Command(binary)
	cmd.Env = append(os.Environ(), "TERM=xterm-256color", "NO_COLOR=1")
	if home, homeErr := os.UserHomeDir(); homeErr == nil {
		cmd.Dir = home
	}
	terminal, err := pty.Start(cmd)
	if err != nil {
		return PlatformUsage{}, fmt.Errorf("could not start agy: %w", err)
	}
	go func() {
		_, _ = io.Copy(io.Discard, terminal)
	}()
	defer stopOwnedAgy(cmd, terminal)

	deadline := time.NewTimer(12 * time.Second)
	defer deadline.Stop()
	ticker := time.NewTicker(250 * time.Millisecond)
	defer ticker.Stop()
	var lastErr error
	for {
		if result, fetchErr := fetchAgySnapshot(ctx, cmd.Process.Pid); fetchErr == nil {
			return result, nil
		} else {
			lastErr = fetchErr
		}
		select {
		case <-ctx.Done():
			return PlatformUsage{}, ctx.Err()
		case <-deadline.C:
			if lastErr == nil {
				lastErr = errors.New("quota endpoint did not become ready")
			}
			return PlatformUsage{}, lastErr
		case <-ticker.C:
		}
	}
}

func resolveAgyBinary() (string, error) {
	candidates := []string{}
	if override := strings.TrimSpace(os.Getenv("ANTIGRAVITY_CLI_PATH")); override != "" {
		candidates = append(candidates, override)
	}
	if found, err := exec.LookPath("agy"); err == nil {
		candidates = append(candidates, found)
	}
	if home, err := os.UserHomeDir(); err == nil {
		candidates = append(candidates, filepath.Join(home, ".local", "bin", "agy"))
	}
	seen := map[string]bool{}
	for _, candidate := range candidates {
		absolute, err := filepath.Abs(candidate)
		if err != nil || seen[absolute] {
			continue
		}
		seen[absolute] = true
		info, err := os.Stat(absolute)
		if err == nil && !info.IsDir() && info.Mode()&0o111 != 0 {
			return absolute, nil
		}
	}
	return "", errors.New("agy CLI not found")
}

func matchingAgyPIDs(binary string) []int {
	canonical, err := filepath.EvalSymlinks(binary)
	if err != nil {
		canonical = binary
	}
	entries, err := os.ReadDir("/proc")
	if err != nil {
		return nil
	}
	pids := []int{}
	for _, entry := range entries {
		pid, parseErr := strconv.Atoi(entry.Name())
		if parseErr != nil || pid == os.Getpid() {
			continue
		}
		executable, linkErr := os.Readlink(filepath.Join("/proc", entry.Name(), "exe"))
		if linkErr != nil {
			continue
		}
		resolved, resolveErr := filepath.EvalSymlinks(executable)
		if resolveErr != nil {
			resolved = executable
		}
		if resolved == canonical {
			pids = append(pids, pid)
		}
	}
	sort.Ints(pids)
	return pids
}

var agyListenPortPattern = regexp.MustCompile(`:(\d+) \(LISTEN\)`)

func listeningPorts(ctx context.Context, pid int) []int {
	command := exec.CommandContext(ctx, "lsof", "-nP", "-a", "-p", strconv.Itoa(pid), "-iTCP", "-sTCP:LISTEN")
	output, err := command.Output()
	if err != nil {
		return nil
	}
	return parseAgyListeningPorts(output)
}

func parseAgyListeningPorts(output []byte) []int {
	ports := []int{}
	seen := map[int]bool{}
	for _, match := range agyListenPortPattern.FindAllSubmatch(output, -1) {
		port, parseErr := strconv.Atoi(string(match[1]))
		if parseErr == nil && port > 0 && port <= 65535 && !seen[port] {
			seen[port] = true
			ports = append(ports, port)
		}
	}
	return ports
}

func fetchAgySnapshot(ctx context.Context, pid int) (PlatformUsage, error) {
	ports := listeningPorts(ctx, pid)
	if len(ports) == 0 {
		return PlatformUsage{}, errors.New("agy has no ready localhost port")
	}
	var lastErr error
	for _, port := range ports {
		var summary agyQuotaSummaryResponse
		if err := postAgyJSON(ctx, port, antigravityQuotaPath, map[string]any{"forceRefresh": true}, &summary); err != nil {
			lastErr = err
			continue
		}
		if !hasUsableAgyQuota(summary) {
			lastErr = errors.New("agy returned no usable quota buckets")
			continue
		}
		var status agyUserStatusResponse
		body := map[string]any{"metadata": map[string]string{
			"ideName": "antigravity", "extensionName": "antigravity", "locale": "en", "ideVersion": "unknown",
		}}
		if err := postAgyJSON(ctx, port, antigravityUserStatusPath, body, &status); err != nil {
			lastErr = err
			continue
		}
		result, err := antigravityFromCLI(summary, status)
		if err == nil {
			return result, nil
		}
		lastErr = err
	}
	if lastErr == nil {
		lastErr = errors.New("agy quota request failed")
	}
	return PlatformUsage{}, lastErr
}

func postAgyJSON(ctx context.Context, port int, path string, body any, target any) error {
	payload, err := json.Marshal(body)
	if err != nil {
		return err
	}
	request, err := http.NewRequestWithContext(ctx, http.MethodPost,
		fmt.Sprintf("https://127.0.0.1:%d%s", port, path), strings.NewReader(string(payload)))
	if err != nil {
		return err
	}
	request.Header.Set("Content-Type", "application/json")
	request.Header.Set("Connect-Protocol-Version", "1")
	transport := &http.Transport{
		Proxy:           nil,
		TLSClientConfig: &tls.Config{InsecureSkipVerify: true}, // Loopback-only server uses a self-signed certificate.
	}
	client := &http.Client{Transport: transport, Timeout: 2 * time.Second}
	response, err := client.Do(request)
	if err != nil {
		return err
	}
	defer response.Body.Close()
	if response.StatusCode != http.StatusOK {
		_, _ = io.Copy(io.Discard, io.LimitReader(response.Body, 32*1024))
		return fmt.Errorf("agy endpoint returned HTTP %d", response.StatusCode)
	}
	decoder := json.NewDecoder(io.LimitReader(response.Body, 4*1024*1024))
	if err := decoder.Decode(target); err != nil {
		return fmt.Errorf("could not decode agy response: %w", err)
	}
	return nil
}

func hasUsableAgyQuota(summary agyQuotaSummaryResponse) bool {
	for _, group := range summary.Response.Groups {
		for _, bucket := range group.Buckets {
			if !bucket.Disabled && validFraction(bucket.RemainingFraction) {
				return true
			}
		}
	}
	return false
}

func antigravityFromCLI(summary agyQuotaSummaryResponse, status agyUserStatusResponse) (PlatformUsage, error) {
	result := emptyPlatform("antigravity", "Antigravity", antigravityCLISource)
	result.State = "live"
	result.UpdatedAt = time.Now().Unix()
	result.Plan = strings.ToUpper(strings.TrimSpace(status.UserStatus.UserTier.Name))
	if result.Plan == "" {
		result.Plan = strings.ToUpper(strings.TrimSpace(status.UserStatus.PlanStatus.PlanInfo.PlanName))
	}
	if result.Plan == "" {
		result.Plan = "SIGNED IN"
	}

	bindings := map[string]*QuotaWindow{}
	for _, group := range summary.Response.Groups {
		pool := antigravityPool(group.DisplayName, "")
		if pool == "" {
			continue
		}
		for _, bucket := range group.Buckets {
			if bucket.Disabled || !validFraction(bucket.RemainingFraction) {
				continue
			}
			candidate := quotaWindowFromAgyBucket(pool, bucket)
			current := bindings[pool]
			if current == nil || candidate.RemainingPercent < current.RemainingPercent ||
				(candidate.RemainingPercent == current.RemainingPercent && candidate.DurationMinutes < current.DurationMinutes) {
				bindings[pool] = candidate
			}
		}
	}

	configs := status.UserStatus.CascadeModelConfigData.ClientModelConfigs
	byLabel := make(map[string]agyModelConfig, len(configs))
	for _, config := range configs {
		if strings.TrimSpace(config.Label) != "" {
			byLabel[config.Label] = config
		}
	}
	ordered := make([]agyModelConfig, 0, len(configs))
	added := map[string]bool{}
	for _, sortGroup := range status.UserStatus.CascadeModelConfigData.ClientModelSorts {
		for _, group := range sortGroup.Groups {
			for _, label := range group.ModelLabels {
				if config, ok := byLabel[label]; ok && !added[label] {
					ordered = append(ordered, config)
					added[label] = true
				}
			}
		}
	}
	for _, config := range configs {
		if !added[config.Label] {
			ordered = append(ordered, config)
			added[config.Label] = true
		}
	}

	for _, config := range ordered {
		pool := antigravityPool(config.Label, firstNonEmpty(config.ModelID, config.ModelOrAlias.Model))
		quota := cloneQuota(bindings[pool])
		if quota == nil {
			quota = quotaFromAgyModelConfig(config, pool)
		}
		result.Models = append(result.Models, ModelUsage{
			Provider: antigravityProvider(pool), Model: config.Label, Kind: "hosted", Quota: quota,
		})
	}
	if len(result.Models) == 0 {
		return PlatformUsage{}, errors.New("agy returned no model configurations")
	}
	return result, nil
}

func validFraction(value *float64) bool {
	return value != nil && !math.IsNaN(*value) && !math.IsInf(*value, 0)
}

func quotaWindowFromAgyBucket(pool string, bucket agyQuotaBucket) *QuotaWindow {
	remaining := math.Max(0, math.Min(100, *bucket.RemainingFraction*100))
	windowLabel, duration := agyWindowLabel(bucket)
	return &QuotaWindow{
		ID:               "agy-" + pool + "-" + bucket.BucketID,
		Label:            windowLabel + " · Shared " + antigravityPoolLabel(pool),
		PercentKnown:     true,
		UsedPercent:      100 - remaining,
		RemainingPercent: remaining,
		ResetAt:          parseAgyReset(bucket.ResetTime),
		DurationMinutes:  duration,
	}
}

func quotaFromAgyModelConfig(config agyModelConfig, pool string) *QuotaWindow {
	if config.QuotaInfo == nil {
		return nil
	}
	reset := parseAgyReset(config.QuotaInfo.ResetTime)
	if !validFraction(config.QuotaInfo.RemainingFraction) {
		if reset == 0 {
			return nil
		}
		return &QuotaWindow{ID: "agy-model", Label: "Session · Model quota", ResetAt: reset}
	}
	remaining := math.Max(0, math.Min(100, *config.QuotaInfo.RemainingFraction*100))
	label := "Session · Model quota"
	if pool != "" {
		label = "Session · Shared " + antigravityPoolLabel(pool)
	}
	return &QuotaWindow{
		ID: "agy-model", Label: label, PercentKnown: true,
		UsedPercent: 100 - remaining, RemainingPercent: remaining, ResetAt: reset,
	}
}

func agyWindowLabel(bucket agyQuotaBucket) (string, int64) {
	value := strings.ToLower(bucket.Window + " " + bucket.DisplayName + " " + bucket.BucketID)
	if strings.Contains(value, "week") {
		return "Weekly", 10080
	}
	if strings.Contains(value, "5h") || strings.Contains(value, "five hour") || strings.Contains(value, "five-hour") {
		return "5-hour", 300
	}
	if strings.TrimSpace(bucket.DisplayName) != "" {
		return strings.TrimSpace(bucket.DisplayName), 0
	}
	return "Usage", 0
}

func antigravityPool(label, modelID string) string {
	value := strings.ToLower(label + " " + modelID)
	if strings.Contains(value, "gemini") {
		return "gemini"
	}
	if strings.Contains(value, "claude") || strings.Contains(value, "gpt") {
		return "third-party"
	}
	return ""
}

func antigravityPoolLabel(pool string) string {
	if pool == "gemini" {
		return "Gemini"
	}
	if pool == "third-party" {
		return "Claude + GPT"
	}
	return "Antigravity"
}

func antigravityProvider(pool string) string {
	if pool == "gemini" {
		return "google"
	}
	return "antigravity"
}

func cloneQuota(quota *QuotaWindow) *QuotaWindow {
	if quota == nil {
		return nil
	}
	copy := *quota
	return &copy
}

func parseAgyReset(raw string) int64 {
	if raw == "" {
		return 0
	}
	if parsed, err := time.Parse(time.RFC3339Nano, raw); err == nil {
		return parsed.Unix()
	}
	if epoch, err := strconv.ParseInt(raw, 10, 64); err == nil {
		return epoch
	}
	return 0
}

func firstNonEmpty(values ...string) string {
	for _, value := range values {
		if strings.TrimSpace(value) != "" {
			return value
		}
	}
	return ""
}

func stopOwnedAgy(cmd *exec.Cmd, terminal *os.File) {
	if terminal != nil {
		_, _ = terminal.Write([]byte{3, 3})
		_ = terminal.Close()
	}
	if cmd == nil || cmd.Process == nil {
		return
	}
	pid := cmd.Process.Pid
	processGroup, err := syscall.Getpgid(pid)
	if err == nil {
		_ = syscall.Kill(-processGroup, syscall.SIGTERM)
	} else {
		_ = cmd.Process.Signal(syscall.SIGTERM)
	}
	done := make(chan struct{})
	go func() {
		_ = cmd.Wait()
		close(done)
	}()
	select {
	case <-done:
	case <-time.After(time.Second):
		if processGroup > 0 {
			_ = syscall.Kill(-processGroup, syscall.SIGKILL)
		} else {
			_ = cmd.Process.Kill()
		}
		select {
		case <-done:
		case <-time.After(time.Second):
		}
	}
}
