import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Math;
import Toybox.System;
import Toybox.Timer;
import Toybox.WatchUi;

// Pages: up to two configurable data screens, then (optionally) the board
// status page and the BLE diagnostics page.
//
// Data screens copy the native Garmin 4-field activity page: a field on top,
// two side by side in the middle, one at the bottom, separated by lines;
// labels above values (below on the bottom field).
class ESkateView extends WatchUi.View {
    enum {
        PAGE_DATA1,
        PAGE_DATA2,
        PAGE_BOARD,
        PAGE_DIAG
    }

    const ROW1 = 0.36;   // top field ends here (fraction of height)
    const ROW2 = 0.68;   // middle row ends here
    const PAGE_HINT_MS = 2000;

    var fx as Feedback = new Feedback();
    private var _index as Number = 0;
    private var _pageChangedAt as Number = -100000;
    private var _ride as RideSession;
    private var _board as BoardLink;
    private var _timer as Timer.Timer?;
    private var _hintStart as Array<WatchUi.Drawable>? = null;
    private var _hintStop as Array<WatchUi.Drawable>? = null;
    private var _s as Dictionary<Symbol, String> = {} as Dictionary<Symbol, String>;

    function initialize(ride as RideSession, board as BoardLink) {
        View.initialize();
        _ride = ride;
        _board = board;
    }

    function onLayout(dc as Dc) as Void {
        var ids = {
            :ready => Rez.Strings.Ready, :paused => Rez.Strings.Paused,
            :board => Rez.Strings.Board, :battery => Rez.Strings.Battery,
            :off => Rez.Strings.BoardOff, :scan => Rez.Strings.BoardScanning, :notfound => Rez.Strings.BoardNotFound,
            :connecting => Rez.Strings.BoardConnecting, :connected => Rez.Strings.BoardConnected,
            :nodata => Rez.Strings.NoData, :packets => Rez.Strings.Packets, :gps => Rez.Strings.GpsWait
        };
        loadHints(dc);
        var keys = ids.keys();
        for (var i = 0; i < keys.size(); i++) {
            _s[keys[i] as Symbol] = WatchUi.loadResource(ids[keys[i]] as ResourceId) as String;
        }
    }

    function onShow() as Void {
        var t = new Timer.Timer();
        t.start(method(:onTick), 1000, true);
        _timer = t;
    }

    function onHide() as Void {
        var t = _timer;
        if (t != null) { t.stop(); }
        _timer = null;
    }

    function onTick() as Void {
        WatchUi.requestUpdate();
    }

    // Pages are rebuilt from settings every time, so changes apply immediately.
    private function pages() as Array<Number> {
        var p = [] as Array<Number>;
        if (Config.screenUsed(0)) { p.add(PAGE_DATA1); }
        if (Config.screenUsed(1)) { p.add(PAGE_DATA2); }
        if (Config.flag("boardEnabled")) {
            if (Config.flag("showBoardPage")) { p.add(PAGE_BOARD); }
            if (Config.flag("showDiagnostics")) { p.add(PAGE_DIAG); }
        }
        if (p.size() == 0) { p.add(PAGE_DATA1); }
        return p;
    }

    function nextPage(dir as Number) as Void {
        var n = pages().size();
        _index = ((_index + dir) % n + n) % n;
        _pageChangedAt = System.getTimer();
        WatchUi.requestUpdate();
    }

    // ---- drawing ----
    function onUpdate(dc as Dc) as Void {
        var p = pages();
        if (_index >= p.size()) { _index = 0; }

        if (fx.isActive()) {
            fx.draw(dc);
            return;
        }
        dc.setColor(Theme.bg(), Theme.bg());
        dc.clear();
        var page = p[_index];
        if (page == PAGE_DATA1) {
            drawDataScreen(dc, 0);
        } else if (page == PAGE_DATA2) {
            drawDataScreen(dc, 1);
        } else if (page == PAGE_BOARD) {
            drawBoard(dc);
        } else {
            drawDiagnostics(dc);
        }
        drawStatus(dc);
        drawPageIndicator(dc, p.size());
        drawStartHint(dc);
    }

    // Button hint layouts exist only on watches with Garmin's personality
    // library; monkey.jungle picks one of these two per device.
    (:hints)
    private function loadHints(dc as Dc) as Void {
        _hintStart = Rez.Layouts.HintStart(dc);
        _hintStop = Rez.Layouts.HintStop(dc);
    }

    (:noHints)
    private function loadHints(dc as Dc) as Void {
    }

    // Native button hint next to START: green = START begins the ride,
    // red = START stops it.
    private function drawStartHint(dc as Dc) as Void {
        var hint = _ride.isRecording() ? _hintStop : _hintStart;
        if (hint == null) { return; }
        for (var i = 0; i < hint.size(); i++) {
            hint[i].draw(dc);
        }
    }

    // Like native activities: no status while recording; before the start
    // a small "GPS" / "READY" chip at the top, "PAUSED" while paused.
    private function drawStatus(dc as Dc) as Void {
        if (_ride.isRecording()) { return; }
        var label;
        var color;
        if (!_ride.gpsReady()) {
            label = _s[:gps]; color = Theme.warn();
        } else if (_ride.hasSession()) {
            label = _s[:paused]; color = Theme.bad();
        } else {
            label = _s[:ready]; color = Theme.good();
        }
        if (label == null) { return; }
        var w = dc.getWidth();
        var font = Graphics.FONT_XTINY;
        var tw = dc.getTextWidthInPixels(label, font) + 16;
        var th = dc.getFontHeight(font);
        var y = dc.getHeight() * 0.035;
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle((w - tw) / 2, y, tw, th, th / 2);
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2, y + th / 2, font, label, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    private function drawDataScreen(dc as Dc, screen as Number) as Void {
        var w = dc.getWidth();
        var h = dc.getHeight();
        var main = Config.field(screen, 0);
        var left = Config.field(screen, 1);
        var right = Config.field(screen, 2);
        var bottom = Config.field(screen, 3);
        var hasMid = left != Fields.NONE || right != Fields.NONE;
        var split = left != Fields.NONE && right != Fields.NONE;

        // grid lines
        dc.setColor(Theme.line(), Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(2);
        if (main != Fields.NONE) { dc.drawLine(0, h * ROW1, w, h * ROW1); }
        if (bottom != Fields.NONE) { dc.drawLine(0, h * ROW2, w, h * ROW2); }
        if (split) { dc.drawLine(w / 2, h * ROW1, w / 2, h * ROW2); }
        dc.setPenWidth(1);

        // top field: label above value
        if (main != Fields.NONE) {
            drawField(dc, main, w / 2, h * 0.15, h * 0.26, w * 0.60, h * 0.19);
        }
        // middle fields
        if (hasMid) {
            var labelY = h * (ROW1 + 0.06);
            var valueY = h * (ROW1 + ROW2) / 2 + h * 0.04;
            if (split) {
                drawField(dc, left, w * 0.27, labelY, valueY, w * 0.44, h * 0.20);
                drawField(dc, right, w * 0.73, labelY, valueY, w * 0.44, h * 0.20);
            } else {
                drawField(dc, left != Fields.NONE ? left : right, w / 2, labelY, valueY, w * 0.80, h * 0.22);
            }
        }
        // bottom field: value above label, like native
        if (bottom != Fields.NONE) {
            drawField(dc, bottom, w / 2, h * 0.91, h * 0.80, w * 0.56, h * 0.17);
        }
    }

    private function drawField(dc as Dc, id as Number, x as Numeric, labelY as Numeric, valueY as Numeric,
                               maxW as Numeric, maxH as Numeric) as Void {
        var v = Fields.value(id, _ride, _board);
        text(dc, x, labelY, Graphics.FONT_XTINY, Theme.label(), label(id, v));
        var str = valueText(v);
        var font = fitFont(dc, str, maxW, maxH);
        text(dc, x, valueY, font, valueColor(id), str);
    }

    private function label(id as Number, v as Array<String>) as String {
        var unit = v[1];
        return (unit.equals("") || unit.equals("%")) ? Fields.LABELS[id] : Fields.LABELS[id] + " " + unit;
    }

    private function valueText(v as Array<String>) as String {
        return v[1].equals("%") ? v[0] + "%" : v[0];
    }

    private function valueColor(id as Number) as Number {
        if (id == Fields.SPEED && _ride.overSpeedLimit()) {
            return Theme.bad();
        }
        return Theme.fg();
    }

    // Largest native number font that fits; "%" isn't in number fonts, so
    // such values use regular fonts.
    private function fitFont(dc as Dc, str as String, maxW as Numeric, maxH as Numeric) as Graphics.FontType {
        var fonts = str.find("%") != null || str.find("-") == 0 && str.length() == 2
            ? [Graphics.FONT_LARGE, Graphics.FONT_MEDIUM, Graphics.FONT_SMALL] as Array<Graphics.FontType>
            : [Graphics.FONT_NUMBER_HOT, Graphics.FONT_NUMBER_MEDIUM, Graphics.FONT_NUMBER_MILD,
               Graphics.FONT_MEDIUM, Graphics.FONT_SMALL] as Array<Graphics.FontType>;
        for (var i = 0; i < fonts.size(); i++) {
            if (dc.getTextWidthInPixels(str, fonts[i]) <= maxW && dc.getFontHeight(fonts[i]) <= maxH * 1.25) {
                return fonts[i];
            }
        }
        return fonts[fonts.size() - 1];
    }

    // Native-style page indicator: dots on the left edge, shown briefly
    // after switching pages.
    private function drawPageIndicator(dc as Dc, count as Number) as Void {
        if (count < 2 || System.getTimer() - _pageChangedAt > PAGE_HINT_MS) { return; }
        var w = dc.getWidth();
        var h = dc.getHeight();
        var r = w / 2 - 10;
        var step = 7.0;   // degrees between dots
        for (var i = 0; i < count; i++) {
            var a = Math.toRadians(180 + (i - (count - 1) / 2.0) * step);
            var x = w / 2 + r * Math.cos(a);
            var y = h / 2 - r * Math.sin(a);
            dc.setColor(Theme.fg(), Graphics.COLOR_TRANSPARENT);
            if (i == _index) {
                dc.fillCircle(x, y, 4);
            } else {
                dc.drawCircle(x, y, 3);
            }
        }
    }

    private function drawBoard(dc as Dc) as Void {
        var w = dc.getWidth();
        var h = dc.getHeight();
        var b = _board;

        var status;
        var color = Theme.label();
        if (b.state == BoardLink.STATE_CONNECTED) {
            status = _s[:connected]; color = Theme.good();
        } else if (b.state == BoardLink.STATE_CONNECTING) {
            status = _s[:connecting]; color = Theme.warn();
        } else if (b.state == BoardLink.STATE_SCANNING || b.state == BoardLink.STATE_STARTING) {
            status = _s[:scan]; color = Theme.warn();
        } else if (b.state == BoardLink.STATE_WAITING) {
            status = _s[:notfound]; color = Theme.warn();
        } else {
            status = _s[:off];
        }
        var name = b.deviceName;
        text(dc, w / 2, h * 0.24, Graphics.FONT_SMALL, Theme.fg(), name != null ? name : _s[:board]);
        text(dc, w / 2, h * 0.33, Graphics.FONT_XTINY, color, status);

        dc.setColor(Theme.line(), Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(2);
        dc.drawLine(0, h * 0.40, w, h * 0.40);
        dc.drawLine(0, h * 0.70, w, h * 0.70);
        dc.setPenWidth(1);

        var bat = b.battery;
        text(dc, w / 2, h * 0.45, Graphics.FONT_XTINY, Theme.label(), _s[:battery]);
        text(dc, w / 2, h * 0.58, Graphics.FONT_LARGE, Theme.fg(), bat != null ? bat.format("%d") + "%" : "--");

        var v = b.voltage;
        text(dc, w / 2, h * 0.80, Graphics.FONT_MEDIUM, Theme.fg(), v != null ? v.format("%.1f") + " V" : "--");
        text(dc, w / 2, h * 0.90, Graphics.FONT_XTINY, Theme.label(), v != null ? "" : _s[:nodata]);
    }

    private function drawDiagnostics(dc as Dc) as Void {
        var w = dc.getWidth();
        var h = dc.getHeight();
        var b = _board;
        var rssi = b.rssi;
        text(dc, w / 2, h * 0.24, Graphics.FONT_XTINY, Theme.label(),
             "BLE  RSSI " + (rssi != null ? rssi.format("%d") : "--") +
             "  " + _s[:packets] + " " + b.packets.format("%d"));
        var y = h * 0.34;
        var n = b.services.size() < 4 ? b.services.size() : 4;
        for (var i = 0; i < n; i++) {
            text(dc, w / 2, y, Graphics.FONT_XTINY, Theme.fg(), b.services[i].substring(0, 8));
            y += h * 0.07;
        }
        var hex = b.lastPacketHex;
        if (hex.length() > 0) {
            // split the hex dump into two lines
            var cut = hex.length() > 25 ? 25 : hex.length();
            text(dc, w / 2, h * 0.72, Graphics.FONT_XTINY, Theme.good(), hex.substring(0, cut));
            if (hex.length() > cut) {
                text(dc, w / 2, h * 0.80, Graphics.FONT_XTINY, Theme.good(), hex.substring(cut, hex.length()));
            }
        }
    }

    private function text(dc as Dc, x as Numeric, y as Numeric, font as Graphics.FontType,
                          color as Number, str as String or Null) as Void {
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        dc.drawText(x, y, font, str != null ? str : "",
                    Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }
}
