package ai

import (
	"bufio"
	"context"
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"sync"
	"time"

	"golang.org/x/sys/unix"
)

type remoteMode int

const (
	remoteNone remoteMode = iota
	remoteRates
	remoteFull
)

func Run(args []string) int {
	action := "usage"
	if len(args) > 0 {
		action = args[0]
	}
	switch action {
	case "usage":
		ctx, cancel := context.WithTimeout(context.Background(), 20*time.Second)
		defer cancel()
		emit(collectSnapshot(ctx, remoteFull))
		return 0
	case "watch":
		return watch()
	default:
		fmt.Fprintf(os.Stderr, "unknown ai action: %s\n", action)
		return 2
	}
}

func collectSnapshot(ctx context.Context, mode remoteMode) Snapshot {
	platforms := make([]PlatformUsage, 3)
	var wg sync.WaitGroup
	wg.Add(3)
	go func() { defer wg.Done(); platforms[0] = collectCodex(ctx, mode) }()
	go func() { defer wg.Done(); platforms[1] = collectAntigravity(ctx, mode) }()
	go func() { defer wg.Done(); platforms[2] = collectOpenCode() }()
	wg.Wait()
	return Snapshot{SchemaVersion: schemaVersion, GeneratedAt: time.Now().Unix(), Platforms: platforms}
}

func emit(snapshot Snapshot) {
	data, err := json.Marshal(snapshot)
	if err == nil {
		fmt.Println(string(data))
	}
}

func cachePath() string {
	dir, err := os.UserCacheDir()
	if err != nil {
		return ""
	}
	return filepath.Join(dir, "quickshell", "ai-usage-v1.json")
}

func readSnapshotCache() (Snapshot, bool) {
	var snapshot Snapshot
	data, err := os.ReadFile(cachePath())
	if err != nil || json.Unmarshal(data, &snapshot) != nil || snapshot.SchemaVersion != schemaVersion {
		return snapshot, false
	}
	return snapshot, true
}

func writeSnapshotCache(snapshot Snapshot) {
	path := cachePath()
	if path == "" {
		return
	}
	if err := os.MkdirAll(filepath.Dir(path), 0700); err != nil {
		return
	}
	data, err := json.Marshal(snapshot)
	if err != nil {
		return
	}
	tmp := path + ".tmp"
	if os.WriteFile(tmp, data, 0600) == nil {
		_ = os.Rename(tmp, path)
	}
}

func watch() int {
	if cached, ok := readSnapshotCache(); ok {
		emit(cached)
	}

	commands := make(chan string, 8)
	go func() {
		scanner := bufio.NewScanner(os.Stdin)
		for scanner.Scan() {
			commands <- scanner.Text()
		}
		close(commands)
	}()

	visible := false
	localTicker := time.NewTicker(60 * time.Second)
	rateTicker := time.NewTicker(60 * time.Second)
	usageTicker := time.NewTicker(5 * time.Minute)
	defer localTicker.Stop()
	defer rateTicker.Stop()
	defer usageTicker.Stop()
	filesystemEvents := watchFilesystemEvents()

	refreshLocal := func() {
		ctx, cancel := context.WithTimeout(context.Background(), 20*time.Second)
		snapshot := collectSnapshot(ctx, remoteNone)
		cancel()
		writeSnapshotCache(snapshot)
		emit(snapshot)
	}
	remoteResults := make(chan Snapshot, 1)
	remoteRunning := false
	startRemote := func(mode remoteMode) {
		if remoteRunning {
			return
		}
		remoteRunning = true
		go func() {
			ctx, cancel := context.WithTimeout(context.Background(), 20*time.Second)
			defer cancel()
			remoteResults <- collectSnapshot(ctx, mode)
		}()
	}
	refreshLocal()

	for {
		select {
		case command, ok := <-commands:
			if !ok {
				return 0
			}
			switch command {
			case "open":
				visible = true
				refreshLocal()
				startRemote(remoteFull)
			case "close":
				visible = false
			case "refresh":
				refreshLocal()
				startRemote(remoteFull)
			}
		case <-localTicker.C:
			if visible {
				refreshLocal()
			}
		case <-filesystemEvents:
			if visible {
				refreshLocal()
			}
		case <-rateTicker.C:
			if visible {
				startRemote(remoteRates)
			}
		case <-usageTicker.C:
			if visible {
				startRemote(remoteFull)
			}
		case snapshot := <-remoteResults:
			remoteRunning = false
			writeSnapshotCache(snapshot)
			emit(snapshot)
		}
	}
}

func watchFilesystemEvents() <-chan struct{} {
	events := make(chan struct{}, 1)
	fd, err := unix.InotifyInit1(unix.IN_CLOEXEC)
	if err != nil {
		return events
	}
	home, _ := os.UserHomeDir()
	now := time.Now()
	directories := []string{
		filepath.Join(home, ".local", "share", "opencode"),
		filepath.Join(home, ".config", "opencode"),
		filepath.Join(home, ".config", "Antigravity IDE", "User", "globalStorage"),
		filepath.Join(home, ".codex", "sessions", now.Format("2006"), now.Format("01"), now.Format("02")),
	}
	watches := 0
	for _, directory := range directories {
		if _, err := unix.InotifyAddWatch(fd, directory, unix.IN_CLOSE_WRITE|unix.IN_MOVED_TO|unix.IN_CREATE|unix.IN_DELETE); err == nil {
			watches++
		}
	}
	if watches == 0 {
		_ = unix.Close(fd)
		return events
	}
	go func() {
		defer unix.Close(fd)
		buffer := make([]byte, 16*1024)
		for {
			if _, err := unix.Read(fd, buffer); err != nil {
				return
			}
			select {
			case events <- struct{}{}:
			default:
			}
		}
	}()
	return events
}
