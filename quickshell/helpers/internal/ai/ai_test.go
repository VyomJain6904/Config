package ai

import (
	"encoding/base64"
	"encoding/binary"
	"encoding/json"
	"math"
	"testing"
)

func protoVarint(field int, value uint64) []byte {
	result := appendVarint(nil, uint64(field<<3))
	return appendVarint(result, value)
}

func protoBytes(field int, value []byte) []byte {
	result := appendVarint(nil, uint64(field<<3|2))
	result = appendVarint(result, uint64(len(value)))
	return append(result, value...)
}

func protoFloat(field int, value float32) []byte {
	result := appendVarint(nil, uint64(field<<3|5))
	bits := make([]byte, 4)
	binary.LittleEndian.PutUint32(bits, math.Float32bits(value))
	return append(result, bits...)
}

func appendVarint(dst []byte, value uint64) []byte {
	for value >= 0x80 {
		dst = append(dst, byte(value)|0x80)
		value >>= 7
	}
	return append(dst, byte(value))
}

func TestAntigravityQuotaDecode(t *testing.T) {
	timestamp := protoVarint(1, 1_800_000_000)
	quota := append(protoFloat(1, 0.375), protoBytes(2, timestamp)...)
	model := append(protoBytes(1, []byte("Gemini 3 Pro")), protoBytes(15, quota)...)
	status := protoBytes(33, protoBytes(1, model))
	wrapper := protoBytes(1, []byte(base64.StdEncoding.EncodeToString(status)))
	outer := base64.StdEncoding.EncodeToString(protoBytes(2, wrapper))
	decoded, err := findUserStatus([]byte(outer))
	if err != nil {
		t.Fatal(err)
	}
	fields, err := parseProto(decoded)
	if err != nil || len(fields) != 1 {
		t.Fatalf("unexpected fields: %#v, %v", fields, err)
	}
	models := antigravityModels(fields[0].bytes)
	if len(models) != 1 {
		t.Fatal("model was not decoded")
	}
	usage := models[0]
	if usage.Model != "Gemini 3 Pro" {
		t.Fatalf("model = %q", usage.Model)
	}
	if usage.Quota.ResetAt != 1_800_000_000 || math.Abs(usage.Quota.RemainingPercent-37.5) > 0.01 {
		t.Fatalf("quota = %#v", usage.Quota)
	}
	if !usage.Quota.PercentKnown {
		t.Fatal("percentage should be marked known")
	}
}

func TestAntigravityModelWithoutPublishedPercent(t *testing.T) {
	timestamp := protoVarint(1, 1_800_000_000)
	quota := protoBytes(2, timestamp)
	model := append(protoBytes(1, []byte("claude-sonnet-4.6-thinking")), protoBytes(15, quota)...)
	usage, ok := antigravityModel(model)
	if !ok {
		t.Fatal("reset-only model was omitted")
	}
	if usage.Quota.PercentKnown || usage.Quota.ResetAt != 1_800_000_000 {
		t.Fatalf("quota = %#v", usage.Quota)
	}
}

func TestAntigravityCLIMapsSharedBindingQuotaAndModelOrder(t *testing.T) {
	var summary agyQuotaSummaryResponse
	if err := json.Unmarshal([]byte(`{"response":{"groups":[{"displayName":"Gemini Models","buckets":[{"bucketId":"gemini-weekly","displayName":"Weekly Limit","window":"weekly","remainingFraction":0.55,"resetTime":"2026-08-06T11:03:52Z"},{"bucketId":"gemini-5h","displayName":"Five Hour Limit","window":"5h","remainingFraction":0.20,"resetTime":"2026-08-01T20:00:00Z"}]},{"displayName":"Claude and GPT models","buckets":[{"bucketId":"3p-weekly","displayName":"Weekly Limit","window":"weekly","remainingFraction":0,"resetTime":"2026-08-02T15:38:42Z"},{"bucketId":"3p-5h","displayName":"Five Hour Limit","window":"5h","remainingFraction":1,"disabled":true}]}]}}`), &summary); err != nil {
		t.Fatal(err)
	}
	var status agyUserStatusResponse
	if err := json.Unmarshal([]byte(`{"userStatus":{"userTier":{"name":"Google AI Pro"},"cascadeModelConfigData":{"clientModelConfigs":[{"label":"Claude Sonnet 4.6 (Thinking)","modelId":"claude-sonnet-4-6"},{"label":"Gemini 3.6 Flash (High)","modelId":"gemini-3.6-flash-high"}],"clientModelSorts":[{"groups":[{"modelLabels":["Gemini 3.6 Flash (High)","Claude Sonnet 4.6 (Thinking)"]}]}]}}}`), &status); err != nil {
		t.Fatal(err)
	}

	result, err := antigravityFromCLI(summary, status)
	if err != nil {
		t.Fatal(err)
	}
	if result.Source != antigravityCLISource || result.Plan != "GOOGLE AI PRO" || result.State != "live" {
		t.Fatalf("unexpected platform metadata: %#v", result)
	}
	if len(result.Models) != 2 || result.Models[0].Model != "Gemini 3.6 Flash (High)" {
		t.Fatalf("model order = %#v", result.Models)
	}
	gemini := result.Models[0].Quota
	if gemini == nil || gemini.Label != "5-hour · Shared Gemini" || math.Abs(gemini.RemainingPercent-20) > 0.01 {
		t.Fatalf("Gemini quota = %#v", gemini)
	}
	thirdParty := result.Models[1].Quota
	if thirdParty == nil || thirdParty.Label != "Weekly · Shared Claude + GPT" || thirdParty.RemainingPercent != 0 {
		t.Fatalf("Claude quota = %#v", thirdParty)
	}
	if len(result.QuotaWindows) != 0 {
		t.Fatalf("shared quota should not be duplicated above model cards: %#v", result.QuotaWindows)
	}
}

func TestAntigravityCLIPortParsing(t *testing.T) {
	output := []byte("agy 100 user 11u IPv4 1 0t0 TCP 127.0.0.1:32969 (LISTEN)\n" +
		"agy 100 user 13u IPv4 1 0t0 TCP 127.0.0.1:40443 (LISTEN)\n" +
		"agy 100 user 14u IPv4 1 0t0 TCP 127.0.0.1:32969 (LISTEN)\n")
	ports := parseAgyListeningPorts(output)
	if len(ports) != 2 || ports[0] != 32969 || ports[1] != 40443 {
		t.Fatalf("ports = %#v", ports)
	}
}

func TestOpenCodeAssistantMessage(t *testing.T) {
	raw := []byte(`{"role":"assistant","providerID":"ollama","modelID":"qwen3:8b-16k","cost":0,"tokens":{"input":120,"output":30,"reasoning":5,"cache":{"read":400,"write":0}}}`)
	message, ok := parseOpenCodeMessage(raw)
	if !ok {
		t.Fatal("assistant message was rejected")
	}
	if message.Tokens.Input+message.Tokens.Output+message.Tokens.Reasoning != 155 {
		t.Fatal("active token total is wrong")
	}
	if message.Tokens.Cache.Read != 400 || providerKind(message.ProviderID) != "local" {
		t.Fatal("cache/local classification is wrong")
	}
}

func TestSevenDaysEndsToday(t *testing.T) {
	days := sevenDays(map[string]int64{})
	if len(days) != 7 || days[6].Label != "Today" {
		t.Fatalf("unexpected days: %#v", days)
	}
}
