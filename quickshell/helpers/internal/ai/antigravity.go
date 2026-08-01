package ai

import (
	"database/sql"
	"encoding/base64"
	"encoding/binary"
	"errors"
	"math"
	"os"
	"path/filepath"
	"strings"
	"time"

	_ "github.com/mattn/go-sqlite3"
)

type protoField struct {
	number int
	wire   int
	value  uint64
	bytes  []byte
}

func collectAntigravityIDE() PlatformUsage {
	result := emptyPlatform("antigravity", "Antigravity", "Antigravity IDE account state")
	result.Plan = "SIGNED IN"
	home, err := os.UserHomeDir()
	if err != nil {
		result.State = "unavailable"
		result.Error = err.Error()
		return result
	}
	dbPath := filepath.Join(home, ".config", "Antigravity IDE", "User", "globalStorage", "state.vscdb")
	info, statErr := os.Stat(dbPath)
	if statErr != nil {
		result.State = "unavailable"
		result.Error = "Antigravity account state not found"
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
	var encoded []byte
	if err = db.QueryRow("SELECT value FROM ItemTable WHERE key = ?", "antigravityUnifiedStateSync.userStatus").Scan(&encoded); err != nil {
		result.State = "unavailable"
		result.Error = "Antigravity quota state is unavailable"
		return result
	}
	status, err := findUserStatus(encoded)
	if err != nil {
		result.State = "unavailable"
		result.Error = err.Error()
		return result
	}
	fields, _ := parseProto(status)
	models := map[string]ModelUsage{}
	for _, field := range fields {
		switch field.number {
		case 33:
			for _, model := range antigravityModels(field.bytes) {
				models[model.Model] = model
			}
		case 36:
			if plan := antigravityPlan(field.bytes); plan != "" {
				result.Plan = strings.ToUpper(plan)
			}
		}
	}
	for _, model := range models {
		result.Models = append(result.Models, model)
	}
	if len(result.Models) == 0 {
		result.State = "unavailable"
		result.Error = "No model quota records were published by Antigravity"
	} else if time.Since(info.ModTime()) > 5*time.Minute {
		result.State = "cached"
	} else {
		result.State = "live"
	}
	return result
}

func antigravityModels(data []byte) []ModelUsage {
	result := []ModelUsage{}
	fields, err := parseProto(data)
	if err != nil {
		return result
	}
	for _, field := range fields {
		if field.number != 1 || field.wire != 2 {
			continue
		}
		if model, ok := antigravityModel(field.bytes); ok {
			result = append(result, model)
		}
	}
	// Compatibility with states that publish a model directly in field 33.
	if len(result) == 0 {
		if model, ok := antigravityModel(data); ok {
			result = append(result, model)
		}
	}
	return result
}

func antigravityModel(data []byte) (ModelUsage, bool) {
	fields, err := parseProto(data)
	if err != nil {
		return ModelUsage{}, false
	}
	var name string
	var quota *QuotaWindow
	for _, field := range fields {
		if field.number == 1 && field.wire == 2 && printable(field.bytes) {
			name = string(field.bytes)
		}
		if field.number == 15 && field.wire == 2 {
			quota = antigravityQuota(field.bytes)
		}
	}
	if name == "" || quota == nil {
		return ModelUsage{}, false
	}
	return ModelUsage{Provider: "google", Model: name, Kind: "hosted", Quota: quota}, true
}

func antigravityQuota(data []byte) *QuotaWindow {
	fields, err := parseProto(data)
	if err != nil {
		return nil
	}
	remaining := float64(0)
	percentKnown := false
	reset := int64(0)
	for _, field := range fields {
		if field.number == 1 && field.wire == 5 {
			remaining = float64(math.Float32frombits(uint32(field.value))) * 100
			percentKnown = true
		}
		if field.number == 2 && field.wire == 2 {
			timestamp, _ := parseProto(field.bytes)
			for _, part := range timestamp {
				if part.number == 1 && part.wire == 0 {
					reset = int64(part.value)
				}
			}
		}
	}
	if percentKnown && (math.IsNaN(remaining) || math.IsInf(remaining, 0)) {
		return nil
	}
	if remaining < 0 {
		remaining = 0
	}
	if remaining > 100 {
		remaining = 100
	}
	if !percentKnown && reset == 0 {
		return nil
	}
	used := float64(0)
	if percentKnown {
		used = 100 - remaining
	}
	return &QuotaWindow{ID: "model", Label: "Model allowance", PercentKnown: percentKnown, UsedPercent: used, RemainingPercent: remaining, ResetAt: reset}
}

func antigravityPlan(data []byte) string {
	fields, _ := parseProto(data)
	for _, wanted := range []int{2, 3, 1} {
		for _, field := range fields {
			if field.number == wanted && field.wire == 2 && printable(field.bytes) {
				return string(field.bytes)
			}
		}
	}
	return ""
}

func findUserStatus(initial []byte) ([]byte, error) {
	queue := [][]byte{initial}
	seen := map[string]bool{}
	for depth := 0; depth < 8 && len(queue) > 0; depth++ {
		next := [][]byte{}
		for _, candidate := range queue {
			key := string(candidate)
			if seen[key] {
				continue
			}
			seen[key] = true
			trimmed := strings.Trim(strings.TrimSpace(string(candidate)), "\"")
			for _, encoding := range []*base64.Encoding{base64.StdEncoding, base64.RawStdEncoding} {
				if decoded, err := encoding.DecodeString(trimmed); err == nil && len(decoded) > 0 {
					next = append(next, decoded)
				}
			}
			fields, err := parseProto(candidate)
			if err != nil {
				continue
			}
			for _, field := range fields {
				if field.number == 33 {
					return candidate, nil
				}
				if field.wire == 2 && len(field.bytes) > 0 {
					next = append(next, field.bytes)
				}
			}
		}
		queue = next
	}
	return nil, errors.New("Could not decode Antigravity user quota state")
}

func parseProto(data []byte) ([]protoField, error) {
	fields := []protoField{}
	for index := 0; index < len(data); {
		key, used := readVarint(data[index:])
		if used == 0 {
			return nil, errors.New("invalid protobuf key")
		}
		index += used
		number, wire := int(key>>3), int(key&7)
		if number == 0 {
			return nil, errors.New("invalid protobuf field")
		}
		field := protoField{number: number, wire: wire}
		switch wire {
		case 0:
			value, n := readVarint(data[index:])
			if n == 0 {
				return nil, errors.New("invalid protobuf varint")
			}
			index += n
			field.value = value
		case 1:
			if index+8 > len(data) {
				return nil, errors.New("invalid protobuf fixed64")
			}
			field.value = binary.LittleEndian.Uint64(data[index : index+8])
			index += 8
		case 2:
			length, n := readVarint(data[index:])
			if n == 0 {
				return nil, errors.New("invalid protobuf length")
			}
			index += n
			if length > uint64(len(data)-index) {
				return nil, errors.New("invalid protobuf payload")
			}
			field.bytes = data[index : index+int(length)]
			index += int(length)
		case 5:
			if index+4 > len(data) {
				return nil, errors.New("invalid protobuf fixed32")
			}
			field.value = uint64(binary.LittleEndian.Uint32(data[index : index+4]))
			index += 4
		default:
			return nil, errors.New("unsupported protobuf wire type")
		}
		fields = append(fields, field)
	}
	return fields, nil
}

func readVarint(data []byte) (uint64, int) {
	var value uint64
	for i, b := range data {
		if i == 10 {
			return 0, 0
		}
		value |= uint64(b&0x7f) << (7 * i)
		if b < 0x80 {
			return value, i + 1
		}
	}
	return 0, 0
}

func printable(data []byte) bool {
	if len(data) == 0 {
		return false
	}
	for _, b := range data {
		if b < 0x20 || b > 0x7e {
			return false
		}
	}
	return true
}
