package ai

import "time"

const schemaVersion = 2

type Snapshot struct {
	SchemaVersion int             `json:"schemaVersion"`
	GeneratedAt   int64           `json:"generatedAt"`
	Platforms     []PlatformUsage `json:"platforms"`
}

type PlatformUsage struct {
	ID           string        `json:"id"`
	Name         string        `json:"name"`
	Plan         string        `json:"plan"`
	State        string        `json:"state"`
	Source       string        `json:"source"`
	UpdatedAt    int64         `json:"updatedAt"`
	Error        string        `json:"error,omitempty"`
	QuotaWindows []QuotaWindow `json:"quotaWindows"`
	DailyUsage   []DailyUsage  `json:"dailyUsage"`
	Models       []ModelUsage  `json:"models"`
	Summary      UsageSummary  `json:"summary"`
}

type QuotaWindow struct {
	ID               string  `json:"id"`
	Label            string  `json:"label"`
	PercentKnown     bool    `json:"percentKnown"`
	UsedPercent      float64 `json:"usedPercent"`
	RemainingPercent float64 `json:"remainingPercent"`
	ResetAt          int64   `json:"resetAt"`
	DurationMinutes  int64   `json:"durationMinutes"`
}

type DailyUsage struct {
	Date   string `json:"date"`
	Label  string `json:"label"`
	Tokens int64  `json:"tokens"`
}

type ModelUsage struct {
	Provider        string       `json:"provider"`
	Model           string       `json:"model"`
	Kind            string       `json:"kind"`
	ActiveTokens    int64        `json:"activeTokens"`
	CacheReadTokens int64        `json:"cacheReadTokens"`
	Cost            float64      `json:"cost"`
	Quota           *QuotaWindow `json:"quota,omitempty"`
}

type UsageSummary struct {
	ActiveTokens    int64   `json:"activeTokens"`
	CacheReadTokens int64   `json:"cacheReadTokens"`
	LifetimeTokens  int64   `json:"lifetimeTokens"`
	PeakDailyTokens int64   `json:"peakDailyTokens"`
	Cost            float64 `json:"cost"`
	Sessions        int     `json:"sessions"`
}

func emptyPlatform(id, name, source string) PlatformUsage {
	return PlatformUsage{
		ID: id, Name: name, Plan: "", State: "local", Source: source,
		UpdatedAt: time.Now().Unix(), QuotaWindows: []QuotaWindow{},
		DailyUsage: []DailyUsage{}, Models: []ModelUsage{},
	}
}

func sevenDays(counts map[string]int64) []DailyUsage {
	now := time.Now()
	result := make([]DailyUsage, 0, 7)
	for ago := 6; ago >= 0; ago-- {
		day := now.AddDate(0, 0, -ago)
		label := day.Format("Mon")
		if ago == 0 {
			label = "Today"
		}
		date := day.Format("2006-01-02")
		result = append(result, DailyUsage{Date: date, Label: label, Tokens: counts[date]})
	}
	return result
}
