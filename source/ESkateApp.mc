import Toybox.Application;
import Toybox.Lang;
import Toybox.Position;
import Toybox.WatchUi;

class ESkateApp extends Application.AppBase {
    var ride as RideSession;
    var board as BoardLink;

    function initialize() {
        AppBase.initialize();
        ride = new RideSession();
        board = new BoardLink();
    }

    function onStart(state as Dictionary?) as Void {
        Position.enableLocationEvents(Position.LOCATION_CONTINUOUS, method(:onPosition));
        applyBoardSetting();
    }

    // Starts or stops the board link to match the "boardEnabled" setting.
    function applyBoardSetting() as Void {
        var on = Config.flag("boardEnabled");
        if (on && board.state == BoardLink.STATE_OFF) {
            board.start();
        } else if (!on && board.state != BoardLink.STATE_OFF) {
            board.stop();
        }
    }

    function onStop(state as Dictionary?) as Void {
        Position.enableLocationEvents(Position.LOCATION_DISABLE, method(:onPosition));
        board.stop();
    }

    // Settings edited in Garmin Connect on the phone.
    function onSettingsChanged() as Void {
        Config.reload();
        ride.reloadSettings();
        applyBoardSetting();
        WatchUi.requestUpdate();
    }

    function onPosition(info as Position.Info) as Void {
        // No redraw here: the view refreshes once per second on its own.
        ride.onPosition(info);
    }

    function getInitialView() as [WatchUi.Views] or [WatchUi.Views, WatchUi.InputDelegates] {
        var view = new ESkateView(ride, board);
        return [view, new ESkateDelegate(view, ride)];
    }
}

function getApp() as ESkateApp {
    return Application.getApp() as ESkateApp;
}
