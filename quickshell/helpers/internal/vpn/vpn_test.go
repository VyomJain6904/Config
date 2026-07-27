package vpn

import "testing"

func TestWarpStatusConnected(t *testing.T) {
	for _, output := range []string{
		"Connected\n",
		"Status update: Connected\n",
		"Connected to WARP\n",
	} {
		if !warpStatusConnected(output) {
			t.Fatalf("warpStatusConnected(%q) = false", output)
		}
	}
}

func TestWarpStatusDisconnected(t *testing.T) {
	for _, output := range []string{
		"",
		"Status update: Disconnected\nReason: Manual Disconnection\n",
		"Unable to connect to CloudflareWARP daemon\n",
	} {
		if warpStatusConnected(output) {
			t.Fatalf("warpStatusConnected(%q) = true", output)
		}
	}
}

func TestFirstError(t *testing.T) {
	if code := firstError(0, 4); code != 4 {
		t.Fatalf("firstError(0, 4) = %d", code)
	}
	if code := firstError(3, 4); code != 3 {
		t.Fatalf("firstError(3, 4) = %d", code)
	}
}
