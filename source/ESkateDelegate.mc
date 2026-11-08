import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Math;
import Toybox.System;
import Toybox.WatchUi;

// Buttons on the data pages:
//   START          pause (stop overlay, then the pause menu slides in)
//   BACK           ignored while riding (no accidental laps), pause menu while paused
//   UP / DOWN      switch pages (swipe up / down on touch-only watches)
//   hold UP (MENU) settings menu
// Screen taps are ignored so a glove or a fall can't stop the ride.
class ESkateDelegate extends WatchUi.BehaviorDelegate {
    private var _view as ESkateView;
    private var _ride as RideSession;

    function initialize(view as ESkateView, ride as RideSession) {
        BehaviorDelegate.initialize();
        _view = view;
        _ride = ride;
    }

    function onTap(evt as WatchUi.ClickEvent) as Boolean {
        return true;
    }

    function onSelect() as Boolean {
        var fx = getApp().fx;
        if (fx.isActive()) {
            return true;   // ignore presses during the animation
        }
        if (_ride.isRecording()) {
            _ride.pause();
            fx.play(Feedback.PAUSE, method(:showPauseMenu));
        } else if (_ride.hasSession()) {
            showPauseMenu();
        } else {
            _ride.start();
            fx.play(Feedback.RESUME, null);
        }
        return true;
    }

    function onBack() as Boolean {
        var fx = getApp().fx;
        if (fx.isActive()) {
            return true;
        }
        if (_ride.isRecording()) {
            return true;
        }
        if (_ride.hasSession()) {
            showPauseMenu();
            return true;
        }
        return false;
    }

    function onMenu() as Boolean {
        new SettingsMenu().open();
        return true;
    }

    function onNextPage() as Boolean {
        switchPage(1);
        return true;
    }

    function onPreviousPage() as Boolean {
        switchPage(-1);
        return true;
    }

    // Native page loop: next page slides up from below, previous slides down.
    private function switchPage(dir as Number) as Void {
        if (getApp().fx.isActive()) { return; }
        _view.changePage(dir);
    }

    function showPauseMenu() as Void {
        PauseMenu.show(_ride);
    }
}

// Pause menu copied from native activities (Fenix 8 video): "TIMER" and the
// paused time on top, then Resume / Save / Discard rows (white icon, divider,
// white label), the focused row kept in the middle of the screen, and a thin
// red ring inside the screen edge that stays put while the list scrolls.
module PauseMenu {
    function show(ride as RideSession) as Void {
        var v = new PauseMenuView(ride);
        WatchUi.pushView(v, new PauseMenuDelegate(ride, v), WatchUi.SLIDE_LEFT);
    }
}

class PauseMenuView extends ScrollPage {
    enum {
        RESUME,
        SAVE,
        DISCARD,
        COUNT
    }

    const ITEM = 0.235;     // row height (fraction of screen height)

    private var _ride as RideSession;
    private var _timerLabel as String = "";
    private var _labels as Array<String> = [] as Array<String>;

    function initialize(ride as RideSession) {
        ScrollPage.initialize();
        _ride = ride;
        _maxFocus = COUNT - 1;
        jumpTo(RESUME);
    }

    function onLayout(dc as Dc) as Void {
        _timerLabel = WatchUi.loadResource(Rez.Strings.Timer) as String;
        _labels = [
            WatchUi.loadResource(Rez.Strings.Resume) as String,
            WatchUi.loadResource(Rez.Strings.Save) as String,
            WatchUi.loadResource(Rez.Strings.Discard) as String
        ];
    }

    // Title block height: the first row ends up in the middle of the screen.
    private function headH(h as Number) as Float {
        return h * (0.5 - ITEM / 2);
    }

    // Every row is centred on the screen when focused.
    function targetFor(f as Number, h as Number) as Float {
        return (f * h * ITEM).toFloat();
    }

    // Row under a tap at screen y, or -1.
    function rowAt(y as Number) as Number {
        var h = System.getDeviceSettings().screenHeight;
        var r = Math.floor((y + offset() - headH(h)) / (h * ITEM)).toNumber();
        return (r >= 0 && r < COUNT) ? r : -1;
    }

    function drawContent(dc as Dc, w as Number, h as Number, y0 as Float) as Void {
        var center = Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER;
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);

        // "TIMER" over m:ss with hundredths raised, like the native timer
        var hh = headH(h);
        dc.drawText(w / 2, y0 + hh * 0.36, Graphics.FONT_XTINY, _timerLabel, center);
        var ms = _ride.timerMs();
        var main = Units.duration(ms);
        var cs = ((ms % 1000) / 10).format("%02d");
        var big = Graphics.FONT_NUMBER_MILD;
        var bw = dc.getTextWidthInPixels(main, big);
        var x = w / 2 - bw / 2;
        var ty = y0 + hh * 0.70;
        dc.drawText(x, ty, big, main, Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
        dc.drawText(x + bw + 2, ty - dc.getFontHeight(big) / 4, Graphics.FONT_XTINY, cs,
                    Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);

        var ih = h * ITEM;
        var divX = w * 0.25;
        for (var i = 0; i < COUNT; i++) {
            var top = y0 + hh + i * ih;
            if (top > dc.getHeight() || top + ih < 0) { continue; }
            var cy = top + ih / 2;
            dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
            var icon = WatchUi.loadResource(i == RESUME ? Rez.Drawables.PauseResume
                : i == SAVE ? Rez.Drawables.PauseSave : Rez.Drawables.PauseDiscard) as WatchUi.BitmapResource;
            dc.drawBitmap(w * 0.14 - icon.getWidth() / 2, cy - icon.getHeight() / 2, icon);
            focusDivider(dc, divX, top, ih, i == focus);
            dc.drawText(divX + w * 0.035, cy, Graphics.FONT_TINY, _labels[i],
                        Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
        }
    }

    function drawOverlay(dc as Dc) as Void {
        insetRing(dc, Graphics.COLOR_RED, 1.0);
    }
}

// Ring flush with the screen edge (native pause menu / saving screens);
// frac < 1 draws only that share of it, clockwise from 12 o'clock.
function insetRing(dc as Dc, color as Number, frac as Float) as Void {
    var w = dc.getWidth();
    var h = dc.getHeight();
    // Drawn twice as wide, centred just outside the edge: the outer half
    // falls off-screen, so the ring sits flush with no gap. Visible ~w/40.
    var t = w / 40;
    if (t < 5) { t = 5; }
    dc.setColor(color, Graphics.COLOR_TRANSPARENT);
    dc.setPenWidth(t * 2 + 4);
    var r = (w < h ? w : h) / 2 + 2;
    if (System.getDeviceSettings().screenShape != System.SCREEN_SHAPE_ROUND && frac >= 1.0) {
        dc.drawRectangle(-2, -2, w + 4, h + 4);
    } else if (frac >= 1.0) {
        dc.drawCircle(w / 2, h / 2, r);
    } else if (frac > 0.005) {
        var end = 90 - (360 * frac).toNumber();
        dc.drawArc(w / 2, h / 2, r, Graphics.ARC_CLOCKWISE, 90, end);
    }
    dc.setPenWidth(1);
}

// Native row divider: a hairline running through all rows, thick on the
// focused row.
function focusDivider(dc as Dc, x as Float, top as Float, ih as Float, focused as Boolean) as Void {
    dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
    dc.setPenWidth(1);
    dc.drawLine(x, top, x, top + ih);
    if (focused) {
        var pen = dc.getWidth() / 90;
        if (pen < 3) { pen = 3; }
        dc.fillRectangle(x - pen / 2, top + ih * 0.05, pen, ih * 0.9);
    }
}

// UP / DOWN move between rows, START picks, BACK closes leaving the ride
// paused. On touch watches swipes scroll and a tap picks the row.
class PauseMenuDelegate extends WatchUi.BehaviorDelegate {
    private var _ride as RideSession;
    private var _view as PauseMenuView;

    function initialize(ride as RideSession, view as PauseMenuView) {
        BehaviorDelegate.initialize();
        _ride = ride;
        _view = view;
    }

    function onNextPage() as Boolean {
        _view.scrollTo(_view.focus + 1);
        return true;
    }

    function onPreviousPage() as Boolean {
        _view.scrollTo(_view.focus - 1);
        return true;
    }

    function onSelect() as Boolean {
        pick(_view.focus);
        return true;
    }

    function onTap(evt as WatchUi.ClickEvent) as Boolean {
        var r = _view.rowAt(evt.getCoordinates()[1]);
        if (r >= 0) { pick(r); }
        return true;
    }

    function onBack() as Boolean {
        WatchUi.popView(WatchUi.SLIDE_RIGHT);
        return true;
    }

    function onMenu() as Boolean {
        return true;
    }

    private function pick(r as Number) as Void {
        if (r == PauseMenuView.RESUME) {
            WatchUi.popView(WatchUi.SLIDE_RIGHT);
            _ride.start();
            getApp().fx.play(Feedback.RESUME, null);
        } else if (r == PauseMenuView.SAVE) {
            WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
            FinishFlow.run(_ride, true);
        } else if (r == PauseMenuView.DISCARD) {
            // Native activities confirm before throwing a ride away.
            WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
            DiscardConfirm.show(_ride);
        }
    }
}

// Discard confirmation. Watches with the personality library get the native
// delete confirmation (trash hint at START, keep hint at the lower left);
// older ones the standard WatchUi.Confirmation.
module DiscardConfirm {
    (:hints)
    function show(ride as RideSession) as Void {
        var v = new DiscardConfirmView();
        WatchUi.pushView(v, new DiscardConfirmKeys(ride, v), WatchUi.SLIDE_IMMEDIATE);
    }

    (:noHints)
    function show(ride as RideSession) as Void {
        WatchUi.pushView(new WatchUi.Confirmation(WatchUi.loadResource(Rez.Strings.DiscardPrompt) as String),
                         new DiscardConfirmDelegate(ride), WatchUi.SLIDE_IMMEDIATE);
    }

    function discard(ride as RideSession) as Void {
        FinishFlow.run(ride, false);
    }

    function keep(ride as RideSession) as Void {
        PauseMenu.show(ride);
    }
}

(:hints)
class DiscardConfirmView extends WatchUi.View {
    function initialize() {
        View.initialize();
    }

    function onLayout(dc as Dc) as Void {
        setLayout(Rez.Layouts.DiscardConfirm(dc));
    }

    function onUpdate(dc as Dc) as Void {
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
        dc.clear();
        View.onUpdate(dc);
    }

    // True when (x, y) hits the given hint icon (with a generous margin).
    function hits(id as String, x as Number, y as Number) as Boolean {
        var d = findDrawableById(id);
        if (d == null) { return false; }
        var m = 30;
        return x >= d.locX - m && x <= d.locX + d.width + m && y >= d.locY - m && y <= d.locY + d.height + m;
    }
}

// START (next to the trash hint) discards; DOWN or BACK keeps the ride.
// On touch watches tapping the trash / keep hint does the same.
(:hints)
class DiscardConfirmKeys extends WatchUi.BehaviorDelegate {
    private var _ride as RideSession;
    private var _view as DiscardConfirmView;

    function initialize(ride as RideSession, view as DiscardConfirmView) {
        BehaviorDelegate.initialize();
        _ride = ride;
        _view = view;
    }

    function onKey(evt as WatchUi.KeyEvent) as Boolean {
        var key = evt.getKey();
        if (key == WatchUi.KEY_ENTER) {
            discard();
        } else if (key == WatchUi.KEY_ESC || key == WatchUi.KEY_DOWN) {
            keep();
        }
        return true;   // nothing else does anything here
    }

    function onTap(evt as WatchUi.ClickEvent) as Boolean {
        var xy = evt.getCoordinates();
        if (_view.hits("deleteIcon", xy[0], xy[1])) {
            discard();
        } else if (_view.hits("keepIcon", xy[0], xy[1])) {
            keep();
        }
        return true;
    }

    private function discard() as Void {
        WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
        DiscardConfirm.discard(_ride);
    }

    private function keep() as Void {
        WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
        DiscardConfirm.keep(_ride);
    }
}

(:noHints)
class DiscardConfirmDelegate extends WatchUi.ConfirmationDelegate {
    private var _ride as RideSession;

    function initialize(ride as RideSession) {
        ConfirmationDelegate.initialize();
        _ride = ride;
    }

    // The confirmation pops itself after this returns, so the next screen
    // is shown a moment later.
    function onResponse(response as WatchUi.Confirm) as Boolean {
        getApp().ticker.after(50, response == WatchUi.CONFIRM_YES ? method(:discard) : method(:back));
        return true;
    }

    function discard() as Void {
        DiscardConfirm.discard(_ride);
    }

    function back() as Void {
        DiscardConfirm.keep(_ride);
    }
}

// "Saving" / "Discarding" with a thin red ring filling up, then
// "Ride Saved" / "Ride Discarded" with a full green ring, then back to the
// pre-start page, like native activities.
class FinishFlow {
    const BUSY_MS = 1200;
    const DONE_MS = 1300;

    private var _ride as RideSession;
    private var _save as Boolean;
    private var _view as FinishView?;

    // Kept alive here while the flow runs (timers alone don't hold it).
    static var current as FinishFlow?;

    static function run(ride as RideSession, save as Boolean) as Void {
        var f = new FinishFlow(ride, save);
        current = f;
        f.begin();
    }

    function initialize(ride as RideSession, save as Boolean) {
        _ride = ride;
        _save = save;
    }

    function begin() as Void {
        var label = WatchUi.loadResource(_save ? Rez.Strings.Saving : Rez.Strings.Discarding) as String;
        var v = new FinishView(label, BUSY_MS);
        _view = v;
        WatchUi.switchToView(v, new BusyDelegate(), WatchUi.SLIDE_IMMEDIATE);
        later(method(:finish), BUSY_MS);
    }

    function finish() as Void {
        if (_save) { _ride.save(); } else { _ride.discard(); }
        var v = _view;
        if (v != null) {
            v.done(WatchUi.loadResource(_save ? Rez.Strings.RideSaved : Rez.Strings.RideDiscarded) as String);
        }
        later(method(:close), DONE_MS);
    }

    function close() as Void {
        var ride = _ride;
        _view = null;
        FinishFlow.current = null;
        var p = preStart(ride);
        WatchUi.switchToView(p[0], p[1], WatchUi.SLIDE_IMMEDIATE);
    }

    private function later(m as Method() as Void, ms as Number) as Void {
        getApp().ticker.after(ms, m);
    }
}

class FinishView extends WatchUi.View {
    private var _text as String;
    private var _start as Number;
    private var _duration as Number;
    private var _done as Boolean = false;

    function initialize(text as String, duration as Number) {
        View.initialize();
        _text = text;
        _duration = duration;
        _start = System.getTimer();
    }

    function done(text as String) as Void {
        _text = text;
        _done = true;
        WatchUi.requestUpdate();
    }

    function onUpdate(dc as Dc) as Void {
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();
        if (_done) {
            insetRing(dc, Graphics.COLOR_GREEN, 1.0);
        } else {
            var p = (System.getTimer() - _start).toFloat() / _duration;
            insetRing(dc, Graphics.COLOR_RED, p > 1.0 ? 1.0 : p);
        }
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(dc.getWidth() / 2, dc.getHeight() / 2, Graphics.FONT_SMALL, _text,
                    Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }
}

// Blocks buttons while saving / discarding.
class BusyDelegate extends WatchUi.BehaviorDelegate {
    function initialize() {
        BehaviorDelegate.initialize();
    }

    function onBack() as Boolean {
        return true;
    }

    function onSelect() as Boolean {
        return true;
    }
}
