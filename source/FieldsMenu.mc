import Toybox.Lang;
import Toybox.WatchUi;

// On-watch settings (long-press UP / MENU): pick the field for every slot
// of both data screens, turn the board link on/off and toggle the extra pages. Changes are saved to
// app settings, the same ones Garmin Connect edits on the phone.
module FieldsMenu {
    function open() as Void {
        var menu = new WatchUi.Menu2({ :title => Rez.Strings.MenuDataFields });
        for (var s = 0; s < Config.SCREEN_COUNT; s++) {
            for (var slot = 0; slot < Config.SLOT_COUNT; slot++) {
                menu.addItem(new WatchUi.MenuItem(slotTitle(s, slot), Fields.name(Config.field(s, slot)),
                                                  s * Config.SLOT_COUNT + slot, {}));
            }
        }
        menu.addItem(new WatchUi.ToggleMenuItem(Rez.Strings.MenuBoardLink, null, :boardEnabled,
                                                Config.flag("boardEnabled"), {}));
        menu.addItem(new WatchUi.ToggleMenuItem(Rez.Strings.MenuBoardPage, null, :showBoardPage,
                                                Config.flag("showBoardPage"), {}));
        menu.addItem(new WatchUi.ToggleMenuItem(Rez.Strings.MenuDiagPage, null, :showDiagnostics,
                                                Config.flag("showDiagnostics"), {}));
        WatchUi.pushView(menu, new FieldsMenuDelegate(), WatchUi.SLIDE_UP);
    }

    function slotTitle(screen as Number, slot as Number) as String {
        var ids = [
            Rez.Strings.SetS1Main, Rez.Strings.SetS1Left, Rez.Strings.SetS1Right, Rez.Strings.SetS1Bottom,
            Rez.Strings.SetS2Main, Rez.Strings.SetS2Left, Rez.Strings.SetS2Right, Rez.Strings.SetS2Bottom
        ];
        return WatchUi.loadResource(ids[screen * Config.SLOT_COUNT + slot] as ResourceId) as String;
    }
}

class FieldsMenuDelegate extends WatchUi.Menu2InputDelegate {
    function initialize() {
        Menu2InputDelegate.initialize();
    }

    function onSelect(item as WatchUi.MenuItem) as Void {
        var id = item.getId();
        if (id == :boardEnabled) {
            Config.setFlag("boardEnabled", (item as WatchUi.ToggleMenuItem).isEnabled());
            getApp().applyBoardSetting();
            return;
        }
        if (id == :showBoardPage || id == :showDiagnostics) {
            Config.setFlag(id == :showBoardPage ? "showBoardPage" : "showDiagnostics",
                           (item as WatchUi.ToggleMenuItem).isEnabled());
            return;
        }
        var n = id as Number;
        var screen = n / Config.SLOT_COUNT;
        var slot = n % Config.SLOT_COUNT;
        var current = Config.field(screen, slot);

        var picker = new WatchUi.Menu2({ :title => item.getLabel() });
        for (var f = 0; f < Fields.COUNT; f++) {
            picker.addItem(new WatchUi.MenuItem(Fields.name(f), null, f, {}));
        }
        picker.setFocus(current);
        WatchUi.pushView(picker, new FieldPickerDelegate(screen, slot, item), WatchUi.SLIDE_LEFT);
    }
}

class FieldPickerDelegate extends WatchUi.Menu2InputDelegate {
    private var _screen as Number;
    private var _slot as Number;
    private var _parentItem as WatchUi.MenuItem;

    function initialize(screen as Number, slot as Number, parentItem as WatchUi.MenuItem) {
        Menu2InputDelegate.initialize();
        _screen = screen;
        _slot = slot;
        _parentItem = parentItem;
    }

    function onSelect(item as WatchUi.MenuItem) as Void {
        var f = item.getId() as Number;
        Config.setField(_screen, _slot, f);
        _parentItem.setSubLabel(Fields.name(f));
        WatchUi.popView(WatchUi.SLIDE_RIGHT);
    }
}
