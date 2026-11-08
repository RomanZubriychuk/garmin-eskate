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
            Feedback.toast(WatchUi.loadResource(Rez.Strings.ToastStarted) as String, Rez.Drawables.ToastCheck);
        }
        WatchUi.requestUpdate();
        return true;
    }

    function onBack() as Boolean {
        if (_ride.isRecording()) {
            _ride.lap();
            Feedback.toast("Lap " + _ride.lapCount.format("%d"), null);
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
                     menuIcon(Rez.Drawables.MenuResume), {}));
        menu.addItem(new WatchUi.IconMenuItem(Rez.Strings.Save, null, :save,
                     menuIcon(Rez.Drawables.MenuSave), {}));
        menu.addItem(new WatchUi.IconMenuItem(Rez.Strings.Discard, null, :discard,
                     menuIcon(Rez.Drawables.MenuDiscard), {}));
        WatchUi.pushView(menu, new StopMenuDelegate(_ride), WatchUi.SLIDE_UP);
    }

    // Menu icons are passed as Drawables: passing a raw BitmapResource
    // crashed the menu on the Fenix 8 simulator ("Failed invoking <symbol>").
    private function menuIcon(id as ResourceId) as WatchUi.Drawable {
        return new WatchUi.Bitmap({ :rezId => id });
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
        WatchUi.popView(WatchUi.SLIDE_DOWN);
        if (id == :resume) {
            _ride.start();
            Feedback.toast(WatchUi.loadResource(Rez.Strings.ToastResumed) as String, Rez.Drawables.ToastCheck);
        } else if (id == :save) {
            _ride.save();
            Feedback.toast(WatchUi.loadResource(Rez.Strings.ToastSaved) as String, Rez.Drawables.ToastSave);
        } else if (id == :discard) {
            _ride.discard();
            Feedback.toast(WatchUi.loadResource(Rez.Strings.ToastDiscarded) as String, Rez.Drawables.ToastDiscard);
        }
    }
}
