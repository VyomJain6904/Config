package metrics

import "testing"

func TestParseVolumePercent(t *testing.T) {
	got := parseVolumePercent("Volume: front-left: 49152 / 75% / -6.00 dB")
	if got != 75 {
		t.Fatalf("want 75, got %d", got)
	}
}

func TestParseVolumePercentFallback(t *testing.T) {
	got := parseVolumePercent("Volume unavailable")
	if got != 75 {
		t.Fatalf("want fallback 75, got %d", got)
	}
}

func TestParseWiFiEnabled(t *testing.T) {
	if !parseWiFiEnabled("enabled") {
		t.Fatal("expected enabled to be true")
	}
	if parseWiFiEnabled("disabled") {
		t.Fatal("expected disabled to be false")
	}
}
