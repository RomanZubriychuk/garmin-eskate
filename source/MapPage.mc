import Toybox.Graphics;
import Toybox.Math;
import Toybox.Lang;
import Toybox.Position;
import Toybox.System;
import Toybox.WatchUi;

// Map page, like the native activity map: the watch's own map with the
// ride's track, following the current position. Only on watches with maps
// (WatchUi has :MapTrackView). Buttons work as on the data pages.
class MapPage extends WatchUi.MapTrackView {
    var index as Number;
    private var _hasArea as Boolean = false;
    private var _lat as Double or Float = 0.0;    // area centre, radians
    private var _lon as Double or Float = 0.0;

    const SLIDE_MS = 280;

    // One map view for the whole app run: building it again on every visit
    // makes the watch load the map from scratch (seconds of black).
    private static var _shared as MapPage? = null;
    private var _cover as Graphics.BufferedBitmapReference? = null;   // previous page
    private var _coverDir as Number = 0;
    private var _coverStart as Number = 0;

    // cover: picture of the page being left; it slides off (up for dir 1,
    // down for -1) to uncover the map, like the native page change.
    static function show(ride as RideSession, index as Number,
                         cover as Graphics.BufferedBitmapReference?, dir as Number) as Void {
        var v = _shared;
        if (v == null) {
            v = new MapPage(index);
            _shared = v;
        }
        v.index = index;
        v.uncover(cover, dir);
        WatchUi.switchToView(v, new MapPageDelegate(ride, v), WatchUi.SLIDE_IMMEDIATE);
    }

    function uncover(cover as Graphics.BufferedBitmapReference?, dir as Number) as Void {
        _cover = cover;
        _coverDir = dir;
        _coverStart = System.getTimer();
        // only the slide of the old page; the map itself is left alone
        if (cover != null) { getApp().ticker.fastFor(SLIDE_MS + 80); }
    }

    function initialize(i as Number) {
        MapTrackView.initialize();
        index = i;
        setMapMode(WatchUi.MAP_MODE_PREVIEW);
        var ds = System.getDeviceSettings();
        setScreenVisibleArea(0, 0, ds.screenWidth, ds.screenHeight);
        centre();
    }

    // The map must have an area to show, or the system crashes it: ~400 m
    // around the current position. The page is only offered once a position
    // is known (ESkateView), and keeps the last area if it is lost.
    private function centre() as Void {
        var info = Position.getInfo();
        var loc = info.position;
        if (loc == null) { return; }
        var d = loc.toRadians();
        var dLat = 0.0000314;            // ~200 m in radians of latitude
        // Re-setting the area makes the map redraw from scratch (setting it
        // every second left it black), so it follows in ~15 m steps.
        var step = dLat * 15 / 200;
        if (_hasArea && (d[0] - _lat).abs() < step && (d[1] - _lon).abs() < step / Math.cos(d[0])) {
            return;
        }
        _hasArea = true;
        _lat = d[0];
        _lon = d[1];
        var dLon = dLat / Math.cos(d[0]);
        setMapVisibleArea(
            new Position.Location({ :latitude => d[0] + dLat, :longitude => d[1] - dLon, :format => :radians }),
            new Position.Location({ :latitude => d[0] - dLat, :longitude => d[1] + dLon, :format => :radians }));
    }

    private function drawCover(dc as Dc) as Void {
        var c = _cover;
        if (c == null) { return; }
        var t = (System.getTimer() - _coverStart).toFloat() / SLIDE_MS;
        if (t >= 1.0 || c.get() == null) {
            _cover = null;
            return;
        }
        var e = 1.0 - (1.0 - t) * (1.0 - t) * (1.0 - t);
        var shift = (dc.getHeight() * e).toNumber();
        dc.drawBitmap(0, _coverDir > 0 ? -shift : shift, c);
    }

    // While the map shows, the app's once-a-second redraw is skipped: every
    // redraw costs the map seconds (Garmin forum), and the watch moves the
    // position arrow and redraws the map by itself.
    function onShow() as Void {
        getApp().ticker.mapShown = true;
    }

    function onHide() as Void {
        getApp().ticker.mapShown = false;
    }

    function onUpdate(dc as Dc) as Void {
        centre();
        if (_hasArea) {
            MapTrackView.onUpdate(dc);
            drawCover(dc);
        } else {
            // no position yet: the map can't be drawn
            dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
            dc.clear();
            dc.drawText(dc.getWidth() / 2, dc.getHeight() / 2, Graphics.FONT_SMALL, "Waiting for GPS",
                        Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        }
        var fx = getApp().fx;
        if (fx.isActive()) {
            fx.draw(dc);
        }
    }
}

class MapPageDelegate extends WatchUi.BehaviorDelegate {
    private var _ride as RideSession;
    private var _view as MapPage;

    function initialize(ride as RideSession, view as MapPage) {
        BehaviorDelegate.initialize();
        _ride = ride;
        _view = view;
    }

    function onTap(evt as WatchUi.ClickEvent) as Boolean {
        return true;
    }

    // START: pause (stop overlay, then the pause menu), as on the data pages.
    function onSelect() as Boolean {
        var fx = getApp().fx;
        if (fx.isActive()) { return true; }
        if (_ride.isRecording()) {
            _ride.pause();
            fx.play(Feedback.PAUSE, method(:showPauseMenu));
        } else if (_ride.hasSession()) {
            showPauseMenu();
        } else {
            _ride.start();
            fx.play(Feedback.RESUME, null);
        }
        return true;
    }

    function showPauseMenu() as Void {
        PauseMenu.show(_ride);
    }

    function onBack() as Boolean {
        if (getApp().fx.isActive() || _ride.isRecording()) { return true; }
        if (_ride.hasSession()) {
            showPauseMenu();
            return true;
        }
        return false;
    }

    function onMenu() as Boolean {
        new SettingsMenu().open();
        return true;
    }

    function onNextPage() as Boolean {
        leave(1);
        return true;
    }

    function onPreviousPage() as Boolean {
        leave(-1);
        return true;
    }

    // Back to the data pages: the page after / before the map.
    private function leave(dir as Number) as Void {
        if (getApp().fx.isActive()) { return; }
        var n = ESkateView.pages().size();
        var i = ((_view.index + dir) % n + n) % n;
        var v = new ESkateView(_ride, getApp().board, i, true);
        WatchUi.switchToView(v, new ESkateDelegate(v, _ride), WatchUi.SLIDE_IMMEDIATE);
    }
}
