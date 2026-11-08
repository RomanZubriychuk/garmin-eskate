import Toybox.Graphics;
import Toybox.Lang;
import Toybox.System;

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
    function lap() as Number { return isLight() ? Graphics.COLOR_DK_BLUE : Graphics.COLOR_BLUE; }
}
