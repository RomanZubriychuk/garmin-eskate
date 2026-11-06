import Toybox.Lang;
import Toybox.System;

module Units {
    function isMetric() as Boolean {
        return System.getDeviceSettings().distanceUnits == System.UNIT_METRIC;
    }

    // m/s -> km/h or mph
    function speed(mps as Float) as Float {
        return isMetric() ? mps * 3.6 : mps * 2.236936;
    }

    // m -> km or mi
    function distance(m as Float) as Float {
        return isMetric() ? m / 1000.0 : m / 1609.344;
    }

    function isMetricElevation() as Boolean {
        return System.getDeviceSettings().elevationUnits == System.UNIT_METRIC;
    }

    // m -> m or ft
    function elevation(m as Number) as Number {
        return isMetricElevation() ? m : (m * 3.28084).toNumber();
    }

    // ms -> "m:ss" or "h:mm:ss"
    function duration(ms as Number) as String {
        var total = ms / 1000;
        var h = total / 3600;
        var m = (total % 3600) / 60;
        var s = total % 60;
        if (h > 0) {
            return h.format("%d") + ":" + m.format("%02d") + ":" + s.format("%02d");
        }
        return m.format("%d") + ":" + s.format("%02d");
    }
}
