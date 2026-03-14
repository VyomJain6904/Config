#!/usr/bin/env python3
"""
control-center.py — instant Control Center daemon
Start daemon:  /usr/bin/python3 ~/.config/polybar/scripts/control-center.py --daemon
Toggle:        /usr/bin/python3 ~/.config/polybar/scripts/control-center.py
Add to i3 config for instant-open: exec --no-startup-id /usr/bin/python3 ~/.config/polybar/scripts/control-center.py --daemon
"""

import gi, subprocess, os, sys, json, re, threading, signal, socket, time

for _v in ("4.1", "4.0"):
    try:
        gi.require_version("Gtk", "3.0")
        gi.require_version("Gdk", "3.0")
        gi.require_version("WebKit2", _v)
        from gi.repository import Gtk, Gdk, WebKit2, GLib

        break
    except Exception:
        continue
else:
    sys.exit("ERROR: install webkit2gtk + python-gobject")

SOCK = "/tmp/cc2.sock"
DAEMON = "/tmp/cc2.daemon"
SCRIPT = os.path.abspath(__file__)
SCRIPT_DIR = os.path.dirname(SCRIPT)
HTML_PATH = os.path.join(SCRIPT_DIR, "control-center.html")
GO_FAST_BIN = os.path.join(SCRIPT_DIR, "go", "bin", "cc-fast")


def try_toggle():
    try:
        s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        s.settimeout(0.2)
        s.connect(SOCK)
        s.sendall(b"toggle")
        s.close()
        return True
    except:
        return False


def sh(cmd, fb=""):
    try:
        return (
            subprocess.check_output(
                cmd, shell=True, stderr=subprocess.DEVNULL, timeout=4
            )
            .decode()
            .strip()
        )
    except:
        return fb


def sh_bg(cmd):
    subprocess.Popen(
        cmd, shell=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL
    )


# ── Fast data: local reads only, <30ms ───────────────────────────
def fast_data_go():
    if not os.path.isfile(GO_FAST_BIN) or not os.access(GO_FAST_BIN, os.X_OK):
        return None
    try:
        out = subprocess.check_output(
            [GO_FAST_BIN], stderr=subprocess.DEVNULL, timeout=1.3
        ).decode()
        d = json.loads(out)
        req = [
            "bp",
            "bs",
            "bc",
            "bf",
            "temp",
            "vol",
            "mute",
            "bri",
            "wss",
            "won",
            "bton",
        ]
        if not all(k in d for k in req):
            return None
        d["wifi_networks"] = []
        d["bt_devices"] = []
        d["sound_outputs"] = []
        return d
    except:
        return None


def fast_data():
    go_data = fast_data_go()
    if go_data is not None:
        return go_data

    d = {}
    bat = next(
        (
            b
            for b in ["BAT0", "BAT1", "BAT"]
            if os.path.exists(f"/sys/class/power_supply/{b}/capacity")
        ),
        "",
    )
    d["bp"] = (
        int(sh(f"cat /sys/class/power_supply/{bat}/capacity", "0") or 0) if bat else 0
    )
    d["bs"] = (
        sh(f"cat /sys/class/power_supply/{bat}/status", "Unknown") if bat else "Unknown"
    )
    d["bc"] = d["bs"] == "Charging"
    d["bf"] = d["bs"] == "Full"

    # Temperature — try all thermal zones, pick highest non-zero
    temp = 0
    for z in range(10):
        p = f"/sys/class/thermal/thermal_zone{z}/temp"
        if not os.path.exists(p):
            continue
        try:
            raw = int(open(p).read().strip())
            if raw > 1000:  # valid reading
                t = raw // 1000
                if t > temp:
                    temp = t
        except:
            pass
    # Fallback: try hwmon
    if temp == 0:
        for line in sh(
            "cat /sys/class/hwmon/hwmon*/temp*_input 2>/dev/null", ""
        ).splitlines():
            try:
                t = int(line.strip()) // 1000
                if t > temp:
                    temp = t
            except:
                pass
    d["temp"] = temp

    vs = sh("pactl get-sink-volume @DEFAULT_SINK@", "")
    m = re.search(r"(\d+)%", vs)
    d["vol"] = int(m.group(1)) if m else 75
    d["mute"] = "yes" in sh("pactl get-sink-mute @DEFAULT_SINK@", "").lower()

    try:
        mx = int(sh("brightnessctl max", "100") or 100)
        cu = int(sh("brightnessctl get", "80") or 80)
        d["bri"] = int(cu * 100 / mx) if mx > 0 else 80
    except:
        d["bri"] = 80

    radio = sh("nmcli radio wifi", "enabled")
    d["won"] = "enabled" in radio.lower()
    d["wss"] = (
        sh(
            "nmcli -t -f active,ssid dev wifi 2>/dev/null | grep '^yes' | cut -d: -f2 | head -1",
            "",
        )
        if d["won"]
        else ""
    )
    d["bton"] = (
        sh("bluetoothctl show 2>/dev/null | grep -c 'Powered: yes'", "0").strip() == "1"
    )

    d["wifi_networks"] = []
    d["bt_devices"] = []
    d["sound_outputs"] = []
    return d


def scan_wifi_networks():
    cur = sh(
        "nmcli -t -f active,ssid dev wifi 2>/dev/null | grep '^yes' | cut -d: -f2 | head -1",
        "",
    )
    nets, seen = [], set()
    raw = sh("nmcli -t -f SSID,SIGNAL dev wifi 2>/dev/null | head -14", "")
    for line in raw.splitlines():
        idx = line.rfind(":")
        if idx < 0:
            continue
        ssid = line[:idx].strip()
        sig_s = line[idx + 1 :].strip()
        if not ssid or ssid in seen:
            continue
        seen.add(ssid)
        try:
            sig = int(sig_s)
        except:
            sig = 0
        bars = 4 if sig >= 75 else 3 if sig >= 50 else 2 if sig >= 25 else 1
        nets.append({"ssid": ssid, "signal": bars, "connected": ssid == cur})
    return nets or [{"ssid": "No networks found", "signal": 0, "connected": False}]


def scan_bt_devices():
    devs = []
    for line in sh("bluetoothctl devices 2>/dev/null", "").splitlines():
        p = line.split(" ", 2)
        if len(p) < 3:
            continue
        mac, name = p[1], p[2].strip()
        if not name:
            continue
        conn = (
            sh(
                f"bluetoothctl info {mac} 2>/dev/null | grep -c 'Connected: yes'", "0"
            ).strip()
            == "1"
        )
        nl = name.lower()
        if any(
            x in nl
            for x in ["airpod", "headphone", "bud", "earphone", "wh-", "qc", "jabra"]
        ):
            t = "headphones"
        elif any(x in nl for x in ["speaker", "jbl", "bose", "flip", "charge"]):
            t = "speaker"
        elif any(x in nl for x in ["mouse", "trackpad"]):
            t = "mouse"
        elif any(x in nl for x in ["iphone", "android", "phone", "galaxy", "pixel"]):
            t = "phone"
        else:
            t = "default"
        devs.append({"name": name, "type": t, "connected": conn})
    return devs or [
        {"name": "No paired devices", "type": "default", "connected": False}
    ]


def scan_sound_outputs():
    outs = []
    dft = sh("pactl get-default-sink", "")
    for line in sh("pactl list sinks short 2>/dev/null", "").splitlines():
        ps = line.split()
        if len(ps) < 2:
            continue
        sn = ps[1]
        state = ps[4] if len(ps) > 4 else ""
        desc = sh(
            f"pactl list sinks 2>/dev/null | grep -A6 'Name: {sn}$' | grep 'Description:' | head -1 | cut -d: -f2-",
            "",
        ).strip()
        if not desc:
            desc = sn
        desc = re.sub(r"^(Built-in |Analog |Digital |Family |HD )", "", desc).strip()
        desc = desc[:36]
        outs.append({"name": sn, "desc": desc, "active": sn == dft, "state": state})
    return outs or [
        {
            "name": "default",
            "desc": "Default Output",
            "active": True,
            "state": "RUNNING",
        }
    ]


# ── Slow data: network scans, parallel threads ────────────────────
def slow_data():
    results = {
        "wifi_networks": [
            {"ssid": "No networks found", "signal": 0, "connected": False}
        ],
        "bt_devices": [
            {"name": "No paired devices", "type": "default", "connected": False}
        ],
        "sound_outputs": [
            {
                "name": "default",
                "desc": "Default Output",
                "active": True,
                "state": "RUNNING",
            }
        ],
    }

    def get_wifi():
        results["wifi_networks"] = scan_wifi_networks()

    def get_bt():
        results["bt_devices"] = scan_bt_devices()

    def get_sound():
        results["sound_outputs"] = scan_sound_outputs()

    threads = [
        threading.Thread(target=get_wifi, daemon=True),
        threading.Thread(target=get_bt, daemon=True),
        threading.Thread(target=get_sound, daemon=True),
    ]
    for t in threads:
        t.start()
    for t in threads:
        t.join(timeout=5)

    return results


def init_js(d):
    return f"""
window.__exec=function(c){{window.webkit.messageHandlers.exec.postMessage(c);}};
window.WIFI_NETWORKS={json.dumps(d.get("wifi_networks", []))};
window.BT_DEVICES={json.dumps(d.get("bt_devices", []))};
window.SOUND_OUTPUTS={json.dumps(d.get("sound_outputs", []))};
window.addEventListener('DOMContentLoaded',function(){{
  if(typeof CC==='function') CC(
    {d["bp"]},{json.dumps(d["bs"])},
    {"true" if d["bc"] else "false"},
    {"true" if d["bf"] else "false"},
    {d["temp"]},{d["vol"]},
    {"true" if d["mute"] else "false"},
    {d["bri"]},
    {json.dumps(d["wss"])},
    {"true" if d["won"] else "false"},
    {"true" if d["bton"] else "false"}
  );
}});
"""


class Daemon:
    def __init__(self):
        self.visible = False
        d = fast_data()

        # Start slow scan immediately in background
        self._slow_cache = {}
        threading.Thread(target=self._bg_slow_scan, daemon=True).start()

        self._build(d)
        threading.Thread(target=self._ipc, daemon=True).start()
        GLib.timeout_add(4000, self._refresh)

    def _bg_slow_scan(self):
        """Run slow scan in background, push to page when ready."""
        d = slow_data()
        self._slow_cache = d
        GLib.idle_add(self._push_slow, d)

    def _push_slow(self, d):
        self.js(
            f"window.WIFI_NETWORKS={json.dumps(d['wifi_networks'])};"
            f"window.BT_DEVICES={json.dumps(d['bt_devices'])};"
            f"window.SOUND_OUTPUTS={json.dumps(d['sound_outputs'])};"
        )
        return False

    def _build(self, d):
        display = Gdk.Display.get_default()
        mon = display.get_primary_monitor() or display.get_monitor(0)
        geo = mon.get_geometry()
        scale = mon.get_scale_factor()
        sw = geo.width * scale
        W = 312
        H = 356
        BAR = 28
        self._bar_y = BAR + 2
        self._win_w = W
        self._win_h = H

        self.win = Gtk.Window(type=Gtk.WindowType.TOPLEVEL)
        self.win.set_default_size(W, H)
        self.win.move(sw - W - 6, self._bar_y)
        self.win.set_decorated(False)
        self.win.set_resizable(False)
        self.win.set_keep_above(True)
        self.win.set_skip_taskbar_hint(True)
        self.win.set_skip_pager_hint(True)
        self.win.set_type_hint(Gdk.WindowTypeHint.POPUP_MENU)
        self.win.set_accept_focus(False)  # prevent focus-loss close
        self.win.set_app_paintable(True)

        screen = Gdk.Screen.get_default()
        vis = screen.get_rgba_visual()
        if vis:
            self.win.set_visual(vis)
        self.win.connect("draw", self._draw)
        self.win.connect("key-press-event", self._key)

        cfg = WebKit2.Settings()
        cfg.set_enable_javascript(True)
        cfg.set_enable_developer_extras(False)
        try:
            cfg.set_hardware_acceleration_policy(
                WebKit2.HardwareAccelerationPolicy.NEVER
            )
        except:
            pass

        self.wv = WebKit2.WebView()
        self.wv.set_settings(cfg)
        self.wv.set_background_color(Gdk.RGBA(0, 0, 0, 0))

        mgr = self.wv.get_user_content_manager()
        mgr.connect("script-message-received::exec", self._exec)
        mgr.register_script_message_handler("exec")
        mgr.add_script(
            WebKit2.UserScript(
                init_js(d),
                WebKit2.UserContentInjectedFrames.ALL_FRAMES,
                WebKit2.UserScriptInjectionTime.START,
                None,
                None,
            )
        )

        self.win.add(self.wv)
        self.wv.load_uri(f"file://{HTML_PATH}")
        self.win.realize()

    def _position_window(self, w=None, h=None):
        if w is not None:
            self._win_w = max(264, min(404, int(w)))
        if h is not None:
            self._win_h = max(262, min(540, int(h)))

        display = Gdk.Display.get_default()
        mon = display.get_primary_monitor() or display.get_monitor(0)
        geo = mon.get_geometry()
        scale = mon.get_scale_factor()
        sw = geo.width * scale

        self.win.set_default_size(self._win_w, self._win_h)
        self.win.resize(self._win_w, self._win_h)
        self.win.move(sw - self._win_w - 6, self._bar_y)

    def _draw(self, w, cr):
        cr.set_source_rgba(0, 0, 0, 0)
        cr.set_operator(1)
        cr.paint()
        return False

    def _key(self, w, ev):
        if ev.keyval == Gdk.KEY_Escape and self.visible:
            self._hide()

    def _exec(self, mgr, res):
        try:
            cmd = res.get_js_value().to_string()
        except:
            return
        if cmd == "__close__":
            GLib.idle_add(self._hide)
            return
        if cmd.startswith("__panel_size__:"):
            raw = cmd.split(":", 1)[1]
            parts = raw.split(",", 1)
            if len(parts) == 2:
                try:
                    w = int(parts[0].strip())
                    h = int(parts[1].strip())
                    GLib.idle_add(lambda: self._position_window(w, h) or False)
                except:
                    pass
            return
        if cmd.startswith("__refresh__:"):
            kind = cmd.split(":", 1)[1].strip()
            threading.Thread(
                target=self._scan_and_push, args=(kind,), daemon=True
            ).start()
            return
        sh_bg(cmd)

    def _scan_and_push(self, kind):
        if kind == "wifi":
            data = scan_wifi_networks()
            GLib.idle_add(
                lambda: self.js(
                    f"window.WIFI_NETWORKS={json.dumps(data)};if(window.activeMenu&&window.activeMenu.id==='wifimenu'){{buildWifi();}}"
                )
                or False
            )
        elif kind == "bt":
            data = scan_bt_devices()
            GLib.idle_add(
                lambda: self.js(
                    f"window.BT_DEVICES={json.dumps(data)};if(window.activeMenu&&window.activeMenu.id==='btmenu'){{buildBt();}}"
                )
                or False
            )
        elif kind == "sound":
            data = scan_sound_outputs()
            GLib.idle_add(
                lambda: self.js(
                    f"window.SOUND_OUTPUTS={json.dumps(data)};if(window.activeMenu&&window.activeMenu.id==='soundmenu'){{buildSound();}}"
                )
                or False
            )
        else:
            data = slow_data()
            self._slow_cache = data
            GLib.idle_add(self._push_slow, data)

    def _show(self):
        self.visible = True
        self.win.show_all()
        self.win.present()
        self.js("if(typeof closeMenus==='function'){closeMenus();}")
        # Push data after page loads (200ms grace for DOMContentLoaded)
        GLib.timeout_add(220, self._push_on_show)

    def _push_on_show(self):
        d = fast_data()
        self.js(f"""
          if(typeof CC==='function') CC(
            {d["bp"]},{json.dumps(d["bs"])},
            {"true" if d["bc"] else "false"},
            {"true" if d["bf"] else "false"},
            {d["temp"]},{d["vol"]},
            {"true" if d["mute"] else "false"},
            {d["bri"]},
            {json.dumps(d["wss"])},
            {"true" if d["won"] else "false"},
            {"true" if d["bton"] else "false"}
          );
        """)
        if self._slow_cache:
            self._push_slow(self._slow_cache)
        else:
            threading.Thread(target=self._lazy_scan, daemon=True).start()
        return False

    def _lazy_scan(self):
        if not self._slow_cache:
            d = slow_data()
            self._slow_cache = d
            GLib.idle_add(self._push_slow, d)

    def _hide(self):
        self.visible = False
        # Close any open submenus before hiding
        try:
            self.wv.run_javascript("closeMenus();", None, None, None)
        except:
            pass
        self.win.hide()

    def toggle(self):
        GLib.idle_add(self._show if not self.visible else self._hide)

    def js(self, code):
        try:
            self.wv.run_javascript(code, None, None, None)
        except:
            try:
                self.wv.evaluate_javascript(code, -1, None, None, None, None, None)
            except:
                pass

    def _refresh(self):
        def _bg():
            d = fast_data()
            GLib.idle_add(
                lambda: self.js(f"""
              if(typeof CC==='function') CC(
                {d["bp"]},{json.dumps(d["bs"])},
                {"true" if d["bc"] else "false"},
                {"true" if d["bf"] else "false"},
                {d["temp"]},{d["vol"]},
                {"true" if d["mute"] else "false"},
                {d["bri"]},
                {json.dumps(d["wss"])},
                {"true" if d["won"] else "false"},
                {"true" if d["bton"] else "false"}
              );
            """)
                or False
            )

        threading.Thread(target=_bg, daemon=True).start()
        return True

    def _ipc(self):
        srv = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        srv.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        srv.bind(SOCK)
        srv.listen(5)
        open(DAEMON, "w").write(str(os.getpid()))
        while True:
            try:
                conn, _ = srv.accept()
                msg = conn.recv(32).decode().strip()
                conn.close()
                if msg == "toggle":
                    self.toggle()
                elif msg == "quit":
                    GLib.idle_add(Gtk.main_quit)
                    break
            except:
                break


def run_daemon():
    sys.stdout = open(os.devnull, "w")
    sys.stderr = open(os.devnull, "w")

    d = Daemon()

    def _quit(*_):
        for f in (SOCK, DAEMON):
            try:
                os.remove(f)
            except:
                pass
        Gtk.main_quit()

    signal.signal(signal.SIGTERM, _quit)
    signal.signal(signal.SIGINT, _quit)
    try:
        Gtk.main()
    finally:
        _quit()


if __name__ == "__main__":
    is_daemon = "--daemon" in sys.argv or os.environ.get("CC_DAEMON") == "1"

    if is_daemon:
        run_daemon()
    else:
        if try_toggle():
            sys.exit(0)

        env = os.environ.copy()
        env["CC_DAEMON"] = "1"
        subprocess.Popen(
            [sys.executable, SCRIPT],
            env=env,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            start_new_session=True,
        )
        for _ in range(40):
            time.sleep(0.1)
            if try_toggle():
                break
