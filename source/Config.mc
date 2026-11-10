import Toybox.Application;
import Toybox.Lang;

// Layout of the configurable data screens and on/off flags, stored in app
// settings (editable in Garmin Connect on the phone or from the on-watch
// menu). Values are cached in memory because the view reads them on every
// redraw; call reload() when settings change on the phone.
module Config {
    const SCREEN_COUNT = 2;
    const SLOT_COUNT = 4;   // main, left, right, bottom
    const SLOT_NAMES = ["Main", "Left", "Right", "Bottom"];

    // Board link (battery / voltage over Bluetooth) is hidden until the
    // board protocol is decoded: it gives no data yet.
    const BOARD = false;

    var _fields as Array<Number>? = null;
    var _flags as Dictionary<String, Boolean> = {} as Dictionary<String, Boolean>;

    function reload() as Void {
        _fields = null;
        _flags = {} as Dictionary<String, Boolean>;
    }

    function key(screen as Number, slot as Number) as String {
        return "s" + (screen + 1).format("%d") + SLOT_NAMES[slot];
    }

    function field(screen as Number, slot as Number) as Number {
        var f = _fields;
        if (f == null) {
            f = [] as Array<Number>;
            for (var s = 0; s < SCREEN_COUNT; s++) {
                for (var i = 0; i < SLOT_COUNT; i++) {
                    var v = Application.Properties.getValue(key(s, i));
                    var ok = v instanceof Number && v >= 0 && v < Fields.COUNT &&
                        (BOARD || (v != Fields.BOARD_BATTERY && v != Fields.BOARD_VOLTAGE));
                    f.add(ok ? v as Number : Fields.NONE);
                }
            }
            _fields = f;
        }
        return f[screen * SLOT_COUNT + slot];
    }

    function setField(screen as Number, slot as Number, id as Number) as Void {
        Application.Properties.setValue(key(screen, slot), id);
        var f = _fields;
        if (f != null) { f[screen * SLOT_COUNT + slot] = id; }
    }

    function screenUsed(screen as Number) as Boolean {
        for (var i = 0; i < SLOT_COUNT; i++) {
            if (field(screen, i) != Fields.NONE) { return true; }
        }
        return false;
    }

    function flag(name as String) as Boolean {
        var v = _flags.get(name);
        if (v == null) {
            v = Application.Properties.getValue(name) == true;
            _flags.put(name, v);
        }
        return v;
    }

    // Board link switched on (and available in this build).
    function board() as Boolean {
        return BOARD && flag("boardEnabled");
    }

    function setFlag(name as String, on as Boolean) as Void {
        Application.Properties.setValue(name, on);
        _flags.put(name, on);
    }

    // Plain numeric settings (theme, speed alert); read rarely, not cached.
    function number(name as String, def as Number) as Number {
        var v = Application.Properties.getValue(name);
        return v instanceof Number ? v : def;
    }

    function setNumber(name as String, v as Number) as Void {
        Application.Properties.setValue(name, v);
    }
}
