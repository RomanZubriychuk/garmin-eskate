import Toybox.Graphics;
import Toybox.Lang;
import Toybox.System;
import Toybox.Timer;
import Toybox.WatchUi;

// Full-screen start/stop animation in the style of Garmin's own activities:
// an icon in the center and a colored border that sweeps around the screen
// edge. A fast timer runs only while the animation is on screen.
class Feedback {
    enum {
        NONE,
        START,
        PAUSE,
        LAP,
        SAVED,
        DISCARDED
    }

    const SWEEP_MS = 550;     // border runs around the edge
    const TOTAL_MS = 900;     // then holds briefly
    const FRAME_MS = 40;

    var kind as Number = NONE;
    var lap as Number = 0;
    private var _start as Number = 0;
    private var _timer as Timer.Timer?;
    private var _done as Method() as Void or Null;

    function initialize() {
    }

    function isActive() as Boolean {
        return kind != NONE;
    }

    // done is called when the animation ends (e.g. to open the pause menu).
    function play(k as Number, done as Method() as Void or Null) as Void {
        kind = k;
        _done = done;
        _start = System.getTimer();
        if (_timer == null) {
            var t = new Timer.Timer();
            t.start(method(:onFrame), FRAME_MS, true);
            _timer = t;
        }
        WatchUi.requestUpdate();
    }

    function onFrame() as Void {
        if (System.getTimer() - _start >= TOTAL_MS) {
            var done = _done;
            stop();
            if (done != null) {
                done.invoke();
            }
        }
        WatchUi.requestUpdate();
    }

    function stop() as Void {
        var t = _timer;
        if (t != null) { t.stop(); }
        _timer = null;
        _done = null;
        kind = NONE;
    }

    function draw(dc as Dc) as Void {
        var w = dc.getWidth();
        var h = dc.getHeight();
        var t = System.getTimer() - _start;
        var p = t >= SWEEP_MS ? 1.0 : t.toFloat() / SWEEP_MS;
        p = 1.0 - (1.0 - p) * (1.0 - p);   // ease-out

        var color = Theme.good();
        if (kind == PAUSE || kind == DISCARDED) {
            color = Theme.bad();
        } else if (kind == LAP) {
            color = Theme.lap();
        }

        dc.setColor(Theme.bg(), Theme.bg());
        dc.clear();
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        drawBorder(dc, w, h, p);
        drawIcon(dc, w / 2, h / 2, (w < h ? w : h) * 0.16, p);
    }

    // Border grows clockwise from 12 o'clock.
    private function drawBorder(dc as Dc, w as Number, h as Number, p as Float) as Void {
        var pen = w / 28 > 4 ? w / 28 : 4;
        dc.setPenWidth(pen);
        if (System.getDeviceSettings().screenShape == System.SCREEN_SHAPE_ROUND) {
            var r = w / 2 - pen / 2;
            if (p >= 0.999) {
                dc.drawCircle(w / 2, h / 2, r);
            } else if (p > 0.01) {
                dc.drawArc(w / 2, h / 2, r, Graphics.ARC_CLOCKWISE, 90, 90 - (360 * p).toNumber());
            }
        } else {
            // Rectangle: walk the perimeter clockwise from top center.
            var o = pen / 2;
            var pts = [[w / 2, o], [w - o, o], [w - o, h - o], [o, h - o], [o, o], [w / 2, o]];
            var total = 2 * (w + h) - 4 * pen;
            var left = total * p;
            for (var i = 0; i < pts.size() - 1 && left > 0; i++) {
                var a = pts[i];
                var b = pts[i + 1];
                var len = (b[0] - a[0]).abs() + (b[1] - a[1]).abs();
                var f = left >= len ? 1.0 : left / len;
                dc.drawLine(a[0], a[1], a[0] + (b[0] - a[0]) * f, a[1] + (b[1] - a[1]) * f);
                left -= len;
            }
        }
        dc.setPenWidth(1);
    }

    private function drawIcon(dc as Dc, cx as Number, cy as Number, s as Float, p as Float) as Void {
        var k = 0.7 + 0.3 * p;     // icon pops in slightly
        s = s * k;
        if (kind == START) {
            dc.fillPolygon([[cx - s * 0.7, cy - s], [cx - s * 0.7, cy + s], [cx + s, cy]]);
        } else if (kind == PAUSE) {
            dc.fillRectangle(cx - s * 0.75, cy - s, s * 0.5, s * 2);
            dc.fillRectangle(cx + s * 0.25, cy - s, s * 0.5, s * 2);
        } else if (kind == SAVED) {
            dc.setPenWidth((s / 3).toNumber());
            dc.drawLine(cx - s, cy, cx - s * 0.25, cy + s * 0.7);
            dc.drawLine(cx - s * 0.25, cy + s * 0.7, cx + s, cy - s * 0.7);
        } else if (kind == DISCARDED) {
            dc.setPenWidth((s / 3).toNumber());
            dc.drawLine(cx - s * 0.8, cy - s * 0.8, cx + s * 0.8, cy + s * 0.8);
            dc.drawLine(cx + s * 0.8, cy - s * 0.8, cx - s * 0.8, cy + s * 0.8);
        } else if (kind == LAP) {
            dc.drawText(cx, cy - s * 0.3, Graphics.FONT_NUMBER_MEDIUM, lap.format("%d"),
                        Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
            dc.drawText(cx, cy + s * 1.1, Graphics.FONT_SMALL, "LAP",
                        Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        }
        dc.setPenWidth(1);
    }
}
