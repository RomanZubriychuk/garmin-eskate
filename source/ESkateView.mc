import Toybox.Graphics;
import Toybox.Lang;
import Toybox.System;
import Toybox.Time;
import Toybox.Time.Gregorian;
import Toybox.Timer;
import Toybox.WatchUi;

// Page 0: ride (speed, distance, time). Page 1: board. Page 2: BLE diagnostics.
class ESkateView extends WatchUi.View {
    const PAGE_COUNT = 3;
    var page as Number = 0;

    private var _ride as RideSession;
    private var _board as BoardLink;
    private var _timer as Timer.Timer?;
    private var _s as Dictionary<Symbol, String> = {} as Dictionary<Symbol, String>;

    function initialize(ride as RideSession, board as BoardLink) {
        View.initialize();
        _ride = ride;
        _board = board;
    }

    function onLayout(dc as Dc) as Void {
        var ids = {
            :ready => Rez.Strings.Ready, :rec => Rez.Strings.Recording, :paused => Rez.Strings.Paused,
            :dist => Rez.Strings.Distance, :time => Rez.Strings.Time, :max => Rez.Strings.MaxSpeed,
            :avg => Rez.Strings.AvgSpeed, :board => Rez.Strings.Board, :battery => Rez.Strings.Battery,
            :off => Rez.Strings.BoardOff, :scan => Rez.Strings.BoardScanning,
            :connecting => Rez.Strings.BoardConnecting, :connected => Rez.Strings.BoardConnected,
            :nodata => Rez.Strings.NoData, :packets => Rez.Strings.Packets, :gps => Rez.Strings.GpsWait
        };
        var keys = ids.keys();
        for (var i = 0; i < keys.size(); i++) {
            _s[keys[i] as Symbol] = WatchUi.loadResource(ids[keys[i]] as WatchUi.ResourceId) as String;
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

    function nextPage(dir as Number) as Void {
        page = (page + dir + PAGE_COUNT) % PAGE_COUNT;
        WatchUi.requestUpdate();
    }

    // ---- drawing ----
    function onUpdate(dc as Dc) as Void {
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();
        drawHeader(dc);
        if (page == 0) {
            drawRide(dc);
        } else if (page == 1) {
            drawBoard(dc);
        } else {
            drawDiagnostics(dc);
        }
        drawPageDots(dc);
    }

    private function drawHeader(dc as Dc) as Void {
        var w = dc.getWidth();
        var h = dc.getHeight();
        var clock = Gregorian.info(Time.now(), Time.FORMAT_SHORT);
        text(dc, w / 2, h * 0.08, Graphics.FONT_XTINY, Graphics.COLOR_LT_GRAY,
             clock.hour.format("%02d") + ":" + clock.min.format("%02d"));

        var label;
        var color;
        if (_ride.isRecording()) {
            label = _s[:rec]; color = Graphics.COLOR_RED;
        } else if (_ride.hasSession()) {
            label = _s[:paused]; color = Graphics.COLOR_YELLOW;
        } else {
            label = _s[:ready]; color = Graphics.COLOR_GREEN;
        }
        if (!_ride.gpsReady()) {
            label = _s[:gps]; color = Graphics.COLOR_ORANGE;
        }
        text(dc, w / 2, h * 0.16, Graphics.FONT_XTINY, color, label);
    }

    private function drawRide(dc as Dc) as Void {
        var w = dc.getWidth();
        var h = dc.getHeight();
        var metric = Units.isMetric();

        text(dc, w / 2, h * 0.38, Graphics.FONT_NUMBER_THAI_HOT, Graphics.COLOR_WHITE,
             Units.speed(_ride.speed()).toNumber().format("%d"));
        text(dc, w / 2, h * 0.55, Graphics.FONT_TINY, Graphics.COLOR_LT_GRAY,
             metric ? "km/h" : "mph");

        // distance | time
        text(dc, w * 0.30, h * 0.66, Graphics.FONT_XTINY, Graphics.COLOR_LT_GRAY, _s[:dist]);
        text(dc, w * 0.30, h * 0.74, Graphics.FONT_MEDIUM, Graphics.COLOR_WHITE,
             Units.distance(_ride.distance()).format("%.2f") + (metric ? " km" : " mi"));
        text(dc, w * 0.70, h * 0.66, Graphics.FONT_XTINY, Graphics.COLOR_LT_GRAY, _s[:time]);
        text(dc, w * 0.70, h * 0.74, Graphics.FONT_MEDIUM, Graphics.COLOR_WHITE,
             Units.duration(_ride.timerMs()));

        // max | board battery
        var bat = _board.battery;
        text(dc, w / 2, h * 0.85, Graphics.FONT_XTINY, Graphics.COLOR_LT_GRAY,
             _s[:max] + " " + Units.speed(_ride.maxSpeed()).format("%.1f") +
             "   " + _s[:board] + " " + (bat != null ? bat.format("%d") + "%" : "--"));
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
        } else if (b.state == BoardLink.STATE_SCANNING) {
            status = _s[:scan]; color = Graphics.COLOR_YELLOW;
        } else {
            status = _s[:off];
        }
        var name = b.deviceName;
        text(dc, w / 2, h * 0.28, Graphics.FONT_SMALL, Graphics.COLOR_WHITE, name != null ? name : _s[:board]);
        text(dc, w / 2, h * 0.37, Graphics.FONT_XTINY, color, status);

        var bat = b.battery;
        text(dc, w / 2, h * 0.52, Graphics.FONT_NUMBER_MEDIUM, Graphics.COLOR_WHITE,
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

    private function drawPageDots(dc as Dc) as Void {
        var w = dc.getWidth();
        var h = dc.getHeight();
        var r = 4;
        var gap = 14;
        var x0 = w / 2 - (PAGE_COUNT - 1) * gap / 2;
        for (var i = 0; i < PAGE_COUNT; i++) {
            dc.setColor(i == page ? Graphics.COLOR_WHITE : Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
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
