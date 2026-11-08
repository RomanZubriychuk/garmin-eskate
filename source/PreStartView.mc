import Toybox.Attention;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.System;
import Toybox.Time;
import Toybox.Time.Gregorian;
import Toybox.WatchUi;

// Pre-start page, laid out like a native activity's: a status block (clock,
// GPS bar, connection icons, activity icon and name, START hint) on top of a
// list of settings items (icon | divider | label + value). UP / DOWN glide
// one row at a time; the focused row sits in the middle and is drawn white,
// the others gray, like the native page.
//   START   on the status block: start the ride; on an item: open it
//   BACK    scroll back to the top, then exit
class PreStartView extends ScrollPage {
    enum {
        ITEM_SCREENS,
        ITEM_ALERTS,
        ITEM_BOARD,
        ITEM_COUNT
    }

    const HEAD = 0.66;      // status block height (fraction of screen height)
    const ITEM = 0.27;      // list item height

    private var _ride as RideSession;
    private var _icon as WatchUi.BitmapResource?;
    private var _hint as Array<WatchUi.Drawable>? = null;
    private var _name as String = "";
    private var _labels as Array<String> = [] as Array<String>;
    private var _wasReady as Boolean;

    function initialize(ride as RideSession) {
        ScrollPage.initialize();
        _ride = ride;
        _maxFocus = ITEM_COUNT;
        _wasReady = ride.gpsReady();
    }

    function onLayout(dc as Dc) as Void {
        _icon = WatchUi.loadResource(Rez.Drawables.LauncherIcon) as WatchUi.BitmapResource;
        _name = WatchUi.loadResource(Rez.Strings.AppName) as String;
        _labels = [
            WatchUi.loadResource(Rez.Strings.MenuDataScreens) as String,
            WatchUi.loadResource(Rez.Strings.MenuAlerts) as String,
            WatchUi.loadResource(Rez.Strings.MenuBoard) as String
        ];
        loadHint(dc);
    }

    (:hints)
    private function loadHint(dc as Dc) as Void {
        _hint = Rez.Layouts.HintStart(dc);
    }

    (:noHints)
    private function loadHint(dc as Dc) as Void {
    }

    // Status block at the top; an item is centred on the screen.
    function targetFor(f as Number, h as Number) as Float {
        if (f == 0) { return 0.0; }
        var t = h * HEAD + (f - 1) * h * ITEM + h * ITEM / 2 - h / 2.0;
        return t < 0 ? 0.0 : t.toFloat();
    }

    function onUpdate(dc as Dc) as Void {
        checkGps();
        ScrollPage.onUpdate(dc);
    }

    // Native activities buzz and beep once when GPS is ready to go.
    private function checkGps() as Void {
        var ready = _ride.gpsReady();
        if (ready && !_wasReady) {
            if (Attention has :vibrate) {
                Attention.vibrate([new Attention.VibeProfile(100, 400)]);
            }
            if (Attention has :playTone) {
                Attention.playTone(Attention.TONE_LOUD_BEEP);
            }
        }
        _wasReady = ready;
    }

    function drawContent(dc as Dc, w as Number, h as Number, y0 as Float) as Void {
        drawHead(dc, w, h, y0);
        var top = y0 + h * HEAD;
        for (var i = 0; i < ITEM_COUNT; i++) {
            var y = top + i * h * ITEM;
            if (y < dc.getHeight() && y + h * ITEM > 0) {
                drawItem(dc, w, h, i, y);
            }
        }
    }

    function drawOverlay(dc as Dc) as Void {
        var fx = getApp().fx;
        if (fx.isActive()) {
            fx.draw(dc);
        }
    }

    private function drawHead(dc as Dc, w as Number, h as Number, y0 as Float) as Void {
        if (y0 + h * HEAD < 0) { return; }
        var center = Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER;

        // clock
        var c = Gregorian.info(Time.now(), Time.FORMAT_SHORT);
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2, y0 + h * 0.10, Graphics.FONT_TINY, c.hour.format("%d") + ":" + c.min.format("%02d"), center);

        // GPS bar: real fix quality from the watch. Red square while
        // searching, the bar fills green with signal, all green once usable.
        var ready = _ride.gpsReady();
        var level = _ride.gpsLevel();
        var y = y0 + h * 0.19;
        dc.drawText(w * 0.33, y, Graphics.FONT_XTINY, "GPS", Graphics.TEXT_JUSTIFY_RIGHT | Graphics.TEXT_JUSTIFY_VCENTER);
        var x0 = w * 0.35;
        var x1 = w * 0.68;
        var sq = h / 30;
        dc.setColor(ready ? Graphics.COLOR_GREEN : Graphics.COLOR_RED, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(x0, y - sq / 2, sq, sq);
        dc.setPenWidth(2);
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(x0 + sq + 2, y, x1, y);
        if (level > 0) {
            dc.setColor(Graphics.COLOR_GREEN, Graphics.COLOR_TRANSPARENT);
            dc.setPenWidth(4);
            dc.drawLine(x0 + sq + 2, y, x0 + sq + 2 + (x1 - x0 - sq - 2) * level, y);
        }
        dc.setPenWidth(2);

        // connection status, like native: phone, heart rate, board
        drawStatusIcons(dc, w / 2, y0 + h * 0.27, h / 34);
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(2);
        dc.drawLine(w * 0.36, y0 + h * 0.33, w * 0.64, y0 + h * 0.33);

        // activity icon + name
        var icon = _icon;
        if (icon != null) {
            dc.drawBitmap(w / 2 - icon.getWidth() / 2, y0 + h * 0.44 - icon.getHeight() / 2, icon);
        }
        dc.drawText(w / 2, y0 + h * 0.57, Graphics.FONT_SMALL, _name, center);

        // separator to the list
        dc.drawLine(0, y0 + h * HEAD - 1, w, y0 + h * HEAD - 1);
        dc.setPenWidth(1);

        // START hint, only while the status block is at the top
        var hint = _hint;
        if (hint != null && y0 > -2) {
            for (var i = 0; i < hint.size(); i++) { hint[i].draw(dc); }
        }

        // green play mark next to START once GPS is ready, like native
        if (ready) {
            var px = w * 0.78;
            var py = y0 + h * 0.27;
            var s = h / 26;
            dc.setColor(Graphics.COLOR_GREEN, Graphics.COLOR_TRANSPARENT);
            dc.fillPolygon([[px - s * 0.7, py - s], [px - s * 0.7, py + s], [px + s, py]]);
        }
    }

    // White = connected / receiving, dark gray = not.
    private function drawStatusIcons(dc as Dc, cx as Number, cy as Float, s as Number) as Void {
        var board = Config.flag("boardEnabled");
        var n = board ? 3 : 2;
        var gap = s * 3.2;
        var x = cx - gap * (n - 1) / 2.0;

        // phone (Bluetooth link to the phone) and heart rate (wrist sensor)
        drawStatus(dc, x, cy, System.getDeviceSettings().phoneConnected ? Rez.Drawables.PhoneOn : Rez.Drawables.PhoneOff);
        x += gap;
        drawStatus(dc, x, cy, _ride.heartRate() != null ? Rez.Drawables.HrOn : Rez.Drawables.HrOff);
        x += gap;

        // board
        if (board) {
            drawStatus(dc, x, cy, getApp().board.state == BoardLink.STATE_CONNECTED ? Rez.Drawables.BoardOn : Rez.Drawables.BoardOff);
        }
    }

    private var _bmp as Dictionary<ResourceId, WatchUi.BitmapResource> = {} as Dictionary<ResourceId, WatchUi.BitmapResource>;

    private function drawStatus(dc as Dc, x as Float, cy as Float, id as ResourceId) as Void {
        var b = _bmp[id];
        if (b == null) {
            b = WatchUi.loadResource(id) as WatchUi.BitmapResource;
            _bmp[id] = b;
        }
        dc.drawBitmap(x - b.getWidth() / 2, cy - b.getHeight() / 2, b);
    }


    // Focused row: white title, light value. Others: gray, like native.
    private function drawItem(dc as Dc, w as Number, h as Number, i as Number, y as Float) as Void {
        var ih = h * ITEM;
        var cy = y + ih / 2;
        var divX = w * 0.27;
        var focused = focus == i + 1;
        var main = focused ? Graphics.COLOR_WHITE : Graphics.COLOR_LT_GRAY;

        dc.setColor(main, Graphics.COLOR_TRANSPARENT);
        drawStatus(dc, w * 0.15, cy, itemIcon(i, focused));
        focusDivider(dc, divX, y, ih, focused);

        var x = divX + w * 0.04;
        dc.drawText(x, cy - ih * 0.18, Graphics.FONT_TINY, _labels[i], Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
        dc.setColor(focused ? Graphics.COLOR_LT_GRAY : Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(x, cy + ih * 0.20, Graphics.FONT_XTINY, value(i), Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    private function value(i as Number) as String {
        var m = new SettingsMenu();
        if (i == ITEM_SCREENS) { return m.screensSummary(); }
        if (i == ITEM_ALERTS) { return m.speedText(); }
        return m.onOff(Config.flag("boardEnabled"));
    }

    private function itemIcon(i as Number, focused as Boolean) as ResourceId {
        if (i == ITEM_SCREENS) { return focused ? Rez.Drawables.ItemScreensOn : Rez.Drawables.ItemScreensDim; }
        if (i == ITEM_ALERTS) { return focused ? Rez.Drawables.ItemAlertsOn : Rez.Drawables.ItemAlertsDim; }
        return focused ? Rez.Drawables.ItemBoardOn : Rez.Drawables.ItemBoardDim;
    }
}

class PreStartDelegate extends WatchUi.BehaviorDelegate {
    private var _ride as RideSession;
    private var _view as PreStartView;

    function initialize(ride as RideSession, view as PreStartView) {
        BehaviorDelegate.initialize();
        _ride = ride;
        _view = view;
    }

    function onTap(evt as WatchUi.ClickEvent) as Boolean {
        return true;
    }

    function onSelect() as Boolean {
        var fx = getApp().fx;
        if (fx.isActive()) { return true; }
        var f = _view.focus;
        if (f == 0) {
            _ride.start();
            fx.play(Feedback.START, method(:showDataPage));
        } else {
            var m = new SettingsMenu();
            if (f - 1 == PreStartView.ITEM_SCREENS) {
                m.openScreens();
            } else if (f - 1 == PreStartView.ITEM_ALERTS) {
                m.openAlerts();
            } else {
                m.openBoard();
            }
        }
        return true;
    }

    // After the play overlay the first data page slides in from the right.
    function showDataPage() as Void {
        var v = new ESkateView(_ride, getApp().board, 0, false);
        WatchUi.switchToView(v, new ESkateDelegate(v, _ride), WatchUi.SLIDE_LEFT);
    }

    function onNextPage() as Boolean {
        _view.scrollTo(_view.focus + 1);
        return true;
    }

    function onPreviousPage() as Boolean {
        _view.scrollTo(_view.focus - 1);
        return true;
    }

    function onMenu() as Boolean {
        new SettingsMenu().open();
        return true;
    }

    function onBack() as Boolean {
        if (_view.focus > 0) {
            _view.scrollTo(0);
            return true;
        }
        return false;   // exit the app
    }
}

// The pre-start page with its delegate.
function preStart(ride as RideSession) as [WatchUi.Views, WatchUi.InputDelegates] {
    var v = new PreStartView(ride);
    return [v, new PreStartDelegate(ride, v)];
}
