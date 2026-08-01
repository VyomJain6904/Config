package ai

import (
	"database/sql"
	"encoding/json"
	"os"
	"path/filepath"
	"sort"
	"strings"
	"time"
)

type openCodeMessage struct {
	Role       string  `json:"role"`
	ProviderID string  `json:"providerID"`
	ModelID    string  `json:"modelID"`
	Cost       float64 `json:"cost"`
	Tokens     struct {
		Input     int64 `json:"input"`
		Output    int64 `json:"output"`
		Reasoning int64 `json:"reasoning"`
		Cache     struct {
			Read  int64 `json:"read"`
			Write int64 `json:"write"`
		} `json:"cache"`
	} `json:"tokens"`
}

type openCodeModelKey struct{ provider, model string }

func collectOpenCode() PlatformUsage {
	result := emptyPlatform("opencode", "OpenCode", "OpenCode message database")
	result.Plan = "LOCAL + PROVIDERS"
	home, err := os.UserHomeDir()
	if err != nil {
		result.State = "unavailable"
		result.Error = err.Error()
		return result
	}
	dbPath := filepath.Join(home, ".local", "share", "opencode", "opencode.db")
	info, err := os.Stat(dbPath)
	if err != nil {
		result.State = "unavailable"
		result.Error = "OpenCode database not found"
		return result
	}
	result.UpdatedAt = info.ModTime().Unix()
	db, err := sql.Open("sqlite3", "file:"+dbPath+"?mode=ro&_mutex=no")
	if err != nil {
		result.State = "unavailable"
		result.Error = err.Error()
		return result
	}
	defer db.Close()

	cutoff := time.Now().AddDate(0, 0, -6)
	cutoff = time.Date(cutoff.Year(), cutoff.Month(), cutoff.Day(), 0, 0, 0, 0, cutoff.Location())
	rows, err := db.Query("SELECT session_id, time_created, data FROM message WHERE time_created >= ? ORDER BY time_created", cutoff.UnixMilli())
	if err != nil {
		result.State = "unavailable"
		result.Error = err.Error()
		return result
	}
	defer rows.Close()
	daily := map[string]int64{}
	models := map[openCodeModelKey]*ModelUsage{}
	sessions := map[string]bool{}
	for rows.Next() {
		var session string
		var created int64
		var raw []byte
		if rows.Scan(&session, &created, &raw) != nil {
			continue
		}
		message, ok := parseOpenCodeMessage(raw)
		if !ok {
			continue
		}
		active := message.Tokens.Input + message.Tokens.Output + message.Tokens.Reasoning
		date := time.UnixMilli(created).Local().Format("2006-01-02")
		daily[date] += active
		key := openCodeModelKey{message.ProviderID, message.ModelID}
		if models[key] == nil {
			models[key] = &ModelUsage{Provider: message.ProviderID, Model: displayModel(message.ModelID), Kind: providerKind(message.ProviderID)}
		}
		models[key].ActiveTokens += active
		models[key].CacheReadTokens += message.Tokens.Cache.Read
		models[key].Cost += message.Cost
		result.Summary.ActiveTokens += active
		result.Summary.CacheReadTokens += message.Tokens.Cache.Read
		result.Summary.Cost += message.Cost
		sessions[session] = true
	}
	if err := rows.Err(); err != nil {
		result.Error = err.Error()
	}
	result.Summary.Sessions = len(sessions)
	result.DailyUsage = sevenDays(daily)
	for key, configured := range configuredLocalModels(home) {
		if models[key] == nil {
			models[key] = &ModelUsage{Provider: key.provider, Model: configured, Kind: "local"}
		}
	}
	for _, model := range models {
		result.Models = append(result.Models, *model)
	}
	sort.Slice(result.Models, func(i, j int) bool {
		if result.Models[i].ActiveTokens == result.Models[j].ActiveTokens {
			return result.Models[i].Model < result.Models[j].Model
		}
		return result.Models[i].ActiveTokens > result.Models[j].ActiveTokens
	})
	result.State = "live"
	return result
}

func configuredLocalModels(home string) map[openCodeModelKey]string {
	result := map[openCodeModelKey]string{}
	data, err := os.ReadFile(filepath.Join(home, ".config", "opencode", "opencode.json"))
	if err != nil {
		return result
	}
	var config struct {
		Providers map[string]struct {
			Models map[string]struct {
				Name string `json:"name"`
			} `json:"models"`
		} `json:"provider"`
	}
	if json.Unmarshal(data, &config) != nil {
		return result
	}
	for provider, definition := range config.Providers {
		if providerKind(provider) != "local" {
			continue
		}
		for model, details := range definition.Models {
			name := details.Name
			if name == "" {
				name = displayModel(model)
			}
			result[openCodeModelKey{provider, model}] = name
		}
	}
	return result
}

func parseOpenCodeMessage(raw []byte) (openCodeMessage, bool) {
	var message openCodeMessage
	if json.Unmarshal(raw, &message) != nil || message.Role != "assistant" || message.ModelID == "" {
		return message, false
	}
	return message, true
}

func providerKind(provider string) string {
	lower := strings.ToLower(provider)
	if lower == "ollama" || strings.Contains(lower, "local") || strings.Contains(lower, "lmstudio") {
		return "local"
	}
	if lower == "opencode" {
		return "hosted"
	}
	return "external"
}
