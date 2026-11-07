import Toybox.Graphics;
import Toybox.Lang;
import Toybox.System;
import Toybox.Time;
import Toybox.Time.Gregorian;
import Toybox.Timer;
import Toybox.WatchUi;

// Pages: up to two configurable data screens, then (optionally) the board
// status page and the BLE diagnostics page.
class ESkateView extends WatchUi.View {
    enum {
        PAGE_DATA1,
        PAGE_DATA2,
        PAGE_BOARD,
        PAGE_DIAG
    }

    enum {
        FLASH_NONE,
        FLASH_START,
        FLASH_LAP,
        FLASH_SAVED,
        FLASH_DISCARDED
    }
    const FLASH_MS = 1300;
    const FLASH_GROW_MS = 300;

    private var _index as Number = 0;
    private var _ride as RideSession;
    private var _board as BoardLink;
    private var _timer as Timer.Timer?;
    private var _flashTimer as Timer.Timer?;
    private var _flashKind as Number = FLASH_NONE;
    private var _flashStart as Number = 0;
    private var _s as Dictionary<Symbol, String> = {} as Dictionary<Symbol, String>;

    function initialize(ride as RideSession, board as BoardLink) {
        View.initialize();
        _ride = ride;
        _board = board;
    }

    function onLayout(dc as Dc) as Void {
        var ids = {
            :ready => Rez.Strings.Ready, :rec => Rez.Strings.Recording, :paused => Rez.Strings.Paused,
            :board => Rez.Strings.Board, :battery => Rez.Strings.Battery,
            :off => Rez.Strings.BoardOff, :scan => Rez.Strings.BoardScanning, :notfound => Rez.Strings.BoardNotFound,
            :connecting => Rez.Strings.BoardConnecting, :connected => Rez.Strings.BoardConnected,
            :nodata => Rez.Strings.NoData, :packets => Rez.Strings.Packets, :gps => Rez.Strings.GpsWait
        };
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
        stopFlash();
    }

    // Short animated confirmation, like the native "Timer Started" screen.
    // Runs a fast timer only while the animation is on screen.
    function flash(kind as Number) as Void {
        _flashKind = kind;
        _flashStart = System.getTimer();
        if (_flashTimer == null) {
            var t = new Timer.Timer();
            t.start(method(:onFlashTick), 50, true);
            _flashTimer = t;
        }
        WatchUi.requestUpdate();
    }

    function onFlashTick() as Void {
        if (System.getTimer() - _flashStart > FLASH_MS) {
            stopFlash();
        }
        WatchUi.requestUpdate();
    }

    private function stopFlash() as Void {
        var t = _flashTimer;
        if (t != null) { t.stop(); }
        _flashTimer = null;
        _flashKind = FLASH_NONE;
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
        WatchUi.requestUpdate();
    }

    // ---- drawing ----
    function onUpdate(dc as Dc) as Void {
        var p = pages();
        if (_index >= p.size()) { _index = 0; }

        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();
        if (_flashKind != FLASH_NONE) {
            drawFlash(dc);
            return;
        }
        drawHeader(dc);
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
        drawPageDots(dc, p.size());
        drawStartHint(dc);
    }

    // Colored arc next to the START button (upper right on round watches):
    // green = START begins the ride, red = START stops it.
    private function drawStartHint(dc as Dc) as Void {
        if (System.getDeviceSettings().screenShape != System.SCREEN_SHAPE_ROUND) {
            return;
        }
        var w = dc.getWidth();
        var pen = w / 40 > 4 ? w / 40 : 4;
        dc.setPenWidth(pen);
        dc.setColor(_ride.isRecording() ? Graphics.COLOR_RED : Graphics.COLOR_GREEN, Graphics.COLOR_TRANSPARENT);
        dc.drawArc(w / 2, dc.getHeight() / 2, w / 2 - pen / 2 - 1, Graphics.ARC_COUNTER_CLOCKWISE, 22, 38);
        dc.setPenWidth(1);
    }

    private function drawFlash(dc as Dc) as Void {
        var w = dc.getWidth();
        var h = dc.getHeight();
        var cx = w / 2;
        var cy = h * 0.44;
        var t = System.getTimer() - _flashStart;
        var k = t >= FLASH_GROW_MS ? 1.0 : 0.4 + 0.6 * t / FLASH_GROW_MS.toFloat();
        var r = (w * 0.22 * k).toNumber();

        var color = Graphics.COLOR_GREEN;
        var label = "Started";
        if (_flashKind == FLASH_LAP) {
            color = Graphics.COLOR_BLUE;
            label = "Lap " + _ride.lapCount.format("%d");
        } else if (_flashKind == FLASH_SAVED) {
            label = "Saved";
        } else if (_flashKind == FLASH_DISCARDED) {
            color = Graphics.COLOR_RED;
            label = "Discarded";
        }

        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(cx, cy, r);
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        var g = r * 0.45;
        if (_flashKind == FLASH_START) {
            dc.fillPolygon([[cx - g * 0.6, cy - g], [cx - g * 0.6, cy + g], [cx + g, cy]]);
        } else if (_flashKind == FLASH_LAP) {
            dc.drawText(cx, cy, Graphics.FONT_NUMBER_MEDIUM, _ride.lapCount.format("%d"),
                        Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        } else if (_flashKind == FLASH_SAVED) {
            dc.setPenWidth((r / 6).toNumber());
            dc.drawLine(cx - g, cy, cx - g * 0.2, cy + g * 0.7);
            dc.drawLine(cx - g * 0.2, cy + g * 0.7, cx + g, cy - g * 0.6);
        } else {
            dc.setPenWidth((r / 6).toNumber());
            dc.drawLine(cx - g * 0.8, cy - g * 0.8, cx + g * 0.8, cy + g * 0.8);
            dc.drawLine(cx + g * 0.8, cy - g * 0.8, cx - g * 0.8, cy + g * 0.8);
        }
        dc.setPenWidth(1);
        if (t >= FLASH_GROW_MS) {
            text(dc, cx, cy + w * 0.22 + dc.getFontHeight(Graphics.FONT_MEDIUM) * 0.7,
                 Graphics.FONT_MEDIUM, Graphics.COLOR_WHITE, label);
        }
    }

    // "14:16  REC" on one line; status colored.
    private function drawHeader(dc as Dc) as Void {
        var w = dc.getWidth();
        var h = dc.getHeight();
        var c = Gregorian.info(Time.now(), Time.FORMAT_SHORT);
        var clock = c.hour.format("%02d") + ":" + c.min.format("%02d");

        var label;
        var color;
        if (!_ride.gpsReady()) {
            label = _s[:gps]; color = Graphics.COLOR_ORANGE;
        } else if (_ride.isRecording()) {
            label = _s[:rec]; color = Graphics.COLOR_RED;
        } else if (_ride.hasSession()) {
            label = _s[:paused]; color = Graphics.COLOR_YELLOW;
        } else {
            label = _s[:ready]; color = Graphics.COLOR_GREEN;
        }
        if (label == null) { label = ""; }

        var font = Graphics.FONT_XTINY;
        var gap = dc.getTextWidthInPixels(" ", font) * 2;
        var cw = dc.getTextWidthInPixels(clock, font);
        var lw = dc.getTextWidthInPixels(label, font);
        var x = (w - cw - gap - lw) / 2;
        var y = h * 0.10;
        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(x, y, font, clock, Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        dc.drawText(x + cw + gap, y, font, label, Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    // Layout:   label (unit)
    //           MAIN VALUE
    //       left        right
    //          bottom line
    private function drawDataScreen(dc as Dc, screen as Number) as Void {
        var w = dc.getWidth();
        var h = dc.getHeight();
        var xtinyH = dc.getFontHeight(Graphics.FONT_XTINY);
        var y = h * 0.21;

        // main field
        var main = Config.field(screen, 0);
        if (main != Fields.NONE) {
            var v = Fields.value(main, _ride, _board);
            text(dc, w / 2, y, Graphics.FONT_XTINY, Graphics.COLOR_LT_GRAY, label(main, v));
            var font = fitFont(dc, valueText(v),
                [Graphics.FONT_NUMBER_THAI_HOT, Graphics.FONT_NUMBER_HOT,
                 Graphics.FONT_NUMBER_MEDIUM, Graphics.FONT_NUMBER_MILD] as Array<Graphics.FontType>,
                w * 0.80, h * 0.36);
            var fh = dc.getFontHeight(font);
            var vy = y + xtinyH / 2 + fh * 0.45;
            text(dc, w / 2, vy, font, valueColor(main), valueText(v));
            y = vy + fh * 0.45;
        } else {
            y = h * 0.45;
        }

        // left | right
        var left = Config.field(screen, 1);
        var right = Config.field(screen, 2);
        if (left != Fields.NONE || right != Fields.NONE) {
            var labelY = y + xtinyH * 0.6;
            var valueY = labelY + xtinyH * 0.5 + dc.getFontHeight(Graphics.FONT_MEDIUM) * 0.5;
            var both = left != Fields.NONE && right != Fields.NONE;
            if (left != Fields.NONE) {
                drawSmallField(dc, left, both ? w * 0.30 : w / 2, labelY, valueY, both ? w * 0.38 : w * 0.7);
            }
            if (right != Fields.NONE) {
                drawSmallField(dc, right, both ? w * 0.70 : w / 2, labelY, valueY, both ? w * 0.38 : w * 0.7);
            }
            y = valueY + dc.getFontHeight(Graphics.FONT_MEDIUM) * 0.5;
        }

        // bottom: "Speed 24 km/h"
        var bottom = Config.field(screen, 3);
        if (bottom != Fields.NONE) {
            var v = Fields.value(bottom, _ride, _board);
            var unit = v[1].equals("%") || v[1].equals("") ? "" : " " + v[1];
            var str = Fields.LABELS[bottom] + " " + valueText(v) + unit;
            var font = fitFont(dc, str, [Graphics.FONT_SMALL, Graphics.FONT_TINY, Graphics.FONT_XTINY] as Array<Graphics.FontType>,
                               w * 0.62, h);
            var by = y + dc.getFontHeight(font) * 0.6;
            if (by < h * 0.82) { by = h * 0.82; }
            text(dc, w / 2, by, font, valueColor(bottom), str);
        }
    }

    private function drawSmallField(dc as Dc, id as Number, x as Numeric, labelY as Numeric, valueY as Numeric,
                                    maxW as Numeric) as Void {
        var v = Fields.value(id, _ride, _board);
        text(dc, x, labelY, Graphics.FONT_XTINY, Graphics.COLOR_LT_GRAY, label(id, v));
        var font = fitFont(dc, valueText(v), [Graphics.FONT_MEDIUM, Graphics.FONT_SMALL, Graphics.FONT_TINY] as Array<Graphics.FontType>,
                           maxW, dc.getHeight());
        text(dc, x, valueY, font, valueColor(id), valueText(v));
    }

    private function label(id as Number, v as Array<String>) as String {
        var unit = v[1];
        return (unit.equals("") || unit.equals("%")) ? Fields.LABELS[id] : Fields.LABELS[id] + " " + unit;
    }

    private function valueText(v as Array<String>) as String {
        return v[1].equals("%") ? v[0] + "%" : v[0];
    }

    private function valueColor(id as Number) as Graphics.ColorType {
        if (id == Fields.SPEED && _ride.overSpeedLimit()) {
            return Graphics.COLOR_RED;
        }
        return Graphics.COLOR_WHITE;
    }

    // First font from the list whose rendering of str fits maxW x maxH.
    // Number fonts contain only digits and a few symbols, so "%" values
    // fall back to regular fonts.
    private function fitFont(dc as Dc, str as String, fonts as Array<Graphics.FontType>,
                             maxW as Numeric, maxH as Numeric) as Graphics.FontType {
        var isNumberFont = fonts[0] == Graphics.FONT_NUMBER_THAI_HOT;
        if (isNumberFont && str.find("%") != null) {
            fonts = [Graphics.FONT_LARGE, Graphics.FONT_MEDIUM] as Array<Graphics.FontType>;
        }
        for (var i = 0; i < fonts.size(); i++) {
            if (dc.getTextWidthInPixels(str, fonts[i]) <= maxW && dc.getFontHeight(fonts[i]) <= maxH) {
                return fonts[i];
            }
        }
        return fonts[fonts.size() - 1];
    }

    private function drawBoard(dc as Dc) as Void {
        var w = dc.getWidth();
        var h = dc.getHeight();
        var b = _board;

        var status;
        var color = Graphics.COLOR_LT_GRAY;
        if (b.state == BoardLink.STATE_CONNECTED) {
            status = _s[:connected]; color = Graphics.COLOR_GREEN;
        } else if (b.state == BoardLink.STATE_CONNECTING) {
            status = _s[:connecting]; color = Graphics.COLOR_YELLOW;
        } else if (b.state == BoardLink.STATE_SCANNING || b.state == BoardLink.STATE_STARTING) {
            status = _s[:scan]; color = Graphics.COLOR_YELLOW;
        } else if (b.state == BoardLink.STATE_WAITING) {
            status = _s[:notfound]; color = Graphics.COLOR_ORANGE;
        } else {
            status = _s[:off];
        }
        var name = b.deviceName;
        text(dc, w / 2, h * 0.28, Graphics.FONT_SMALL, Graphics.COLOR_WHITE, name != null ? name : _s[:board]);
        text(dc, w / 2, h * 0.37, Graphics.FONT_XTINY, color, status);

        var bat = b.battery;
        text(dc, w / 2, h * 0.52, Graphics.FONT_LARGE, Graphics.COLOR_WHITE,
             bat != null ? bat.format("%d") + "%" : "--");
        text(dc, w / 2, h * 0.64, Graphics.FONT_XTINY, Graphics.COLOR_LT_GRAY, _s[:battery]);

        var v = b.voltage;
        text(dc, w / 2, h * 0.76, Graphics.FONT_SMALL, Graphics.COLOR_WHITE,
             v != null ? v.format("%.1f") + " V" : _s[:nodata]);
    }

    private function drawDiagnostics(dc as Dc) as Void {
        var w = dc.getWidth();
        var h = dc.getHeight();
        var b = _board;
        var rssi = b.rssi;
        text(dc, w / 2, h * 0.28, Graphics.FONT_XTINY, Graphics.COLOR_LT_GRAY,
             "BLE  RSSI " + (rssi != null ? rssi.format("%d") : "--") +
             "  " + _s[:packets] + " " + b.packets.format("%d"));
        var y = h * 0.37;
        var n = b.services.size() < 4 ? b.services.size() : 4;
        for (var i = 0; i < n; i++) {
            text(dc, w / 2, y, Graphics.FONT_XTINY, Graphics.COLOR_WHITE, b.services[i].substring(0, 8));
            y += h * 0.07;
        }
        var hex = b.lastPacketHex;
        if (hex.length() > 0) {
            // split the hex dump into two lines
            var cut = hex.length() > 25 ? 25 : hex.length();
            text(dc, w / 2, h * 0.72, Graphics.FONT_XTINY, Graphics.COLOR_GREEN, hex.substring(0, cut));
            if (hex.length() > cut) {
                text(dc, w / 2, h * 0.80, Graphics.FONT_XTINY, Graphics.COLOR_GREEN, hex.substring(cut, hex.length()));
            }
        }
    }

    private function drawPageDots(dc as Dc, count as Number) as Void {
        if (count < 2) { return; }
        var w = dc.getWidth();
        var h = dc.getHeight();
        var r = 4;
        var gap = 14;
        var x0 = w / 2 - (count - 1) * gap / 2;
        for (var i = 0; i < count; i++) {
            dc.setColor(i == _index ? Graphics.COLOR_WHITE : Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(x0 + i * gap, h * 0.94, r);
        }
    }

    private function text(dc as Dc, x as Numeric, y as Numeric, font as Graphics.FontType,
                          color as Graphics.ColorType, str as String or Null) as Void {
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        dc.drawText(x, y, font, str != null ? str : "",
                    Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }
}
