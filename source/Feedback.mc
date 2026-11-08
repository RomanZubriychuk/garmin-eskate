import Toybox.Graphics;
import Toybox.Lang;
import Toybox.System;
import Toybox.WatchUi;

// Start/stop overlays copied frame by frame from Garmin's native activities
// (Fenix 8), drawn on top of whatever page is showing:
//   START   thick green ring + big filled play triangle (on the pre-start page)
//   RESUME  same as START, over the data page
//   PAUSE   thin red ring + red stop square, then the pause menu slides in
// Animated by the app's Ticker, which runs fast only while an overlay is visible.
class Feedback {
    enum {
        NONE,
        START,
        RESUME,
        PAUSE
    }

    const ACCENT_START = Graphics.COLOR_GREEN;   // native start ring / play
    var kind as Number = NONE;
    private var _start as Number = 0;
    private var _duration as Number = 0;
    private var _done as Method() as Void or Null;

    function initialize() {
    }

    function isActive() as Boolean {
        return kind != NONE;
    }

    // done is called when the overlay ends (e.g. to slide in the next view).
    function play(k as Number, done as Method() as Void or Null) as Void {
        kind = k;
        _done = done;
        _start = System.getTimer();
        _duration = durationOf(k);
        getApp().ticker.update();
        WatchUi.requestUpdate();
    }

    private function durationOf(k as Number) as Number {
        if (k == START) { return 1900; }
        if (k == RESUME) { return 800; }
        if (k == PAUSE) { return 1300; }
        return 900;
    }

    // Called by the Ticker on every tick. Returns true when the overlay
    // ended and handed over to the next view (no redraw then, so the slide
    // transition runs undisturbed).
    function onFrame(now as Number) as Boolean {
        if (kind != NONE && now - _start >= _duration) {
            var done = _done;
            stop();
            if (done != null) {
                done.invoke();
                return true;
            }
            WatchUi.requestUpdate();   // overlay gone
        }
        return false;
    }

    function stop() as Void {
        _done = null;
        kind = NONE;
    }

    function draw(dc as Dc) as Void {
        var w = dc.getWidth();
        var h = dc.getHeight();
        var cx = w / 2;
        var cy = h / 2;
        if (kind == START || kind == RESUME) {
            ring(dc, ACCENT_START, w / 30);
            playIcon(dc, cx, cy, w);
        } else if (kind == PAUSE) {
            ring(dc, Graphics.COLOR_RED, w / 45);
            var s = w * 0.33;
            dc.setColor(Graphics.COLOR_RED, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(cx - s / 2, cy - s / 2, s, s);
            dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_TRANSPARENT);
            dc.setPenWidth(2);
            dc.drawRectangle(cx - s / 2, cy - s / 2, s, s);
            dc.setPenWidth(1);
        }
    }

    // Ring flush with the screen edge: drawn twice as wide, centred on the
    // edge, so its outer half falls off-screen and no gap is left.
    static function ring(dc as Dc, color as Number, pen as Number) as Void {
        if (pen < 3) { pen = 3; }
        var w = dc.getWidth();
        var h = dc.getHeight();
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(pen * 2 + 4);
        if (System.getDeviceSettings().screenShape == System.SCREEN_SHAPE_ROUND) {
            dc.drawCircle(w / 2, h / 2, w / 2 + 2);
        } else {
            dc.drawRectangle(-2, -2, w + 4, h + 4);
        }
        dc.setPenWidth(1);
    }

    // Big play triangle, ~40% of the screen height, with a dark outline.
    private function playIcon(dc as Dc, cx as Number, cy as Number, w as Number) as Void {
        var hh = w * 0.20;
        var pts = [[cx - w * 0.13, cy - hh], [cx - w * 0.13, cy + hh], [cx + w * 0.19, cy]];
        dc.setColor(ACCENT_START, Graphics.COLOR_TRANSPARENT);
        dc.fillPolygon(pts);
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(2);
        for (var i = 0; i < 3; i++) {
            var a = pts[i];
            var b = pts[(i + 1) % 3];
            dc.drawLine(a[0], a[1], b[0], b[1]);
        }
        dc.setPenWidth(1);
    }
}
