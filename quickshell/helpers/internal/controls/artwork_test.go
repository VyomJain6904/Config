package controls

import (
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func TestArtworkTitleMatches(t *testing.T) {
	tests := []struct {
		mediaTitle   string
		artworkTitle string
		want         bool
	}{
		{"The Framework Pro 13 Made me Cry", "The Framework Pro 13 Made me Cry", true},
		{"The Framework Pro 13 Made me Cry", "the framework pro 13 made me cry", true},
		{"Network Ports Explained", "Network Ports Explained - YouTube", true},
		{"Short video", "Different video", false},
	}
	for _, test := range tests {
		if got := artworkTitleMatches(test.mediaTitle, test.artworkTitle); got != test.want {
			t.Fatalf("artworkTitleMatches(%q, %q) = %v, want %v", test.mediaTitle, test.artworkTitle, got, test.want)
		}
	}
}

func TestPlaceholderArtworkTitle(t *testing.T) {
	for _, value := range []string{"", "Media", "unknown", "Untitled", "No title", "A site is playing media"} {
		if !placeholderArtworkTitle(value) {
			t.Fatalf("expected placeholder artwork title: %q", value)
		}
	}
	for _, value := range []string{"Reuter I Turned Windows Into macOS", "Network Ports Explained"} {
		if placeholderArtworkTitle(value) {
			t.Fatalf("did not expect real artwork title to be a placeholder: %q", value)
		}
	}
}

func TestArtworkPageTitle(t *testing.T) {
	if got := artworkPageTitle("https://www.youtube.com/watch?v=abc"); got != "www.youtube.com — watch" {
		t.Fatalf("artworkPageTitle() = %q", got)
	}
	if got := artworkPageTitle("https://example.test/"); got != "example.test" {
		t.Fatalf("artworkPageTitle() = %q", got)
	}
}

func TestValidArtworkURL(t *testing.T) {
	if !validArtworkURL("https://cdn.example.test/image.jpg") {
		t.Fatal("expected HTTPS artwork URL to be accepted")
	}
	for _, value := range []string{
		"",
		"file:///tmp/image.jpg",
		"javascript:alert(1)",
		"https://",
	} {
		if validArtworkURL(value) {
			t.Fatalf("expected artwork URL to be rejected: %q", value)
		}
	}
}

func TestBrowserMediaPlayer(t *testing.T) {
	for _, player := range []string{"chromium.instance31748", "helium", "firefox.instance1", "brave"} {
		if !browserMediaPlayer(player) {
			t.Fatalf("expected browser player to be detected: %q", player)
		}
	}
	for _, player := range []string{"vlc", "mpv", "spotify", "clementine"} {
		if browserMediaPlayer(player) {
			t.Fatalf("expected local player not to be detected as browser: %q", player)
		}
	}
}

func TestHighQualityArtworkPathRejectsMissingFile(t *testing.T) {
	if highQualityArtworkPath(filepath.Join(t.TempDir(), "missing.jpg")) {
		t.Fatal("expected missing artwork to be rejected")
	}
}

func TestLocalMediaTitleUnescapesFileURL(t *testing.T) {
	directory := t.TempDir()
	path := filepath.Join(directory, "Some Video.mp4")
	if err := os.WriteFile(path, []byte("placeholder"), 0o600); err != nil {
		t.Fatal(err)
	}
	fileURL := "file://" + strings.ReplaceAll(path, " ", "%20")
	if got := localMediaTitle(fileURL); got != "Some Video" {
		t.Fatalf("localMediaTitle() = %q, want %q", got, "Some Video")
	}
}
