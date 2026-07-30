package controls

import (
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"errors"
	"fmt"
	"image"
	_ "image/gif"
	_ "image/jpeg"
	_ "image/png"
	"io"
	"net"
	"net/http"
	"net/url"
	"os"
	"path/filepath"
	"strings"
	"sync"
	"syscall"
	"time"

	"quickshell/helpers/internal/common"
)

const (
	mediaArtworkListenAddress = "127.0.0.1:47831"
	mediaArtworkMaxDownload   = 20 * 1024 * 1024
	mediaArtworkMaxAge        = 10 * time.Minute
	mediaArtworkMinWidth      = 640
	mediaArtworkMinHeight     = 360
)

var mediaArtworkWriteMu sync.Mutex

type mediaArtworkRequest struct {
	PageURL    string `json:"pageUrl"`
	MediaURL   string `json:"mediaUrl"`
	PageKey    string `json:"pageKey"`
	Title      string `json:"title"`
	ArtworkURL string `json:"artworkUrl"`
}

type mediaArtworkState struct {
	Title       string `json:"title"`
	Path        string `json:"path"`
	Width       int    `json:"width,omitempty"`
	Height      int    `json:"height,omitempty"`
	Fingerprint string `json:"fingerprint,omitempty"`
	UpdatedAt   int64  `json:"updatedAt"`
}

func mediaArtworkRuntimeDir() string {
	if runtimeDir := strings.TrimSpace(os.Getenv("XDG_RUNTIME_DIR")); runtimeDir != "" {
		return filepath.Join(runtimeDir, "quickshell-media-artwork")
	}
	return filepath.Join(os.TempDir(), fmt.Sprintf("quickshell-media-artwork-%d", os.Getuid()))
}

func mediaArtworkStatePath() string {
	return filepath.Join(mediaArtworkRuntimeDir(), "current.json")
}

func mediaArtworkFileURL(path string) string {
	return "file://" + path
}

func validArtworkURL(raw string) bool {
	parsed, err := url.Parse(strings.TrimSpace(raw))
	if err != nil || parsed.Host == "" {
		return false
	}
	return parsed.Scheme == "http" || parsed.Scheme == "https"
}

func normalizedArtworkTitle(value string) string {
	value = strings.ToLower(strings.TrimSpace(value))
	var builder strings.Builder
	for _, char := range value {
		if (char >= 'a' && char <= 'z') || (char >= '0' && char <= '9') {
			builder.WriteRune(char)
		} else if builder.Len() > 0 {
			builder.WriteByte(' ')
		}
	}
	return strings.Join(strings.Fields(builder.String()), " ")
}

func placeholderArtworkTitle(value string) bool {
	switch normalizedArtworkTitle(value) {
	case "", "media", "unknown", "untitled", "no title", "a site is playing media":
		return true
	default:
		return false
	}
}

func artworkPageTitle(pageURL string) string {
	parsed, err := url.Parse(strings.TrimSpace(pageURL))
	if err == nil && parsed.Host != "" {
		path := strings.Trim(strings.TrimSpace(parsed.Path), "/")
		if path != "" {
			parts := strings.Split(path, "/")
			path = parts[len(parts)-1]
			if decoded, decodeErr := url.PathUnescape(path); decodeErr == nil {
				path = decoded
			}
			path = strings.TrimSpace(path)
		}
		if path != "" {
			return parsed.Host + " — " + path
		}
		return parsed.Host
	}
	return "Web media"
}

func artworkTitleMatches(mediaTitle, artworkTitle string) bool {
	if placeholderArtworkTitle(mediaTitle) || placeholderArtworkTitle(artworkTitle) {
		return false
	}
	mediaTitle = normalizedArtworkTitle(mediaTitle)
	artworkTitle = normalizedArtworkTitle(artworkTitle)
	if mediaTitle == "" || artworkTitle == "" {
		return false
	}
	if mediaTitle == artworkTitle {
		return true
	}
	return len(mediaTitle) >= 16 && len(artworkTitle) >= 16 &&
		(strings.Contains(mediaTitle, artworkTitle) || strings.Contains(artworkTitle, mediaTitle))
}

func artworkDimensions(path string) (int, int, bool) {
	file, err := os.Open(path)
	if err != nil {
		return 0, 0, false
	}
	defer file.Close()
	config, _, err := image.DecodeConfig(file)
	if err != nil {
		return 0, 0, false
	}
	return config.Width, config.Height, config.Width > 0 && config.Height > 0
}

func highQualityArtworkPath(path string) bool {
	info, err := os.Stat(path)
	if err != nil || info.IsDir() || info.Size() == 0 {
		return false
	}
	width, height, ok := artworkDimensions(path)
	return !ok || (width >= mediaArtworkMinWidth && height >= mediaArtworkMinHeight)
}

func highQualityArtworkURL(raw string) bool {
	parsed, err := url.Parse(strings.TrimSpace(raw))
	if err != nil || parsed.Scheme != "file" {
		return true
	}
	path, err := url.PathUnescape(parsed.Path)
	if err != nil {
		return false
	}
	return highQualityArtworkPath(path)
}

func browserMediaPlayer(player string) bool {
	player = strings.ToLower(strings.TrimSpace(player))
	for _, marker := range []string{
		"chromium", "helium", "chrome", "brave", "firefox", "librewolf",
		"vivaldi", "opera", "microsoft-edge", "browser",
	} {
		if strings.Contains(player, marker) {
			return true
		}
	}
	return false
}

func localMediaPath(rawURL string) (string, bool) {
	parsed, err := url.Parse(strings.TrimSpace(rawURL))
	if err != nil || parsed.Scheme != "file" || parsed.Path == "" {
		return "", false
	}
	path, err := url.PathUnescape(parsed.Path)
	if err != nil || !filepath.IsAbs(path) {
		return "", false
	}
	info, err := os.Stat(path)
	if err != nil || !info.Mode().IsRegular() {
		return "", false
	}
	return path, true
}

func localMediaTitle(rawURL string) string {
	path, ok := localMediaPath(rawURL)
	if !ok {
		return ""
	}
	name := strings.TrimSuffix(filepath.Base(path), filepath.Ext(path))
	return strings.TrimSpace(name)
}

func localMediaArtwork(rawURL string) string {
	path, ok := localMediaPath(rawURL)
	if !ok {
		return ""
	}

	extension := strings.ToLower(filepath.Ext(path))
	videoExtensions := map[string]bool{
		".3gp": true, ".avi": true, ".flv": true, ".m4v": true,
		".mkv": true, ".mov": true, ".mp4": true, ".mpeg": true,
		".mpg": true, ".ogv": true, ".ts": true, ".webm": true,
		".wmv": true,
	}
	if !videoExtensions[extension] {
		return ""
	}

	info, err := os.Stat(path)
	if err != nil {
		return ""
	}
	key := fmt.Sprintf("%s:%d:%d", path, info.ModTime().UnixNano(), info.Size())
	hash := sha256.Sum256([]byte(key))
	baseName := hex.EncodeToString(hash[:])
	cachePath := filepath.Join(mediaArtworkRuntimeDir(), "local-"+baseName+".jpg")
	if cached, err := os.Stat(cachePath); err == nil && !cached.IsDir() && cached.Size() > 0 {
		return mediaArtworkFileURL(cachePath)
	}

	if err := os.MkdirAll(mediaArtworkRuntimeDir(), 0o700); err != nil {
		return ""
	}
	tmpPath := filepath.Join(mediaArtworkRuntimeDir(), ".local-"+baseName+".jpg")
	_ = os.Remove(tmpPath)
	result := common.Run(20*time.Second, "ffmpeg", "-hide_banner", "-loglevel", "error", "-ss", "1", "-i", path, "-frames:v", "1", "-q:v", "2", "-y", tmpPath)
	if result.Code != 0 {
		_ = os.Remove(tmpPath)
		return ""
	}
	if generated, err := os.Stat(tmpPath); err != nil || generated.IsDir() || generated.Size() == 0 {
		_ = os.Remove(tmpPath)
		return ""
	}
	if err := os.Rename(tmpPath, cachePath); err != nil {
		_ = os.Remove(tmpPath)
		if cached, statErr := os.Stat(cachePath); statErr == nil && !cached.IsDir() {
			return mediaArtworkFileURL(cachePath)
		}
		return ""
	}
	return mediaArtworkFileURL(cachePath)
}

func readCurrentArtwork(mediaTitle string) (string, string, bool) {
	var state mediaArtworkState
	if err := readJSONFile(mediaArtworkStatePath(), &state); err != nil {
		return "", "", false
	}
	if time.Since(time.Unix(state.UpdatedAt, 0)) > mediaArtworkMaxAge {
		return "", "", false
	}
	if !placeholderArtworkTitle(mediaTitle) && !artworkTitleMatches(mediaTitle, state.Title) {
		return "", "", false
	}
	if info, err := os.Stat(state.Path); err != nil || info.IsDir() || !highQualityArtworkPath(state.Path) {
		return "", "", false
	}
	return mediaArtworkFileURL(state.Path), state.Title, true
}

func readJSONFile(path string, target any) error {
	data, err := os.ReadFile(path)
	if err != nil {
		return err
	}
	return json.Unmarshal(data, target)
}

func writeJSONFile(path string, value any) error {
	data, err := json.Marshal(value)
	if err != nil {
		return err
	}
	if err := os.MkdirAll(filepath.Dir(path), 0o700); err != nil {
		return err
	}
	tmp, err := os.CreateTemp(filepath.Dir(path), ".media-artwork-*")
	if err != nil {
		return err
	}
	tmpName := tmp.Name()
	defer os.Remove(tmpName)
	if err := tmp.Chmod(0o600); err != nil {
		_ = tmp.Close()
		return err
	}
	if _, err := tmp.Write(data); err != nil {
		_ = tmp.Close()
		return err
	}
	if err := tmp.Close(); err != nil {
		return err
	}
	return os.Rename(tmpName, path)
}

func artworkFingerprint(request mediaArtworkRequest) string {
	value := request.PageURL + "\x00" + request.MediaURL + "\x00" + request.PageKey + "\x00" + request.Title + "\x00" + request.ArtworkURL
	hash := sha256.Sum256([]byte(value))
	return hex.EncodeToString(hash[:])
}

func writeArtworkResponse(writer http.ResponseWriter, status int, value any) {
	writer.Header().Set("Content-Type", "application/json")
	writer.WriteHeader(status)
	_ = json.NewEncoder(writer).Encode(value)
}

func artworkExtension(contentType string) string {
	switch strings.ToLower(strings.TrimSpace(strings.Split(contentType, ";")[0])) {
	case "image/png":
		return ".png"
	case "image/webp":
		return ".webp"
	case "image/gif":
		return ".gif"
	default:
		return ".jpg"
	}
}

func downloadArtwork(rawURL string) (string, error) {
	if !validArtworkURL(rawURL) {
		return "", fmt.Errorf("invalid artwork URL")
	}

	hash := sha256.Sum256([]byte(rawURL))
	baseName := hex.EncodeToString(hash[:])

	client := &http.Client{
		Timeout: 12 * time.Second,
		CheckRedirect: func(req *http.Request, via []*http.Request) error {
			if len(via) >= 5 || !validArtworkURL(req.URL.String()) {
				return http.ErrUseLastResponse
			}
			return nil
		},
	}
	request, err := http.NewRequest(http.MethodGet, rawURL, nil)
	if err != nil {
		return "", err
	}
	request.Header.Set("User-Agent", "Quickshell media artwork")
	response, err := client.Do(request)
	if err != nil {
		return "", err
	}
	defer response.Body.Close()
	if response.StatusCode < 200 || response.StatusCode >= 300 {
		return "", fmt.Errorf("artwork server returned %s", response.Status)
	}

	data, err := io.ReadAll(io.LimitReader(response.Body, mediaArtworkMaxDownload+1))
	if err != nil {
		return "", err
	}
	if len(data) == 0 || len(data) > mediaArtworkMaxDownload {
		return "", fmt.Errorf("artwork image is empty or too large")
	}
	contentType := response.Header.Get("Content-Type")
	if !strings.HasPrefix(contentType, "image/") {
		contentType = http.DetectContentType(data)
	}
	if !strings.HasPrefix(contentType, "image/") {
		return "", fmt.Errorf("artwork response is not an image")
	}
	cachePath := filepath.Join(mediaArtworkRuntimeDir(), baseName+artworkExtension(contentType))
	if info, err := os.Stat(cachePath); err == nil && !info.IsDir() {
		return cachePath, nil
	}

	if err := os.MkdirAll(mediaArtworkRuntimeDir(), 0o700); err != nil {
		return "", err
	}
	tmp, err := os.CreateTemp(mediaArtworkRuntimeDir(), ".download-*")
	if err != nil {
		return "", err
	}
	tmpName := tmp.Name()
	defer os.Remove(tmpName)
	if err := tmp.Chmod(0o600); err != nil {
		_ = tmp.Close()
		return "", err
	}
	if _, err := tmp.Write(data); err != nil {
		_ = tmp.Close()
		return "", err
	}
	if err := tmp.Close(); err != nil {
		return "", err
	}
	if err := os.Rename(tmpName, cachePath); err != nil {
		return "", err
	}
	return cachePath, nil
}

func mediaArtworkServer() int {
	if err := os.MkdirAll(mediaArtworkRuntimeDir(), 0o700); err != nil {
		return 1
	}

	lockPath := filepath.Join(mediaArtworkRuntimeDir(), "media-artwork-server.lock")
	var releaseLock func()
	for {
		release, acquired, err := common.TryFileLock(lockPath)
		if err != nil {
			fmt.Fprintf(os.Stderr, "media artwork server lock: %v\n", err)
			return 1
		}
		if acquired {
			releaseLock = release
			break
		}
		time.Sleep(2 * time.Second)
	}
	defer releaseLock()

	mux := http.NewServeMux()
	mux.HandleFunc("/health", func(writer http.ResponseWriter, request *http.Request) {
		writer.WriteHeader(http.StatusNoContent)
	})
	mux.HandleFunc("/v1/artwork", func(writer http.ResponseWriter, request *http.Request) {
		writer.Header().Set("Access-Control-Allow-Origin", "*")
		writer.Header().Set("Access-Control-Allow-Methods", "POST, OPTIONS")
		writer.Header().Set("Access-Control-Allow-Headers", "Content-Type")
		if request.Method == http.MethodOptions {
			writer.WriteHeader(http.StatusNoContent)
			return
		}
		if request.Method != http.MethodPost {
			http.Error(writer, "method not allowed", http.StatusMethodNotAllowed)
			return
		}

		var payload mediaArtworkRequest
		decoder := json.NewDecoder(io.LimitReader(request.Body, 32*1024))
		if err := decoder.Decode(&payload); err != nil || !validArtworkURL(payload.ArtworkURL) {
			writeArtworkResponse(writer, http.StatusBadRequest, map[string]any{"ok": false, "error": "invalid artwork request"})
			return
		}
		if placeholderArtworkTitle(payload.Title) {
			payload.Title = artworkPageTitle(payload.PageURL)
		}

		mediaArtworkWriteMu.Lock()
		path, err := downloadArtwork(payload.ArtworkURL)
		if err == nil {
			width, height, dimensionsKnown := artworkDimensions(path)
			var current mediaArtworkState
			currentExists := readJSONFile(mediaArtworkStatePath(), &current) == nil
			keepCurrent := currentExists && artworkTitleMatches(payload.Title, current.Title) &&
				current.UpdatedAt > 0 && time.Since(time.Unix(current.UpdatedAt, 0)) <= mediaArtworkMaxAge &&
				current.Width >= width && current.Height >= height && highQualityArtworkPath(current.Path)
			if !keepCurrent {
				state := mediaArtworkState{
					Title: payload.Title, Path: path, Width: width, Height: height,
					Fingerprint: artworkFingerprint(payload), UpdatedAt: time.Now().Unix(),
				}
				err = writeJSONFile(mediaArtworkStatePath(), state)
			} else if !dimensionsKnown {
				// Unknown formats such as WebP are allowed, but never replace a
				// known high-resolution image for the same title.
				err = nil
			}
		}
		mediaArtworkWriteMu.Unlock()

		if err != nil {
			writeArtworkResponse(writer, http.StatusBadGateway, map[string]any{"ok": false, "error": "artwork unavailable"})
			return
		}
		writeArtworkResponse(writer, http.StatusOK, map[string]any{"ok": true})
	})

	var listener net.Listener
	var err error
	for {
		listener, err = net.Listen("tcp", mediaArtworkListenAddress)
		if err == nil {
			break
		}
		if !errors.Is(err, syscall.EADDRINUSE) {
			return 1
		}
		time.Sleep(2 * time.Second)
	}
	defer listener.Close()
	server := &http.Server{Handler: mux, ReadHeaderTimeout: 5 * time.Second}
	if err := server.Serve(listener); err != nil && err != http.ErrServerClosed {
		return 1
	}
	return 0
}
