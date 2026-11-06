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
                    f.add((v instanceof Number && v >= 0 && v < Fields.COUNT) ? v : Fields.NONE);
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

    function setFlag(name as String, on as Boolean) as Void {
        Application.Properties.setValue(name, on);
        _flags.put(name, on);
    }
}
