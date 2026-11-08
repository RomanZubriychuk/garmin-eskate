import Toybox.Graphics;
import Toybox.Lang;
import Toybox.WatchUi;

// Buttons:
//   START          start / pause ride (pause opens Resume / Save / Discard)
//   BACK           lap while riding; exit when idle
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
        if (_view.fx.isActive()) {
            return true;   // ignore presses during the animation
        }
        if (_ride.isRecording()) {
            _ride.pause();
            _view.fx.play(Feedback.PAUSE, method(:showStopMenu));
        } else if (_ride.hasSession()) {
            showStopMenu();
        } else {
            _ride.start();
            _view.fx.play(Feedback.START, null);
        }
        WatchUi.requestUpdate();
        return true;
    }

    function onBack() as Boolean {
        if (_view.fx.isActive()) {
            return true;
        }
        if (_ride.isRecording()) {
            _ride.lap();
            _view.fx.lap = _ride.lapCount;
            _view.fx.play(Feedback.LAP, null);
            return true;
        }
        if (_ride.hasSession()) {
            showStopMenu();
            return true;
        }
        return false; // exit app
    }

    function onMenu() as Boolean {
        new SettingsMenu().open();
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

    function showStopMenu() as Void {
        var menu = new WatchUi.Menu2({ :title => Rez.Strings.MenuTitle });
        menu.addItem(new WatchUi.IconMenuItem(Rez.Strings.Resume, null, :resume,
                     menuIcon(Rez.Drawables.MenuResume), {}));
        menu.addItem(new WatchUi.IconMenuItem(Rez.Strings.Save, null, :save,
                     menuIcon(Rez.Drawables.MenuSave), {}));
        menu.addItem(new WatchUi.IconMenuItem(Rez.Strings.Discard, null, :discard,
                     menuIcon(Rez.Drawables.MenuDiscard), {}));
        WatchUi.pushView(menu, new StopMenuDelegate(_ride, _view.fx), WatchUi.SLIDE_UP);
    }

    // Menu icons are passed as Drawables: passing a raw BitmapResource
    // crashed the menu on the Fenix 8 simulator ("Failed invoking <symbol>").
    private function menuIcon(id as ResourceId) as WatchUi.Drawable {
        return new WatchUi.Bitmap({ :rezId => id });
    }
}

class StopMenuDelegate extends WatchUi.Menu2InputDelegate {
    private var _ride as RideSession;
    private var _fx as Feedback;

    function initialize(ride as RideSession, fx as Feedback) {
        Menu2InputDelegate.initialize();
        _ride = ride;
        _fx = fx;
    }

    function onSelect(item as WatchUi.MenuItem) as Void {
        var id = item.getId();
        WatchUi.popView(WatchUi.SLIDE_DOWN);
        if (id == :resume) {
            _ride.start();
            _fx.play(Feedback.START, null);
        } else if (id == :save) {
            _ride.save();
            _fx.play(Feedback.SAVED, null);
        } else if (id == :discard) {
            _ride.discard();
            _fx.play(Feedback.DISCARDED, null);
        }
    }
}
