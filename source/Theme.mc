import Toybox.Graphics;
import Toybox.Lang;
import Toybox.System;
import Toybox.Time;
import Toybox.Time.Gregorian;
import Toybox.WatchUi;

// Colors matching Garmin's native activity screens: light (white background)
// on MIP watches, dark on AMOLED. Can be forced with the "theme" setting.
module Theme {
    enum {
        AUTO = 0,
        LIGHT = 1,
        DARK = 2
    }

    var _light as Boolean? = null;

    function reload() as Void {
        _light = null;
    }

    function isLight() as Boolean {
        var l = _light;
        if (l == null) {
            var t = Config.number("theme", AUTO);
            if (t == AUTO) {
                // AMOLED watches need burn-in protection and use dark screens.
                var s = System.getDeviceSettings();
                l = !((s has :requiresBurnInProtection) && s.requiresBurnInProtection);
            } else {
                l = (t == LIGHT);
            }
            _light = l;
        }
        return l;
    }

    function bg() as Number { return isLight() ? Graphics.COLOR_WHITE : Graphics.COLOR_BLACK; }
    function fg() as Number { return isLight() ? Graphics.COLOR_BLACK : Graphics.COLOR_WHITE; }
    function label() as Number { return isLight() ? Graphics.COLOR_DK_GRAY : Graphics.COLOR_LT_GRAY; }
    function line() as Number { return isLight() ? Graphics.COLOR_BLACK : Graphics.COLOR_DK_GRAY; }
    function good() as Number { return isLight() ? Graphics.COLOR_DK_GREEN : Graphics.COLOR_GREEN; }
    function warn() as Number { return Graphics.COLOR_ORANGE; }
    function bad() as Number { return isLight() ? Graphics.COLOR_DK_RED : Graphics.COLOR_RED; }

    // The round sub-screen in the corner of Instinct watches, or null.
    function subscreen() as Graphics.BoundingBox? {
        if (WatchUi has :getSubscreen) {
            return WatchUi.getSubscreen();
        }
        return null;
    }

    // Time of day in the sub-screen, white on black like native Instinct
    // activities. Drawn last so nothing under it shows through.
    function drawSubClock(dc as Graphics.Dc) as Void {
        var sub = subscreen();
        if (sub == null) { return; }
        var c = Gregorian.info(Time.now(), Time.FORMAT_SHORT);
        var r = (sub.width < sub.height ? sub.width : sub.height) / 2;
        var cx = sub.x + sub.width / 2;
        var cy = sub.y + sub.height / 2;
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.fillCircle(cx, cy, r + 1);
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, cy, Graphics.FONT_XTINY, c.hour.format("%d") + ":" + c.min.format("%02d"),
                    Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }
}
