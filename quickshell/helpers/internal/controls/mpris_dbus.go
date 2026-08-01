package controls

import (
	"fmt"
	"os"
	"strconv"
	"strings"
	"sync"

	"github.com/godbus/dbus/v5"
)

var (
	dbusConn  *dbus.Conn
	dbusMutex sync.Mutex
)

func getSessionBus() (*dbus.Conn, error) {
	dbusMutex.Lock()
	defer dbusMutex.Unlock()
	if dbusConn == nil {
		conn, err := dbus.SessionBus()
		if err != nil {
			return nil, err
		}
		dbusConn = conn
	}
	return dbusConn, nil
}

func variantString(v dbus.Variant) string {
	if v.Value() == nil {
		return ""
	}
	if s, ok := v.Value().(string); ok {
		return strings.TrimSpace(s)
	}
	return strings.TrimSpace(fmt.Sprint(v.Value()))
}

func variantStringSlice(v dbus.Variant) string {
	if v.Value() == nil {
		return ""
	}
	switch val := v.Value().(type) {
	case []string:
		return strings.TrimSpace(strings.Join(val, ", "))
	case []interface{}:
		var strs []string
		for _, item := range val {
			if s, ok := item.(string); ok && s != "" {
				strs = append(strs, s)
			}
		}
		return strings.TrimSpace(strings.Join(strs, ", "))
	case string:
		return strings.TrimSpace(val)
	}
	return ""
}

func variantInt64(v dbus.Variant) int64 {
	if v.Value() == nil {
		return 0
	}
	switch val := v.Value().(type) {
	case int64:
		return val
	case uint64:
		return int64(val)
	case int32:
		return int64(val)
	case uint32:
		return int64(val)
	case int:
		return int64(val)
	case float64:
		return int64(val)
	}
	if s, err := strconv.ParseInt(fmt.Sprint(v.Value()), 10, 64); err == nil {
		return s
	}
	return 0
}

func listMprisPlayers(conn *dbus.Conn) []string {
	var names []string
	err := conn.BusObject().Call("org.freedesktop.DBus.ListNames", 0).Store(&names)
	if err != nil {
		return nil
	}
	var players []string
	for _, name := range names {
		if strings.HasPrefix(name, "org.mpris.MediaPlayer2.") {
			players = append(players, strings.TrimPrefix(name, "org.mpris.MediaPlayer2."))
		}
	}
	return players
}

func fetchMprisCandidate(conn *dbus.Conn, shortName string, urlStr *string) candidate {
	serviceName := "org.mpris.MediaPlayer2." + shortName
	obj := conn.Object(serviceName, "/org/mpris/MediaPlayer2")

	item := candidate{
		player: shortName,
		state:  "Stopped",
	}

	var status string
	if err := obj.StoreProperty("org.mpris.MediaPlayer2.Player.PlaybackStatus", &status); err == nil {
		item.state = strings.TrimSpace(status)
	}

	var meta map[string]dbus.Variant
	if err := obj.StoreProperty("org.mpris.MediaPlayer2.Player.Metadata", &meta); err == nil && meta != nil {
		item.artist = variantStringSlice(meta["xesam:artist"])
		item.title = variantString(meta["xesam:title"])
		item.artURL = variantString(meta["mpris:artUrl"])
		lenUs := variantInt64(meta["mpris:length"])
		if lenUs > 0 {
			item.length = strconv.FormatInt(lenUs, 10)
		} else {
			item.length = "0"
		}
		if u := variantString(meta["xesam:url"]); u != "" && urlStr != nil {
			*urlStr = u
		}
	} else {
		item.length = "0"
	}

	var posVariant dbus.Variant
	if err := obj.StoreProperty("org.mpris.MediaPlayer2.Player.Position", &posVariant); err == nil {
		posUs := variantInt64(posVariant)
		item.pos = strconv.FormatInt(posUs, 10)
	} else {
		item.pos = "0"
	}

	return item
}

func getTargetMprisPlayer(conn *dbus.Conn, target string) string {
	if target != "" {
		if strings.HasPrefix(target, "org.mpris.MediaPlayer2.") {
			return target
		}
		return "org.mpris.MediaPlayer2." + target
	}
	players := listMprisPlayers(conn)
	if len(players) == 0 {
		return ""
	}
	bestScore := -1
	bestService := ""
	for _, p := range players {
		c := fetchMprisCandidate(conn, p, nil)
		score := 0
		switch c.state {
		case "Playing":
			score = 3
		case "Paused":
			score = 2
		case "Stopped":
			score = 0
		default:
			score = 1
		}
		if c.title != "" || c.artist != "" {
			score++
		}
		if score > bestScore {
			bestScore = score
			bestService = "org.mpris.MediaPlayer2." + p
		}
	}
	return bestService
}

func mediaPlayPauseDBus(player string) error {
	conn, err := getSessionBus()
	if err != nil {
		return err
	}
	target := getTargetMprisPlayer(conn, player)
	if target == "" {
		return fmt.Errorf("no mpris players available")
	}
	obj := conn.Object(target, "/org/mpris/MediaPlayer2")
	return obj.Call("org.mpris.MediaPlayer2.Player.PlayPause", 0).Err
}

func mediaNextDBus(player string) error {
	conn, err := getSessionBus()
	if err != nil {
		return err
	}
	target := getTargetMprisPlayer(conn, player)
	if target == "" {
		return fmt.Errorf("no mpris players available")
	}
	obj := conn.Object(target, "/org/mpris/MediaPlayer2")
	return obj.Call("org.mpris.MediaPlayer2.Player.Next", 0).Err
}

func mediaPreviousDBus(player string) error {
	conn, err := getSessionBus()
	if err != nil {
		return err
	}
	target := getTargetMprisPlayer(conn, player)
	if target == "" {
		return fmt.Errorf("no mpris players available")
	}
	obj := conn.Object(target, "/org/mpris/MediaPlayer2")
	return obj.Call("org.mpris.MediaPlayer2.Player.Previous", 0).Err
}

func mediaSeekByDBus(player string, seconds int) error {
	conn, err := getSessionBus()
	if err != nil {
		return err
	}
	target := getTargetMprisPlayer(conn, player)
	if target == "" {
		return fmt.Errorf("no mpris players available")
	}
	obj := conn.Object(target, "/org/mpris/MediaPlayer2")
	offsetUs := int64(seconds) * 1_000_000
	return obj.Call("org.mpris.MediaPlayer2.Player.Seek", 0, offsetUs).Err
}

func mediaSeekDBus(player string, targetSeconds int) error {
	conn, err := getSessionBus()
	if err != nil {
		return err
	}
	target := getTargetMprisPlayer(conn, player)
	if target == "" {
		return fmt.Errorf("no mpris players available")
	}
	obj := conn.Object(target, "/org/mpris/MediaPlayer2")

	var meta map[string]dbus.Variant
	targetUs := int64(targetSeconds) * 1_000_000
	if err := obj.StoreProperty("org.mpris.MediaPlayer2.Player.Metadata", &meta); err == nil && meta != nil {
		if trackIdVar, exists := meta["mpris:trackid"]; exists && trackIdVar.Value() != nil {
			var trackPath dbus.ObjectPath
			if op, ok := trackIdVar.Value().(dbus.ObjectPath); ok {
				trackPath = op
			} else if s, ok := trackIdVar.Value().(string); ok && s != "" {
				trackPath = dbus.ObjectPath(s)
			}
			if trackPath != "" && trackPath != "/org/mpris/MediaPlayer2/TrackList/NoTrack" {
				call := obj.Call("org.mpris.MediaPlayer2.Player.SetPosition", 0, trackPath, targetUs)
				if call.Err == nil {
					return nil
				}
			}
		}
	}

	// Fallback to relative Seek if SetPosition unsupported or no valid trackid
	var posVariant dbus.Variant
	if err := obj.StoreProperty("org.mpris.MediaPlayer2.Player.Position", &posVariant); err == nil {
		currUs := variantInt64(posVariant)
		deltaUs := targetUs - currUs
		return obj.Call("org.mpris.MediaPlayer2.Player.Seek", 0, deltaUs).Err
	}
	return fmt.Errorf("could not seek position on %s", target)
}

func mediaWatchDBus() int {
	conn, err := getSessionBus()
	if err != nil {
		fmt.Fprintln(os.Stderr, "Failed to connect to D-Bus session bus:", err)
		return 1
	}

	if err := conn.AddMatchSignal(
		dbus.WithMatchInterface("org.freedesktop.DBus.Properties"),
		dbus.WithMatchMember("PropertiesChanged"),
	); err != nil {
		fmt.Fprintln(os.Stderr, "Failed to add match for PropertiesChanged:", err)
	}

	if err := conn.AddMatchSignal(
		dbus.WithMatchInterface("org.mpris.MediaPlayer2.Player"),
		dbus.WithMatchMember("Seeked"),
	); err != nil {
		fmt.Fprintln(os.Stderr, "Failed to add match for Seeked:", err)
	}

	if err := conn.AddMatchSignal(
		dbus.WithMatchInterface("org.freedesktop.DBus"),
		dbus.WithMatchMember("NameOwnerChanged"),
		dbus.WithMatchSender("org.freedesktop.DBus"),
	); err != nil {
		fmt.Fprintln(os.Stderr, "Failed to add match for NameOwnerChanged:", err)
	}

	sigChan := make(chan *dbus.Signal, 64)
	conn.Signal(sigChan)

	fmt.Println("ready")

	for sig := range sigChan {
		if sig.Path == "/org/mpris/MediaPlayer2" && (sig.Name == "org.freedesktop.DBus.Properties.PropertiesChanged" || sig.Name == "org.mpris.MediaPlayer2.Player.Seeked") {
			if sig.Name == "org.freedesktop.DBus.Properties.PropertiesChanged" && len(sig.Body) > 0 {
				if iface, ok := sig.Body[0].(string); !ok || iface != "org.mpris.MediaPlayer2.Player" {
					continue
				}
			}
			fmt.Println("changed")
		} else if sig.Name == "org.freedesktop.DBus.NameOwnerChanged" && len(sig.Body) > 0 {
			if name, ok := sig.Body[0].(string); ok && strings.HasPrefix(name, "org.mpris.MediaPlayer2.") {
				fmt.Println("changed")
			}
		}
	}
	return 0
}
