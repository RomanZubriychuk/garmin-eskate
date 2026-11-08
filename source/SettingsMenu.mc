import Toybox.Lang;
import Toybox.Math;
import Toybox.System;
import Toybox.WatchUi;

// On-watch settings (hold UP / MENU), structured per Garmin's UX guidelines:
// at most 7 items per list, categories with submenus, the current value
// shown as sublabel, toggles for on/off options.
//
//   E-Skate
//   ├─ Data Screens → Screen 1 / Screen 2 → Main / Left / Right / Bottom
//   │                 Background → Auto / Light / Dark
//   ├─ Alerts       → Speed Alert → Off / values
//   ├─ Board        → Connect to Board / Board Screen / Diagnostics
//   └─ About
class SettingsMenu {
    const VERSION = "1.0";
    const SPEEDS_KMH = [0, 15, 20, 25, 30, 35, 40, 45, 50];
    const SPEEDS_MPH = [0, 10, 15, 20, 25, 30];

    // items whose sublabels change when a choice is made deeper down
    private var _screensItem as WatchUi.MenuItem?;
    private var _alertsItem as WatchUi.MenuItem?;
    private var _boardItem as WatchUi.MenuItem?;
    private var _screenItem as WatchUi.MenuItem?;
    private var _slotItem as WatchUi.MenuItem?;
    private var _themeItem as WatchUi.MenuItem?;
    private var _speedItem as WatchUi.MenuItem?;
    private var _editScreen as Number = 0;
    private var _editSlot as Number = 0;

    function initialize() {
    }

    function open() as Void {
        var m = new WatchUi.Menu2({ :title => Rez.Strings.AppName });
        _screensItem = new WatchUi.MenuItem(Rez.Strings.MenuDataScreens, screensSummary(), :screens, {});
        _alertsItem = new WatchUi.MenuItem(Rez.Strings.MenuAlerts, speedText(), :alerts, {});
        _boardItem = new WatchUi.MenuItem(Rez.Strings.MenuBoard, onOff(Config.flag("boardEnabled")), :board, {});
        m.addItem(_screensItem as WatchUi.MenuItem);
        m.addItem(_alertsItem as WatchUi.MenuItem);
        m.addItem(_boardItem as WatchUi.MenuItem);
        m.addItem(new WatchUi.MenuItem(Rez.Strings.MenuAbout, "E-Skate " + VERSION, :about, {}));
        push(m, :onMainSelect);
    }

    // ---- top level ----
    function onMainSelect(item as WatchUi.MenuItem) as Void {
        var id = item.getId();
        if (id == :screens) {
            openScreens();
        } else if (id == :alerts) {
            openAlerts();
        } else if (id == :board) {
            openBoard();
        }
    }


    // ---- data screens ----
    function openScreens() as Void {
        var m = new WatchUi.Menu2({ :title => Rez.Strings.MenuDataScreens });
        for (var s = 0; s < Config.SCREEN_COUNT; s++) {
            m.addItem(new WatchUi.MenuItem("Screen " + (s + 1).format("%d"), screenSummary(s), s, {}));
        }
        _themeItem = new WatchUi.MenuItem(Rez.Strings.MenuBackground, themeName(Config.number("theme", Theme.AUTO)), :theme, {});
        m.addItem(_themeItem as WatchUi.MenuItem);
        push(m, :onScreensSelect);
    }

    function onScreensSelect(item as WatchUi.MenuItem) as Void {
        var id = item.getId();
        if (id == :theme) {
            var m = new WatchUi.Menu2({ :title => Rez.Strings.MenuBackground });
            for (var t = 0; t < 3; t++) {
                m.addItem(new WatchUi.MenuItem(themeName(t), null, t, {}));
            }
            m.setFocus(Config.number("theme", Theme.AUTO));
            pushChoice(m, :onThemePicked);
            return;
        }
        _editScreen = id as Number;
        _screenItem = item;
        var m = new WatchUi.Menu2({ :title => item.getLabel() });
        for (var slot = 0; slot < Config.SLOT_COUNT; slot++) {
            m.addItem(new WatchUi.MenuItem(Config.SLOT_NAMES[slot], Fields.name(Config.field(_editScreen, slot)), slot, {}));
        }
        push(m, :onSlotSelect);
    }

    function onSlotSelect(item as WatchUi.MenuItem) as Void {
        _editSlot = item.getId() as Number;
        _slotItem = item;
        var m = new WatchUi.Menu2({ :title => item.getLabel() });
        for (var f = 0; f < Fields.COUNT; f++) {
            m.addItem(new WatchUi.MenuItem(Fields.name(f), null, f, {}));
        }
        m.setFocus(Config.field(_editScreen, _editSlot));
        pushChoice(m, :onFieldPicked);
    }

    function onFieldPicked(value as Object) as Void {
        var f = value as Number;
        Config.setField(_editScreen, _editSlot, f);
        setSub(_slotItem, Fields.name(f));
        setSub(_screenItem, screenSummary(_editScreen));
        setSub(_screensItem, screensSummary());
    }

    function onThemePicked(value as Object) as Void {
        var t = value as Number;
        Config.setNumber("theme", t);
        Theme.reload();
        setSub(_themeItem, themeName(t));
    }

    // ---- alerts ----
    function openAlerts() as Void {
        var m = new WatchUi.Menu2({ :title => Rez.Strings.MenuAlerts });
        _speedItem = new WatchUi.MenuItem(Rez.Strings.MenuSpeedAlert, speedText(), :speed, {});
        m.addItem(_speedItem as WatchUi.MenuItem);
        push(m, :onAlertsSelect);
    }

    function onAlertsSelect(item as WatchUi.MenuItem) as Void {
        var metric = Units.isMetric();
        var values = metric ? SPEEDS_KMH : SPEEDS_MPH;
        var current = Config.number("speedAlertKmh", 0);
        var focus = 0;
        var m = new WatchUi.Menu2({ :title => Rez.Strings.MenuSpeedAlert });
        for (var i = 0; i < values.size(); i++) {
            var kmh = metric ? values[i] : Math.round(values[i] * 1.609344).toNumber();
            m.addItem(new WatchUi.MenuItem(speedLabel(kmh), null, kmh, {}));
            if (kmh == current) { focus = i; }
        }
        m.setFocus(focus);
        pushChoice(m, :onSpeedPicked);
    }

    function onSpeedPicked(value as Object) as Void {
        Config.setNumber("speedAlertKmh", value as Number);
        getApp().ride.reloadSettings();
        setSub(_speedItem, speedText());
        setSub(_alertsItem, speedText());
    }

    // ---- board ----
    function openBoard() as Void {
        var m = new WatchUi.Menu2({ :title => Rez.Strings.MenuBoard });
        m.addItem(new WatchUi.ToggleMenuItem(Rez.Strings.MenuBoardLink, null, "boardEnabled", Config.flag("boardEnabled"), {}));
        m.addItem(new WatchUi.ToggleMenuItem(Rez.Strings.MenuBoardPage, null, "showBoardPage", Config.flag("showBoardPage"), {}));
        m.addItem(new WatchUi.ToggleMenuItem(Rez.Strings.MenuDiagPage, null, "showDiagnostics", Config.flag("showDiagnostics"), {}));
        push(m, :onBoardSelect);
    }

    function onBoardSelect(item as WatchUi.MenuItem) as Void {
        var key = item.getId() as String;
        Config.setFlag(key, (item as WatchUi.ToggleMenuItem).isEnabled());
        if (key.equals("boardEnabled")) {
            getApp().applyBoardSetting();
            setSub(_boardItem, onOff(Config.flag("boardEnabled")));
        }
    }

    // ---- helpers ----
    // Menus slide in from the right, as the guidelines recommend.
    private function push(m as WatchUi.Menu2, handler as Symbol) as Void {
        WatchUi.pushView(m, new SettingsMenuDelegate(method(handler), false), WatchUi.SLIDE_LEFT);
    }

    // A choice list closes itself after a pick.
    private function pushChoice(m as WatchUi.Menu2, handler as Symbol) as Void {
        WatchUi.pushView(m, new SettingsMenuDelegate(method(handler), true), WatchUi.SLIDE_LEFT);
    }

    private function setSub(item as WatchUi.MenuItem?, text as String) as Void {
        if (item != null) { item.setSubLabel(text); }
    }

    function screensSummary() as String {
        return Config.screenUsed(1) ? "2 screens" : "1 screen";
    }

    private function screenSummary(s as Number) as String {
        return Config.screenUsed(s) ? Fields.name(Config.field(s, 0)) : "Off";
    }

    private function themeName(t as Number) as String {
        return t == Theme.LIGHT ? "Light" : (t == Theme.DARK ? "Dark" : "Auto");
    }

    function onOff(on as Boolean) as String {
        return on ? "On" : "Off";
    }

    function speedText() as String {
        return speedLabel(Config.number("speedAlertKmh", 0));
    }

    private function speedLabel(kmh as Number) as String {
        if (kmh <= 0) { return "Off"; }
        return Units.isMetric()
            ? kmh.format("%d") + " km/h"
            : Math.round(kmh / 1.609344).toNumber().format("%d") + " mph";
    }
}

class SettingsMenuDelegate extends WatchUi.Menu2InputDelegate {
    private var _handler as Method;
    private var _closeOnPick as Boolean;

    function initialize(handler as Method, closeOnPick as Boolean) {
        Menu2InputDelegate.initialize();
        _handler = handler;
        _closeOnPick = closeOnPick;
    }

    function onSelect(item as WatchUi.MenuItem) as Void {
        if (_closeOnPick) {
            _handler.invoke(item.getId());
            WatchUi.popView(WatchUi.SLIDE_RIGHT);
        } else {
            _handler.invoke(item);
        }
    }

    function onBack() as Void {
        WatchUi.popView(WatchUi.SLIDE_RIGHT);
    }
}
