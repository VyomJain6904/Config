package ai

import (
	"bufio"
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"os"
	"os/exec"
	"path/filepath"
	"sort"
	"strings"
	"time"
)

type codexFileCursor struct {
	Offset int64  `json:"offset"`
	Model  string `json:"model"`
}

type codexLocalState struct {
	Files      map[string]codexFileCursor  `json:"files"`
	Daily      map[string]int64            `json:"daily"`
	ModelDaily map[string]map[string]int64 `json:"modelDaily"`
	Quota      []QuotaWindow               `json:"quota"`
}

type codexRemoteState struct {
	UpdatedAt int64            `json:"updatedAt"`
	Plan      string           `json:"plan"`
	Quota     []QuotaWindow    `json:"quota"`
	Daily     map[string]int64 `json:"daily"`
	Summary   UsageSummary     `json:"summary"`
}

type appRateWindow struct {
	UsedPercent       float64 `json:"usedPercent"`
	WindowDurationMin int64   `json:"windowDurationMins"`
	ResetsAt          int64   `json:"resetsAt"`
}

type appRateLimits struct {
	PlanType  string         `json:"planType"`
	Primary   *appRateWindow `json:"primary"`
	Secondary *appRateWindow `json:"secondary"`
}

type appUsage struct {
	Summary struct {
		LifetimeTokens  int64 `json:"lifetimeTokens"`
		PeakDailyTokens int64 `json:"peakDailyTokens"`
	} `json:"summary"`
	Daily []struct {
		Date   string `json:"startDate"`
		Tokens int64  `json:"tokens"`
	} `json:"dailyUsageBuckets"`
}

func codexCachePath(name string) string {
	dir, err := os.UserCacheDir()
	if err != nil {
		return ""
	}
	return filepath.Join(dir, "quickshell", name)
}

func loadJSON(path string, value any) {
	data, err := os.ReadFile(path)
	if err == nil {
		_ = json.Unmarshal(data, value)
	}
}

func saveJSON(path string, value any) {
	if path == "" || os.MkdirAll(filepath.Dir(path), 0700) != nil {
		return
	}
	data, err := json.Marshal(value)
	if err != nil {
		return
	}
	tmp := path + ".tmp"
	if os.WriteFile(tmp, data, 0600) == nil {
		_ = os.Rename(tmp, path)
	}
}

func collectCodex(ctx context.Context, mode remoteMode) PlatformUsage {
	result := emptyPlatform("codex", "Codex", "Codex app-server + local rollouts")
	result.Plan = "SIGNED IN"

	local, err := collectCodexRollouts()
	if err != nil {
		result.Error = err.Error()
	}
	remote := codexRemoteState{Daily: map[string]int64{}, Quota: []QuotaWindow{}}
	remotePath := codexCachePath("ai-codex-remote-v1.json")
	loadJSON(remotePath, &remote)
	if remote.Daily == nil {
		remote.Daily = map[string]int64{}
	}
	for index := range remote.Quota {
		remote.Quota[index].PercentKnown = true
	}

	if mode != remoteNone {
		rates, usage, fetchErr := queryCodexAppServer(ctx, mode == remoteFull)
		if fetchErr == nil {
			remote.UpdatedAt = time.Now().Unix()
			remote.Plan = strings.ToUpper(rates.PlanType)
			remote.Quota = quotaFromAppServer(rates)
			if mode == remoteFull && usage != nil {
				remote.Daily = map[string]int64{}
				for _, bucket := range usage.Daily {
					remote.Daily[bucket.Date] = bucket.Tokens
				}
				remote.Summary.LifetimeTokens = usage.Summary.LifetimeTokens
				remote.Summary.PeakDailyTokens = usage.Summary.PeakDailyTokens
			}
			saveJSON(remotePath, remote)
		} else if result.Error == "" {
			result.Error = "Live quota unavailable; showing last verified data"
		}
	}

	counts := map[string]int64{}
	for date, tokens := range local.Daily {
		counts[date] = tokens
	}
	for date, tokens := range remote.Daily {
		counts[date] = tokens
	}
	result.DailyUsage = sevenDays(counts)
	result.QuotaWindows = remote.Quota
	if len(result.QuotaWindows) == 0 {
		result.QuotaWindows = local.Quota
	}
	if remote.Plan != "" {
		result.Plan = remote.Plan
	}
	if remote.UpdatedAt > 0 {
		result.UpdatedAt = remote.UpdatedAt
		if time.Since(time.Unix(remote.UpdatedAt, 0)) <= 2*time.Minute {
			result.State = "live"
		} else {
			result.State = "cached"
		}
	}
	result.Summary = remote.Summary

	modelTotals := map[string]int64{}
	for _, models := range local.ModelDaily {
		for model, tokens := range models {
			modelTotals[model] += tokens
			result.Summary.ActiveTokens += tokens
		}
	}
	for model, tokens := range modelTotals {
		result.Models = append(result.Models, ModelUsage{Provider: "openai", Model: displayModel(model), Kind: "hosted", ActiveTokens: tokens})
	}
	sort.Slice(result.Models, func(i, j int) bool {
		if result.Models[i].ActiveTokens == result.Models[j].ActiveTokens {
			return result.Models[i].Model < result.Models[j].Model
		}
		return result.Models[i].ActiveTokens > result.Models[j].ActiveTokens
	})
	return result
}

func collectCodexRollouts() (codexLocalState, error) {
	state := codexLocalState{Files: map[string]codexFileCursor{}, Daily: map[string]int64{}, ModelDaily: map[string]map[string]int64{}, Quota: []QuotaWindow{}}
	path := codexCachePath("ai-codex-local-v1.json")
	loadJSON(path, &state)
	if state.Files == nil {
		state.Files = map[string]codexFileCursor{}
	}
	if state.Daily == nil {
		state.Daily = map[string]int64{}
	}
	if state.ModelDaily == nil {
		state.ModelDaily = map[string]map[string]int64{}
	}

	home, err := os.UserHomeDir()
	if err != nil {
		return state, err
	}
	validDates := map[string]bool{}
	paths := []string{}
	for ago := 6; ago >= 0; ago-- {
		day := time.Now().AddDate(0, 0, -ago)
		date := day.Format("2006-01-02")
		validDates[date] = true
		matches, _ := filepath.Glob(filepath.Join(home, ".codex", "sessions", day.Format("2006"), day.Format("01"), day.Format("02"), "*.jsonl"))
		paths = append(paths, matches...)
	}
	for date := range state.Daily {
		if !validDates[date] {
			delete(state.Daily, date)
		}
	}
	for date := range state.ModelDaily {
		if !validDates[date] {
			delete(state.ModelDaily, date)
		}
	}

	for _, rollout := range paths {
		cursor := state.Files[rollout]
		info, statErr := os.Stat(rollout)
		if statErr != nil {
			continue
		}
		if info.Size() < cursor.Offset {
			// A rewritten rollout is rare; discard the whole incremental cache so no usage is double-counted.
			state = codexLocalState{Files: map[string]codexFileCursor{}, Daily: map[string]int64{}, ModelDaily: map[string]map[string]int64{}, Quota: []QuotaWindow{}}
			return rebuildCodexRollouts(paths, state, path)
		}
		if err := scanCodexRollout(rollout, &cursor, &state); err != nil {
			continue
		}
		state.Files[rollout] = cursor
	}
	for tracked := range state.Files {
		if _, err := os.Stat(tracked); err != nil {
			delete(state.Files, tracked)
		}
	}
	saveJSON(path, state)
	return state, nil
}

func rebuildCodexRollouts(paths []string, state codexLocalState, cache string) (codexLocalState, error) {
	for _, rollout := range paths {
		cursor := codexFileCursor{}
		_ = scanCodexRollout(rollout, &cursor, &state)
		state.Files[rollout] = cursor
	}
	saveJSON(cache, state)
	return state, nil
}

func scanCodexRollout(path string, cursor *codexFileCursor, state *codexLocalState) error {
	file, err := os.Open(path)
	if err != nil {
		return err
	}
	defer file.Close()
	if _, err = file.Seek(cursor.Offset, io.SeekStart); err != nil {
		return err
	}
	scanner := bufio.NewScanner(file)
	scanner.Buffer(make([]byte, 64*1024), 8*1024*1024)
	for scanner.Scan() {
		var event struct {
			Timestamp string `json:"timestamp"`
			Type      string `json:"type"`
			Payload   struct {
				Type  string `json:"type"`
				Model string `json:"model"`
				Info  *struct {
					Last *struct {
						Total int64 `json:"total_tokens"`
					} `json:"last_token_usage"`
				} `json:"info"`
				RateLimits *struct {
					Primary *struct {
						Used     float64 `json:"used_percent"`
						Duration int64   `json:"window_minutes"`
						Reset    int64   `json:"resets_at"`
					} `json:"primary"`
					Secondary *struct {
						Used     float64 `json:"used_percent"`
						Duration int64   `json:"window_minutes"`
						Reset    int64   `json:"resets_at"`
					} `json:"secondary"`
				} `json:"rate_limits"`
			} `json:"payload"`
		}
		if json.Unmarshal(scanner.Bytes(), &event) != nil {
			continue
		}
		if event.Type == "turn_context" && event.Payload.Model != "" {
			cursor.Model = event.Payload.Model
		}
		if event.Type != "event_msg" || event.Payload.Type != "token_count" {
			continue
		}
		if event.Payload.RateLimits != nil {
			state.Quota = embeddedQuota(event.Payload.RateLimits.Primary, event.Payload.RateLimits.Secondary)
		}
		if event.Payload.Info == nil || event.Payload.Info.Last == nil || event.Payload.Info.Last.Total <= 0 {
			continue
		}
		at, parseErr := time.Parse(time.RFC3339Nano, event.Timestamp)
		if parseErr != nil {
			continue
		}
		date := at.Local().Format("2006-01-02")
		model := cursor.Model
		if model == "" {
			model = "codex"
		}
		tokens := event.Payload.Info.Last.Total
		state.Daily[date] += tokens
		if state.ModelDaily[date] == nil {
			state.ModelDaily[date] = map[string]int64{}
		}
		state.ModelDaily[date][model] += tokens
	}
	offset, _ := file.Seek(0, io.SeekCurrent)
	cursor.Offset = offset
	return scanner.Err()
}

func embeddedQuota(primary, secondary *struct {
	Used     float64 `json:"used_percent"`
	Duration int64   `json:"window_minutes"`
	Reset    int64   `json:"resets_at"`
}) []QuotaWindow {
	result := []QuotaWindow{}
	if primary != nil {
		result = append(result, QuotaWindow{ID: "primary", Label: quotaLabel(primary.Duration), PercentKnown: true, UsedPercent: primary.Used, RemainingPercent: 100 - primary.Used, ResetAt: primary.Reset, DurationMinutes: primary.Duration})
	}
	if secondary != nil {
		result = append(result, QuotaWindow{ID: "secondary", Label: quotaLabel(secondary.Duration), PercentKnown: true, UsedPercent: secondary.Used, RemainingPercent: 100 - secondary.Used, ResetAt: secondary.Reset, DurationMinutes: secondary.Duration})
	}
	return result
}

func quotaFromAppServer(limits appRateLimits) []QuotaWindow {
	result := []QuotaWindow{}
	add := func(id string, window *appRateWindow) {
		if window == nil {
			return
		}
		result = append(result, QuotaWindow{ID: id, Label: quotaLabel(window.WindowDurationMin), PercentKnown: true, UsedPercent: window.UsedPercent, RemainingPercent: 100 - window.UsedPercent, ResetAt: window.ResetsAt, DurationMinutes: window.WindowDurationMin})
	}
	add("primary", limits.Primary)
	add("secondary", limits.Secondary)
	return result
}

func quotaLabel(minutes int64) string {
	if minutes == 10080 {
		return "Weekly"
	}
	if minutes%60 == 0 && minutes > 0 {
		return fmt.Sprintf("%d hour", minutes/60)
	}
	return "Usage window"
}

func queryCodexAppServer(ctx context.Context, includeUsage bool) (appRateLimits, *appUsage, error) {
	var limits appRateLimits
	command, err := exec.LookPath("codex")
	if err != nil {
		home, _ := os.UserHomeDir()
		fallback := filepath.Join(home, ".local", "share", "mise", "shims", "codex")
		if info, statErr := os.Stat(fallback); statErr != nil || info.Mode()&0111 == 0 {
			return limits, nil, errors.New("Codex CLI not found")
		}
		command = fallback
	}
	cmd := exec.CommandContext(ctx, command, "app-server", "--listen", "stdio://")
	stdin, err := cmd.StdinPipe()
	if err != nil {
		return limits, nil, err
	}
	stdout, err := cmd.StdoutPipe()
	if err != nil {
		return limits, nil, err
	}
	cmd.Stderr = io.Discard
	if err = cmd.Start(); err != nil {
		return limits, nil, err
	}
	defer func() {
		_ = stdin.Close()
		if cmd.Process != nil {
			_ = cmd.Process.Kill()
		}
		_ = cmd.Wait()
	}()
	encoder := json.NewEncoder(stdin)
	_ = encoder.Encode(map[string]any{"jsonrpc": "2.0", "id": 1, "method": "initialize", "params": map[string]any{"clientInfo": map[string]string{"name": "quickshell", "title": "Quickshell AI usage", "version": "1"}, "capabilities": map[string]bool{"experimentalApi": true}}})
	_ = encoder.Encode(map[string]any{"jsonrpc": "2.0", "method": "initialized"})
	_ = encoder.Encode(map[string]any{"jsonrpc": "2.0", "id": 2, "method": "account/rateLimits/read"})
	if includeUsage {
		_ = encoder.Encode(map[string]any{"jsonrpc": "2.0", "id": 3, "method": "account/usage/read"})
	}

	gotRates, gotUsage := false, !includeUsage
	var usage *appUsage
	scanner := bufio.NewScanner(stdout)
	scanner.Buffer(make([]byte, 64*1024), 4*1024*1024)
	for scanner.Scan() {
		var response struct {
			ID     int             `json:"id"`
			Error  any             `json:"error"`
			Result json.RawMessage `json:"result"`
		}
		if json.Unmarshal(scanner.Bytes(), &response) != nil || response.ID == 0 {
			continue
		}
		if response.Error != nil {
			return limits, usage, fmt.Errorf("Codex app-server request %d failed", response.ID)
		}
		switch response.ID {
		case 2:
			var envelope struct {
				RateLimits appRateLimits `json:"rateLimits"`
			}
			if json.Unmarshal(response.Result, &envelope) == nil {
				limits = envelope.RateLimits
				gotRates = true
			}
		case 3:
			var parsed appUsage
			if json.Unmarshal(response.Result, &parsed) == nil {
				usage = &parsed
				gotUsage = true
			}
		}
		if gotRates && gotUsage {
			return limits, usage, nil
		}
	}
	if err := scanner.Err(); err != nil {
		return limits, usage, err
	}
	return limits, usage, errors.New("Codex app-server returned an incomplete response")
}

func displayModel(raw string) string {
	name := strings.TrimPrefix(strings.TrimPrefix(raw, "openai/"), "ollama/")
	parts := strings.FieldsFunc(name, func(r rune) bool { return r == '-' || r == '_' })
	for i, part := range parts {
		if len(part) > 0 {
			parts[i] = strings.ToUpper(part[:1]) + part[1:]
		}
	}
	if len(parts) > 0 && strings.EqualFold(parts[0], "gpt") {
		parts[0] = "GPT"
	}
	return strings.Join(parts, " ")
}
