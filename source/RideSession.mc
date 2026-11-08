import Toybox.Activity;
import Toybox.ActivityRecording;
import Toybox.Application;
import Toybox.Attention;
import Toybox.FitContributor;
import Toybox.Lang;
import Toybox.Position;
import Toybox.System;

// Wraps the FIT activity recording plus live GPS data.
class RideSession {
    private var _session as ActivityRecording.Session?;
    private var _batteryField as FitContributor.Field?;
    private var _speed as Float = 0.0;              // m/s, live from GPS
    private var _gpsQuality as Number = Position.QUALITY_NOT_AVAILABLE;
    private var _lastAlertMs as Number = 0;
    var lapCount as Number = 1;
    private var _speedLimitKmh as Number = 0;    // cached setting, 0 = off

    function initialize() {
        reloadSettings();
    }

    function reloadSettings() as Void {
        var v = Application.Properties.getValue("speedAlertKmh");
        _speedLimitKmh = v instanceof Number ? v : 0;
    }

    // ---- state ----
    function hasSession() as Boolean {
        return _session != null;
    }

    function isRecording() as Boolean {
        var s = _session;
        return s != null && s.isRecording();
    }

    // ---- control ----
    function start() as Void {
        if (_session == null) {
            var s = ActivityRecording.createSession({
                :name => "E-Skate",
                :sport => Activity.SPORT_GENERIC,
                :subSport => Activity.SUB_SPORT_GENERIC
            });
            _batteryField = s.createField("board_battery", 0, FitContributor.DATA_TYPE_UINT8,
                { :mesgType => FitContributor.MESG_TYPE_RECORD, :units => "%" });
            _session = s;
        }
        (_session as ActivityRecording.Session).start();
        vibe(1);
        tone(Attention.TONE_START);
    }

    function pause() as Void {
        var s = _session;
        if (s != null && s.isRecording()) {
            s.stop();
            vibe(2);
            tone(Attention.TONE_STOP);
        }
    }

    function lap() as Void {
        var s = _session;
        if (s != null && s.isRecording()) {
            s.addLap();
            lapCount++;
            vibe(1);
            tone(Attention.TONE_LAP);
        }
    }

    function save() as Void {
        var s = _session;
        if (s != null) {
            if (s.isRecording()) { s.stop(); }
            s.save();
            vibe(1);
            tone(Attention.TONE_SUCCESS);
            lapCount = 1;
            _session = null;
            _batteryField = null;
        }
    }

    function discard() as Void {
        var s = _session;
        if (s != null) {
            if (s.isRecording()) { s.stop(); }
            s.discard();
            lapCount = 1;
            _session = null;
            _batteryField = null;
        }
    }

    // Called by BoardLink when a battery value is decoded.
    function setBoardBattery(percent as Number) as Void {
        var f = _batteryField;
        if (f != null && isRecording()) {
            f.setData(percent);
        }
    }

    // ---- GPS ----
    function onPosition(info as Position.Info) as Void {
        _gpsQuality = info.accuracy;
        var spd = info.speed;
        _speed = (spd != null) ? spd.toFloat() : 0.0;
        checkSpeedAlert();
    }

    function gpsReady() as Boolean {
        return _gpsQuality >= Position.QUALITY_USABLE;
    }

    // ---- metrics (SI units) ----
    function speed() as Float {
        return _speed;
    }

    function distance() as Float {
        var i = sessionInfo();
        var d = i != null ? i.elapsedDistance : null;
        return d != null ? d.toFloat() : 0.0;
    }

    function timerMs() as Number {
        var i = sessionInfo();
        var t = i != null ? i.timerTime : null;
        return t != null ? t : 0;
    }

    function maxSpeed() as Float {
        var i = sessionInfo();
        var v = i != null ? i.maxSpeed : null;
        return v != null ? v.toFloat() : 0.0;
    }

    function avgSpeed() as Float {
        var i = sessionInfo();
        var v = i != null ? i.averageSpeed : null;
        return v != null ? v.toFloat() : 0.0;
    }

    function calories() as Number? {
        var i = sessionInfo();
        return i != null ? i.calories : null;
    }

    // meters
    function ascent() as Number? {
        var i = sessionInfo();
        return i != null ? i.totalAscent : null;
    }

    // Live wrist heart rate, available even before the ride is started.
    function heartRate() as Number? {
        var i = Activity.getActivityInfo();
        return i != null ? i.currentHeartRate : null;
    }

    function overSpeedLimit() as Boolean {
        return _speedLimitKmh > 0 && _speed * 3.6 >= _speedLimitKmh;
    }

    private function sessionInfo() as Activity.Info? {
        return hasSession() ? Activity.getActivityInfo() : null;
    }

    // ---- helpers ----
    private function checkSpeedAlert() as Void {
        if (!overSpeedLimit()) {
            return;
        }
        var now = System.getTimer();
        if (now - _lastAlertMs > 5000) {
            _lastAlertMs = now;
            vibe(3);
        }
    }

    // Respects the watch's own "Tones" setting.
    private function tone(t as Attention.Tone) as Void {
        if (Attention has :playTone) {
            Attention.playTone(t);
        }
    }

    private function vibe(count as Number) as Void {
        if (!(Attention has :vibrate)) {
            return;
        }
        var pattern = [] as Array<Attention.VibeProfile>;
        for (var i = 0; i < count; i++) {
            pattern.add(new Attention.VibeProfile(100, 250));
            pattern.add(new Attention.VibeProfile(0, 150));
        }
        Attention.vibrate(pattern);
    }
}
