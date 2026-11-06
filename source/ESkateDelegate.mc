import Toybox.Lang;
import Toybox.WatchUi;

// Buttons (Fenix 8):
//   START          start / pause ride (pause opens Resume / Save / Discard)
//   BACK           lap while riding; exit when idle
//   UP / DOWN      switch pages
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
        }
        WatchUi.requestUpdate();
        return true;
    }

    function onBack() as Boolean {
        if (_ride.isRecording()) {
            _ride.lap();
            return true;
        }
        if (_ride.hasSession()) {
            showStopMenu();
            return true;
        }
        return false; // exit app
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
        menu.addItem(new WatchUi.MenuItem(Rez.Strings.Resume, null, :resume, {}));
        menu.addItem(new WatchUi.MenuItem(Rez.Strings.Save, null, :save, {}));
        menu.addItem(new WatchUi.MenuItem(Rez.Strings.Discard, null, :discard, {}));
        WatchUi.pushView(menu, new StopMenuDelegate(_ride), WatchUi.SLIDE_UP);
    }
}

class StopMenuDelegate extends WatchUi.Menu2InputDelegate {
    private var _ride as RideSession;

    function initialize(ride as RideSession) {
        Menu2InputDelegate.initialize();
        _ride = ride;
    }

    function onSelect(item as WatchUi.MenuItem) as Void {
        var id = item.getId();
        if (id == :resume) {
            _ride.start();
        } else if (id == :save) {
            _ride.save();
        } else if (id == :discard) {
            _ride.discard();
        }
        WatchUi.popView(WatchUi.SLIDE_DOWN);
    }
}
