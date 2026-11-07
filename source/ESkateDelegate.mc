import Toybox.Graphics;
import Toybox.Lang;
import Toybox.WatchUi;

// Buttons:
//   START          start / pause ride (pause opens Resume / Save / Discard)
//   BACK           lap while riding; exit when idle
//   UP / DOWN      switch pages (swipe up / down on touch-only watches)
//   hold UP (MENU) data field settings
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
        if (_ride.isRecording()) {
            _ride.pause();
            showStopMenu();
        } else if (_ride.hasSession()) {
            showStopMenu();
        } else {
            _ride.start();
            _view.flash(ESkateView.FLASH_START);
        }
        WatchUi.requestUpdate();
        return true;
    }

    function onBack() as Boolean {
        if (_ride.isRecording()) {
            _ride.lap();
            _view.flash(ESkateView.FLASH_LAP);
            return true;
        }
        if (_ride.hasSession()) {
            showStopMenu();
            return true;
        }
        return false; // exit app
    }

    function onMenu() as Boolean {
        FieldsMenu.open();
        return true;
    }

    function onNextPage() as Boolean {
        _view.nextPage(1);
        return true;
    }

    function onPreviousPage() as Boolean {
        _view.nextPage(-1);
        return true;
    }

    private function showStopMenu() as Void {
        var menu = new WatchUi.Menu2({ :title => Rez.Strings.MenuTitle });
        menu.addItem(new WatchUi.IconMenuItem(Rez.Strings.Resume, null, :resume,
                     WatchUi.loadResource(Rez.Drawables.IconResume) as Graphics.BitmapType, {}));
        menu.addItem(new WatchUi.IconMenuItem(Rez.Strings.Save, null, :save,
                     WatchUi.loadResource(Rez.Drawables.IconSave) as Graphics.BitmapType, {}));
        menu.addItem(new WatchUi.IconMenuItem(Rez.Strings.Discard, null, :discard,
                     WatchUi.loadResource(Rez.Drawables.IconDiscard) as Graphics.BitmapType, {}));
        WatchUi.pushView(menu, new StopMenuDelegate(_ride, _view), WatchUi.SLIDE_UP);
    }
}

class StopMenuDelegate extends WatchUi.Menu2InputDelegate {
    private var _ride as RideSession;
    private var _view as ESkateView;

    function initialize(ride as RideSession, view as ESkateView) {
        Menu2InputDelegate.initialize();
        _ride = ride;
        _view = view;
    }

    function onSelect(item as WatchUi.MenuItem) as Void {
        var id = item.getId();
        if (id == :resume) {
            _ride.start();
            _view.flash(ESkateView.FLASH_START);
        } else if (id == :save) {
            _ride.save();
            _view.flash(ESkateView.FLASH_SAVED);
        } else if (id == :discard) {
            _ride.discard();
            _view.flash(ESkateView.FLASH_DISCARDED);
        }
        WatchUi.popView(WatchUi.SLIDE_DOWN);
    }
}
