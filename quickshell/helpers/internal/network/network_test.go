package network

import (
	"reflect"
	"testing"
)

func TestSplitTerse(t *testing.T) {
	t.Parallel()

	got := splitTerse(`wifi:connected:Cafe\: Upstairs`)
	want := []string{"wifi", "connected", "Cafe: Upstairs"}
	if !reflect.DeepEqual(got, want) {
		t.Fatalf("splitTerse() = %#v, want %#v", got, want)
	}
}

func TestChannelBand(t *testing.T) {
	t.Parallel()

	tests := map[string]string{
		"":    "bg",
		"6":   "bg",
		"14":  "bg",
		"36":  "a",
		"149": "a",
	}
	for channel, want := range tests {
		if got := channelBand(channel); got != want {
			t.Errorf("channelBand(%q) = %q, want %q", channel, got, want)
		}
	}
}
