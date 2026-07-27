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
	"sync"
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
	ID        string `json:"id"`
	IsHoliday bool   `json:"is_holiday"`
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

type eventCache struct {
	Version            int                `json:"version"`
	UpdatedAt          string             `json:"updated_at"`
	Months             map[string][]event `json:"months"`
	Calendars          []calendarRef      `json:"calendars,omitempty"`
	CalendarsUpdatedAt string             `json:"calendars_updated_at,omitempty"`
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
	case "cached":
		month, year := "", ""
		if len(args) > 0 {
			month = args[0]
		}
		if len(args) > 1 {
			year = args[1]
		}
		printJSON(loadCachedEvents(month, year))
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

func loadCache() eventCache {
	result := eventCache{
		Version: 1,
		Months:  make(map[string][]event),
	}
	data, err := os.ReadFile(cacheFile())
	if err != nil {
		return result
	}
	if err := json.Unmarshal(data, &result); err == nil && result.Months != nil {
		return result
	}

	var legacy []event
	if err := json.Unmarshal(data, &legacy); err != nil {
		return eventCache{Version: 1, Months: make(map[string][]event)}
	}
	for _, item := range legacy {
		key := monthFromDate(item.Date)
		if key != "" {
			result.Months[key] = append(result.Months[key], item)
		}
	}
	return result
}

func saveCache(cache eventCache) {
	cache.Version = 1
	cache.UpdatedAt = time.Now().UTC().Format(time.RFC3339)
	_ = common.WriteJSON(cacheFile(), cache, 0o600)
}

func loadCachedEvents(monthText, yearText string) []event {
	key, _, _ := eventMonth(monthText, yearText)
	items := loadCache().Months[key]
	if items == nil {
		return []event{}
	}
	return items
}

func monthFromDate(date string) string {
	if len(date) < 7 || date[4] != '-' {
		return ""
	}
	return date[:7]
}

func tokenString(tokens map[string]any, key string) string {
	value, _ := tokens[key].(string)
	return value
}

func tokenNumber(tokens map[string]any, key string) int64 {
	switch value := tokens[key].(type) {
	case float64:
		return int64(value)
	case json.Number:
		result, _ := value.Int64()
		return result
	case int64:
		return value
	case int:
		return int64(value)
	case string:
		result, _ := strconv.ParseInt(value, 10, 64)
		return result
	default:
		return 0
	}
}

func isNetworkConnected() bool {
	executable, err := os.Executable()
	if err == nil {
		result := common.Run(time.Second, executable, "network", "status")
		output := strings.ToLower(strings.TrimSpace(result.Stdout))
		if result.Code == 0 && (strings.Contains(output, "offline") ||
			strings.Contains(output, "unavailable") ||
			strings.Contains(output, "disconnected")) {
			return false
		}
		if result.Code == 0 && output != "" {
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
	accessToken := tokenString(tokens, "access_token")
	expiresAt := tokenNumber(tokens, "expires_at")
	if accessToken != "" && expiresAt > time.Now().Add(time.Minute).Unix() {
		return accessToken
	}

	refreshToken := tokenString(tokens, "refresh_token")
	if refreshToken == "" {
		return accessToken
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
		return accessToken
	}
	defer response.Body.Close()
	body, err := io.ReadAll(response.Body)
	if err != nil || response.StatusCode < 200 || response.StatusCode >= 300 {
		if err == nil {
			err = fmt.Errorf("%s: %s", response.Status, strings.TrimSpace(string(body)))
		}
		fmt.Fprintf(os.Stderr, "Token refresh failed: %v\n", err)
		return accessToken
	}
	var refreshed map[string]any
	if err := json.Unmarshal(body, &refreshed); err != nil {
		fmt.Fprintf(os.Stderr, "Token refresh failed: %v\n", err)
		return accessToken
	}
	accessToken = tokenString(refreshed, "access_token")
	if accessToken != "" {
		for key, value := range refreshed {
			if key != "refresh_token" || tokenString(tokens, "refresh_token") == "" {
				tokens[key] = value
			}
		}
		expiresIn := tokenNumber(refreshed, "expires_in")
		if expiresIn <= 0 {
			expiresIn = 3600
		}
		tokens["expires_at"] = time.Now().Add(time.Duration(expiresIn) * time.Second).Unix()
		_ = saveTokens(tokens)
		return accessToken
	}
	return tokenString(tokens, "access_token")
}

func fetchGoogleEvents(monthText, yearText string) []event {
	key, _, _ := eventMonth(monthText, yearText)
	cache := loadCache()
	cached := cache.Months[key]
	if cached == nil {
		cached = []event{}
	}

	creds, credsErr := loadCredentials()
	tokens, tokensErr := loadTokens()
	if credsErr != nil || tokensErr != nil || !isNetworkConnected() {
		return cached
	}
	accessToken := refreshAccessToken(creds, tokens)
	if accessToken == "" {
		return cached
	}

	timeMin, timeMax := eventRange(monthText, yearText)
	calendars := cachedCalendars(cache)
	client := &http.Client{Timeout: 8 * time.Second}
	if len(calendars) == 0 {
		discovered, ok := fetchCalendars(client, accessToken)
		if ok {
			calendars = discovered
			cache.Calendars = calendars
			cache.CalendarsUpdatedAt = time.Now().UTC().Format(time.RFC3339)
			saveCache(cache)
		} else if len(cache.Calendars) > 0 {
			calendars = cache.Calendars
		} else {
			calendars = defaultCalendars()
		}
	}

	type calendarResult struct {
		calendar calendarRef
		events   []event
		err      error
	}
	results := make(chan calendarResult, len(calendars))
	var requests sync.WaitGroup
	for _, calendar := range calendars {
		requests.Add(1)
		go func(calendar calendarRef) {
			defer requests.Done()

			query := url.Values{
				"timeMin":      {timeMin},
				"timeMax":      {timeMax},
				"singleEvents": {"true"},
				"orderBy":      {"startTime"},
				"maxResults":   {"2500"},
			}
			endpoint := "https://www.googleapis.com/calendar/v3/calendars/" +
				url.PathEscape(calendar.ID) + "/events?" + query.Encode()
			var response eventsResponse
			if err := getJSON(client, endpoint, accessToken, &response); err != nil {
				results <- calendarResult{calendar: calendar, err: err}
				return
			}

			items := make([]event, 0, len(response.Items))
			for _, item := range response.Items {
				datePart, timePart := parseEventStart(item.Start.DateTime, item.Start.Date)
				summary := item.Summary
				if summary == "" {
					summary = "Untitled Event"
				}
				items = append(items, event{
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
			results <- calendarResult{calendar: calendar, events: items}
		}(calendar)
	}
	go func() {
		requests.Wait()
		close(results)
	}()

	parsed := make([]event, 0)
	seen := make(map[string]bool)
	successful := 0
	for result := range results {
		if result.err != nil {
			fmt.Fprintf(os.Stderr, "Fetch events for %s failed: %v\n", result.calendar.ID, result.err)
			continue
		}
		successful++
		for _, item := range result.events {
			dedupeKey := item.ID + "\x00" + item.Date + "\x00" + item.Time
			if seen[dedupeKey] {
				continue
			}
			seen[dedupeKey] = true
			parsed = append(parsed, item)
		}
	}

	if successful == 0 || (successful < len(calendars) && len(cached) > 0) {
		return cached
	}
	sortEvents(parsed)
	cache.Months[key] = parsed
	saveCache(cache)
	return parsed
}

func defaultCalendars() []calendarRef {
	return []calendarRef{
		{ID: "primary", IsHoliday: false},
		{ID: holidayCalendar, IsHoliday: true},
	}
}

func cachedCalendars(cache eventCache) []calendarRef {
	if len(cache.Calendars) == 0 || cache.CalendarsUpdatedAt == "" {
		return nil
	}
	updatedAt, err := time.Parse(time.RFC3339, cache.CalendarsUpdatedAt)
	if err != nil || time.Since(updatedAt) > 24*time.Hour {
		return nil
	}
	return cache.Calendars
}

func fetchCalendars(client *http.Client, accessToken string) ([]calendarRef, bool) {
	calendars := defaultCalendars()
	var calendarList calendarListResponse
	if err := getJSON(client, "https://www.googleapis.com/calendar/v3/users/me/calendarList", accessToken, &calendarList); err != nil {
		return calendars, false
	}
	existing := map[string]bool{"primary": true, holidayCalendar: true}
	for _, item := range calendarList.Items {
		if item.ID == "" || existing[item.ID] {
			continue
		}
		text := strings.ToLower(item.ID + " " + item.Summary)
		calendars = append(calendars, calendarRef{ID: item.ID, IsHoliday: strings.Contains(text, "holiday")})
		existing[item.ID] = true
	}
	return calendars, true
}

func sortEvents(events []event) {
	sort.SliceStable(events, func(i, j int) bool {
		if events[i].Date != events[j].Date {
			return events[i].Date < events[j].Date
		}
		left, right := parseTimeMinutes(events[i].Time), parseTimeMinutes(events[j].Time)
		if left != right {
			return left < right
		}
		return events[i].Summary < events[j].Summary
	})
}

func eventRange(monthText, yearText string) (string, string) {
	_, month, year := eventMonth(monthText, yearText)
	start := time.Date(year, time.Month(month), 1, 0, 0, 0, 0, time.UTC)
	end := start.AddDate(0, 1, 0)
	return start.Format(time.RFC3339), end.Format(time.RFC3339)
}

func eventMonth(monthText, yearText string) (string, int, int) {
	now := time.Now()
	month := int(now.Month())
	year := now.Year()
	if parsedMonth, err := strconv.Atoi(monthText); err == nil && parsedMonth >= 1 && parsedMonth <= 12 {
		month = parsedMonth
	}
	if parsedYear, err := strconv.Atoi(yearText); err == nil && parsedYear >= 1 {
		year = parsedYear
	}
	return fmt.Sprintf("%04d-%02d", year, month), month, year
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
	expiresIn := tokenNumber(tokens, "expires_in")
	if expiresIn <= 0 {
		expiresIn = 3600
	}
	tokens["expires_at"] = time.Now().Add(time.Duration(expiresIn) * time.Second).Unix()
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
