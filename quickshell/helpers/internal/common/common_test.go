package common

import (
	"os"
	"path/filepath"
	"testing"
)

func TestWriteJSONPermissions(t *testing.T) {
	t.Parallel()

	path := filepath.Join(t.TempDir(), "nested", "state.json")
	if err := WriteJSON(path, map[string]string{"value": "ok"}, 0o600); err != nil {
		t.Fatal(err)
	}
	info, err := os.Stat(path)
	if err != nil {
		t.Fatal(err)
	}
	if got := info.Mode().Perm(); got != 0o600 {
		t.Fatalf("mode = %o, want 600", got)
	}
}
