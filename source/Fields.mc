import Toybox.Lang;
import Toybox.System;
import Toybox.Time;
import Toybox.Time.Gregorian;
import Toybox.WatchUi;

// Data fields that can be placed on the configurable data screens.
// The numeric ids are stored in app settings, so never renumber them.
module Fields {
    enum {
        NONE = 0,
        DISTANCE = 1,
        RIDE_TIME = 2,
        HEART_RATE = 3,
        SPEED = 4,
        MAX_SPEED = 5,
        AVG_SPEED = 6,
        BOARD_BATTERY = 7,
        BOARD_VOLTAGE = 8,
        WATCH_BATTERY = 9,
        CLOCK = 10,
        CALORIES = 11,
        ASCENT = 12
    }
    const COUNT = 13;

    // Short labels drawn above the values.
    // Native-style labels: uppercase, no units.
    const LABELS = ["", "DISTANCE", "TIMER", "HEART RATE", "SPEED", "MAX SPEED", "AVG SPEED",
                    "BOARD BATT", "BOARD VOLT", "BATTERY", "TIME", "CALORIES", "ASCENT"];

    // Shorter labels for narrow cells (small screens).
    const SHORT = ["", "DIST", "TIMER", "HR", "SPEED", "MAX SPD", "AVG SPD",
                   "BRD BATT", "BRD VOLT", "BATT", "TIME", "CAL", "ASCENT"];

    // Full names, used in the on-watch settings menu.
    function name(id as Number) as String {
        var ids = [
            Rez.Strings.FieldNone, Rez.Strings.FieldDistance, Rez.Strings.FieldRideTime,
            Rez.Strings.FieldHeartRate, Rez.Strings.FieldSpeed, Rez.Strings.FieldMaxSpeed,
            Rez.Strings.FieldAvgSpeed, Rez.Strings.FieldBoardBattery, Rez.Strings.FieldBoardVoltage,
            Rez.Strings.FieldWatchBattery, Rez.Strings.FieldClock, Rez.Strings.FieldCalories,
            Rez.Strings.FieldAscent
        ];
        if (id < 0 || id >= COUNT) { id = NONE; }
        return WatchUi.loadResource(ids[id] as ResourceId) as String;
    }

    // Returns [value, unit]. Unit "%" is meant to be attached to the value;
    // any other unit is shown next to the label.
    function value(id as Number, ride as RideSession, board as BoardLink) as Array<String> {
        var metric = Units.isMetric();
        var speedUnit = metric ? "km/h" : "mph";
        if (id == DISTANCE) {
            return [Units.distance(ride.distance()).format("%.2f"), metric ? "km" : "mi"];
        } else if (id == RIDE_TIME) {
            return [Units.duration(ride.timerMs()), ""];
        } else if (id == HEART_RATE) {
            var hr = ride.heartRate();
            return [hr != null ? hr.format("%d") : "--", "bpm"];
        } else if (id == SPEED) {
            return [Units.speed(ride.speed()).toNumber().format("%d"), speedUnit];
        } else if (id == MAX_SPEED) {
            return [Units.speed(ride.maxSpeed()).format("%.1f"), speedUnit];
        } else if (id == AVG_SPEED) {
            return [Units.speed(ride.avgSpeed()).format("%.1f"), speedUnit];
        } else if (id == BOARD_BATTERY) {
            var b = board.battery;
            return b != null ? [b.format("%d"), "%"] : ["--", ""];
        } else if (id == BOARD_VOLTAGE) {
            var v = board.voltage;
            return [v != null ? v.format("%.1f") : "--", "V"];
        } else if (id == WATCH_BATTERY) {
            return [System.getSystemStats().battery.toNumber().format("%d"), "%"];
        } else if (id == CLOCK) {
            var c = Gregorian.info(Time.now(), Time.FORMAT_SHORT);
            return [c.hour.format("%02d") + ":" + c.min.format("%02d"), ""];
        } else if (id == CALORIES) {
            var cal = ride.calories();
            return [cal != null ? cal.format("%d") : "--", "kcal"];
        } else if (id == ASCENT) {
            var a = ride.ascent();
            return [a != null ? Units.elevation(a).format("%d") : "--", Units.isMetricElevation() ? "m" : "ft"];
        }
        return ["", ""];
    }
}
