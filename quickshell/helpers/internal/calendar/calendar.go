package calendar

import (
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net"
	"net/http"
	"net/url"
	"os"
	"os/exec"
	"path/filepath"
	"sort"
	"strconv"
	"strings"
	"time"

	"quickshell/helpers/internal/common"
)

const (
	defaultAuthURI  = "https://accounts.google.com/o/oauth2/auth"
	defaultTokenURI = "https://oauth2.googleapis.com/token"
	holidayCalendar = "en.indian#holiday@group.v.calendar.google.com"
)

type credentials struct {
	ClientID     string `json:"client_id"`
	ClientSecret string `json:"client_secret"`
	AuthURI      string `json:"auth_uri"`
	TokenURI     string `json:"token_uri"`
}

type calendarRef struct {
	ID        string
	IsHoliday bool
}

type event struct {
	ID          string `json:"id"`
	Summary     string `json:"summary"`
	Description string `json:"description"`
	Location    string `json:"location"`
	Date        string `json:"date"`
	Time        string `json:"time"`
	IsHoliday   bool   `json:"is_holiday"`
	Link        string `json:"link"`
}

type calendarListResponse struct {
	Items []struct {
		ID      string `json:"id"`
		Summary string `json:"summary"`
	} `json:"items"`
}

type eventsResponse struct {
	Items []struct {
		ID       string `json:"id"`
		Summary  string `json:"summary"`
		HTMLLink string `json:"htmlLink"`
		Start    struct {
			DateTime string `json:"dateTime"`
			Date     string `json:"date"`
		} `json:"start"`
	} `json:"items"`
}

func Run(argv []string) int {
	action := "events"
	var args []string
	if len(argv) > 0 {
		action = argv[0]
		args = argv[1:]
	}
	switch action {
	case "auth":
		return runOAuthAuth()
	case "events":
		month, year := "", ""
		if len(args) > 0 {
			month = args[0]
		}
		if len(args) > 1 {
			year = args[1]
		}
		printJSON(fetchGoogleEvents(month, year))
	case "status":
		_, tokenErr := loadTokens()
		fmt.Printf("authenticated\t%s\n", common.Bool01(tokenErr == nil))
		fmt.Printf("online\t%s\n", common.Bool01(isNetworkConnected()))
	default:
		fmt.Println("[]")
	}
	return 0
}

func credentialsFile() string {
	return filepath.Join(common.HomeDir(), ".config", "quickshell", "google_calendar_credentials.json")
}

func tokensFile() string {
	return filepath.Join(common.HomeDir(), ".config", "quickshell", "google_calendar_tokens.json")
}

func cacheFile() string {
	return filepath.Join(common.HomeDir(), ".cache", "quickshell", "google_calendar_cache.json")
}

func loadCredentials() (*credentials, error) {
	if clientID, clientSecret := os.Getenv("GOOGLE_CLIENT_ID"), os.Getenv("GOOGLE_CLIENT_SECRET"); clientID != "" && clientSecret != "" {
		return &credentials{
			ClientID:     clientID,
			ClientSecret: clientSecret,
			AuthURI:      defaultAuthURI,
			TokenURI:     defaultTokenURI,
		}, nil
	}
	var result credentials
	if err := common.ReadJSON(credentialsFile(), &result); err != nil {
		return nil, err
	}
	if result.AuthURI == "" {
		result.AuthURI = defaultAuthURI
	}
	if result.TokenURI == "" {
		result.TokenURI = defaultTokenURI
	}
	if result.ClientID == "" || result.ClientSecret == "" {
		return nil, fmt.Errorf("calendar credentials are incomplete")
	}
	return &result, nil
}

func loadTokens() (map[string]any, error) {
	result := make(map[string]any)
	if err := common.ReadJSON(tokensFile(), &result); err != nil {
		return nil, err
	}
	return result, nil
}

func saveTokens(tokens map[string]any) error {
	return common.WriteJSON(tokensFile(), tokens, 0o600)
}

func loadCache() []event {
	var result []event
	if err := common.ReadJSON(cacheFile(), &result); err != nil {
		return []event{}
	}
	return result
}

func saveCache(events []event) {
	_ = common.WriteJSON(cacheFile(), events, 0o600)
}

func tokenString(tokens map[string]any, key string) string {
	value, _ := tokens[key].(string)
	return value
}

func isNetworkConnected() bool {
	executable, err := os.Executable()
	if err == nil {
		result := common.Run(time.Second, executable, "network", "status")
		output := strings.ToLower(strings.TrimSpace(result.Stdout))
		if strings.Contains(output, "offline") ||
			strings.Contains(output, "unavailable") ||
			strings.Contains(output, "disconnected") {
			return false
		}
		if strings.Contains(output, "online") ||
			strings.Contains(output, "connected") ||
			strings.Contains(output, "wifi") ||
			strings.Contains(output, "ethernet") {
			return true
		}
	}

	client := &http.Client{Timeout: time.Second}
	response, err := client.Get("https://www.google.com")
	if err != nil {
		return false
	}
	_ = response.Body.Close()
	return true
}

func refreshAccessToken(creds *credentials, tokens map[string]any) string {
	refreshToken := tokenString(tokens, "refresh_token")
	if refreshToken == "" {
		return ""
	}
	form := url.Values{
		"client_id":     {creds.ClientID},
		"client_secret": {creds.ClientSecret},
		"refresh_token": {refreshToken},
		"grant_type":    {"refresh_token"},
	}
	client := &http.Client{Timeout: 10 * time.Second}
	response, err := client.PostForm(creds.TokenURI, form)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Token refresh failed: %v\n", err)
		return tokenString(tokens, "access_token")
	}
	defer response.Body.Close()
	body, err := io.ReadAll(response.Body)
	if err != nil || response.StatusCode < 200 || response.StatusCode >= 300 {
		if err == nil {
			err = fmt.Errorf("%s: %s", response.Status, strings.TrimSpace(string(body)))
		}
		fmt.Fprintf(os.Stderr, "Token refresh failed: %v\n", err)
		return tokenString(tokens, "access_token")
	}
	var refreshed map[string]any
	if err := json.Unmarshal(body, &refreshed); err != nil {
		fmt.Fprintf(os.Stderr, "Token refresh failed: %v\n", err)
		return tokenString(tokens, "access_token")
	}
	accessToken := tokenString(refreshed, "access_token")
	if accessToken != "" {
		tokens["access_token"] = accessToken
		_ = saveTokens(tokens)
		return accessToken
	}
	return tokenString(tokens, "access_token")
}

func fetchGoogleEvents(monthText, yearText string) []event {
	creds, credsErr := loadCredentials()
	tokens, tokensErr := loadTokens()
	if credsErr != nil || tokensErr != nil || !isNetworkConnected() {
		return loadCache()
	}
	accessToken := refreshAccessToken(creds, tokens)
	if accessToken == "" {
		return loadCache()
	}

	timeMin, timeMax := eventRange(monthText, yearText)
	calendars := []calendarRef{
		{ID: "primary", IsHoliday: false},
		{ID: holidayCalendar, IsHoliday: true},
	}
	client := &http.Client{Timeout: 10 * time.Second}

	var calendarList calendarListResponse
	if err := getJSON(client, "https://www.googleapis.com/calendar/v3/users/me/calendarList", accessToken, &calendarList); err == nil {
		existing := map[string]bool{"primary": true, holidayCalendar: true}
		for _, item := range calendarList.Items {
			if item.ID == "" || existing[item.ID] {
				continue
			}
			text := strings.ToLower(item.ID + " " + item.Summary)
			calendars = append(calendars, calendarRef{ID: item.ID, IsHoliday: strings.Contains(text, "holiday")})
			existing[item.ID] = true
		}
	}

	var parsed []event
	seen := make(map[string]bool)
	for _, calendar := range calendars {
		query := url.Values{
			"timeMin":      {timeMin},
			"timeMax":      {timeMax},
			"singleEvents": {"true"},
			"orderBy":      {"startTime"},
		}
		endpoint := "https://www.googleapis.com/calendar/v3/calendars/" +
			url.PathEscape(calendar.ID) + "/events?" + query.Encode()
		var response eventsResponse
		if err := getJSON(client, endpoint, accessToken, &response); err != nil {
			fmt.Fprintf(os.Stderr, "Fetch events for %s failed: %v\n", calendar.ID, err)
			continue
		}
		for _, item := range response.Items {
			if seen[item.ID] {
				continue
			}
			seen[item.ID] = true
			datePart, timePart := parseEventStart(item.Start.DateTime, item.Start.Date)
			summary := item.Summary
			if summary == "" {
				summary = "Untitled Event"
			}
			parsed = append(parsed, event{
				ID:          item.ID,
				Summary:     summary,
				Description: "",
				Location:    "",
				Date:        datePart,
				Time:        timePart,
				IsHoliday:   calendar.IsHoliday,
				Link:        item.HTMLLink,
			})
		}
	}

	if len(parsed) == 0 {
		return loadCache()
	}
	sort.SliceStable(parsed, func(i, j int) bool {
		if parsed[i].Date != parsed[j].Date {
			return parsed[i].Date < parsed[j].Date
		}
		left, right := parseTimeMinutes(parsed[i].Time), parseTimeMinutes(parsed[j].Time)
		if left != right {
			return left < right
		}
		return parsed[i].Summary < parsed[j].Summary
	})
	saveCache(parsed)
	return parsed
}

func eventRange(monthText, yearText string) (string, string) {
	now := time.Now().UTC()
	start := now.AddDate(0, 0, -365)
	end := now.AddDate(0, 0, 365)
	month, monthErr := strconv.Atoi(monthText)
	year, yearErr := strconv.Atoi(yearText)
	if monthText != "" && yearText != "" && monthErr == nil && yearErr == nil && month >= 1 && month <= 12 {
		target := time.Date(year, time.Month(month), 1, 0, 0, 0, 0, time.UTC)
		start = target.AddDate(0, 0, -60)
		end = target.AddDate(0, 0, 120)
	}
	return start.Format("2006-01-02") + "T00:00:00Z", end.Format("2006-01-02") + "T23:59:59Z"
}

func getJSON(client *http.Client, endpoint, accessToken string, target any) error {
	request, err := http.NewRequest(http.MethodGet, endpoint, nil)
	if err != nil {
		return err
	}
	request.Header.Set("Authorization", "Bearer "+accessToken)
	response, err := client.Do(request)
	if err != nil {
		return err
	}
	defer response.Body.Close()
	if response.StatusCode < 200 || response.StatusCode >= 300 {
		body, _ := io.ReadAll(io.LimitReader(response.Body, 4096))
		return fmt.Errorf("%s: %s", response.Status, strings.TrimSpace(string(body)))
	}
	return json.NewDecoder(response.Body).Decode(target)
}

func parseEventStart(dateTimeText, dateText string) (string, string) {
	if dateTimeText == "" {
		return dateText, ""
	}
	value, err := time.Parse(time.RFC3339, dateTimeText)
	if err != nil {
		parts := strings.SplitN(dateTimeText, "T", 2)
		if len(parts) == 2 {
			timePart := parts[1]
			if len(timePart) > 5 {
				timePart = timePart[:5]
			}
			return parts[0], timePart
		}
		return dateTimeText, ""
	}
	local := value.Local()
	return local.Format("2006-01-02"), local.Format("03:04 PM")
}

func parseTimeMinutes(value string) int {
	if value == "" || value == "All Day" {
		return -1
	}
	parsed, err := time.Parse("03:04 PM", value)
	if err != nil {
		return 9999
	}
	return parsed.Hour()*60 + parsed.Minute()
}

func runOAuthAuth() int {
	creds, err := loadCredentials()
	if err != nil {
		fmt.Println("Error: credentials file missing!")
		return 1
	}

	redirectURI := "http://localhost:8080"
	params := url.Values{
		"client_id":     {creds.ClientID},
		"redirect_uri":  {redirectURI},
		"response_type": {"code"},
		"scope":         {"https://www.googleapis.com/auth/calendar.readonly"},
		"access_type":   {"offline"},
		"prompt":        {"consent"},
	}
	authURL := creds.AuthURI + "?" + params.Encode()
	fmt.Printf("Opening browser for Google Calendar authorization:\n%s\n\n", authURL)

	listener, err := net.Listen("tcp", "localhost:8080")
	if err != nil {
		fmt.Printf("Failed to start OAuth callback server: %v\n", err)
		return 1
	}
	defer listener.Close()

	codeChannel := make(chan string, 1)
	server := &http.Server{Handler: http.HandlerFunc(func(writer http.ResponseWriter, request *http.Request) {
		code := request.URL.Query().Get("code")
		if code != "" {
			writer.Header().Set("Content-Type", "text/html")
			writer.WriteHeader(http.StatusOK)
			_, _ = io.WriteString(writer, "<h1>Authorization successful!</h1><p>You can close this tab and return to Quickshell.</p>")
		} else {
			writer.WriteHeader(http.StatusBadRequest)
			_, _ = io.WriteString(writer, "Authorization failed.")
		}
		select {
		case codeChannel <- code:
		default:
		}
	})}
	go func() {
		_ = server.Serve(listener)
	}()
	openBrowser(authURL)

	code := <-codeChannel
	shutdownContext, cancel := context.WithTimeout(context.Background(), time.Second)
	_ = server.Shutdown(shutdownContext)
	cancel()
	if code == "" {
		fmt.Println("Failed to receive authorization code.")
		return 1
	}

	form := url.Values{
		"client_id":     {creds.ClientID},
		"client_secret": {creds.ClientSecret},
		"code":          {code},
		"grant_type":    {"authorization_code"},
		"redirect_uri":  {redirectURI},
	}
	client := &http.Client{Timeout: 15 * time.Second}
	response, err := client.PostForm(creds.TokenURI, form)
	if err != nil {
		fmt.Printf("Failed to exchange token: %v\n", err)
		return 1
	}
	defer response.Body.Close()
	body, readErr := io.ReadAll(response.Body)
	if readErr != nil || response.StatusCode < 200 || response.StatusCode >= 300 {
		if readErr == nil {
			readErr = fmt.Errorf("%s: %s", response.Status, strings.TrimSpace(string(body)))
		}
		fmt.Printf("Failed to exchange token: %v\n", readErr)
		return 1
	}
	var tokens map[string]any
	if err := json.Unmarshal(body, &tokens); err != nil {
		fmt.Printf("Failed to exchange token: %v\n", err)
		return 1
	}
	if err := saveTokens(tokens); err != nil {
		fmt.Printf("Failed to exchange token: %v\n", err)
		return 1
	}
	fmt.Println("Google Calendar authorization successful! Tokens saved.")
	return 0
}

func openBrowser(target string) {
	for _, command := range []string{"xdg-open", "gio"} {
		path, err := exec.LookPath(command)
		if err != nil {
			continue
		}
		args := []string{target}
		if command == "gio" {
			args = []string{"open", target}
		}
		_ = common.StartDetached(path, args...)
		return
	}
	fmt.Fprintln(os.Stderr, "No browser opener found; open the authorization URL manually.")
}

func printJSON(value any) {
	encoder := json.NewEncoder(os.Stdout)
	encoder.SetEscapeHTML(false)
	if err := encoder.Encode(value); err != nil {
		fmt.Println("[]")
	}
}
