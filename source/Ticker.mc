import Toybox.Lang;
import Toybox.System;
import Toybox.Timer;
import Toybox.WatchUi;

// The app's single UI timer (watches allow only a few timers per app).
// Ticks once a second to refresh the pages, fast while an overlay animates
// or a delayed step is pending, and runs those delayed steps.
class Ticker {
    const SLOW_MS = 1000;
    const FAST_MS = 50;

    private var _timer as Timer.Timer;
    private var _period as Number = 0;
    private var _jobs as Array<Array> = [] as Array<Array>;   // [dueMs, Method]
    private var _fastUntil as Number = 0;

    function initialize() {
        _timer = new Timer.Timer();
    }

    // Runs m once after ms milliseconds.
    function after(ms as Number, m as Method() as Void) as Void {
        _jobs.add([System.getTimer() + ms, m]);
        update();
    }

    // Ticks fast for the next ms milliseconds (e.g. a scroll animation).
    function fastFor(ms as Number) as Void {
        _fastUntil = System.getTimer() + ms;
        update();
    }

    // Re-evaluates the tick rate (call after an overlay starts or stops).
    function update() as Void {
        var fast = getApp().fx.isActive() || _jobs.size() > 0 || System.getTimer() < _fastUntil;
        var p = fast ? FAST_MS : SLOW_MS;
        if (p != _period) {
            _timer.stop();
            _timer.start(method(:onTick), p, true);
            _period = p;
        }
    }

    function stop() as Void {
        _timer.stop();
        _period = 0;
    }

    function onTick() as Void {
        var now = System.getTimer();
        var handedOver = getApp().fx.onFrame(now);
        if (_jobs.size() > 0) {
            var due = [] as Array<Method>;
            var keep = [] as Array<Array>;
            for (var i = 0; i < _jobs.size(); i++) {
                var j = _jobs[i];
                if (now >= (j[0] as Number)) { due.add(j[1] as Method); } else { keep.add(j); }
            }
            _jobs = keep;
            for (var i = 0; i < due.size(); i++) { due[i].invoke(); }
        }
        update();
        if (!handedOver) {
            WatchUi.requestUpdate();
        }
    }
}
