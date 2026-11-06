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
        if (Application.Properties.getValue("boardEnabled") == true) {
            board.start();
        }
    }

    function onStop(state as Dictionary?) as Void {
        Position.enableLocationEvents(Position.LOCATION_DISABLE, method(:onPosition));
        board.stop();
    }

    function onPosition(info as Position.Info) as Void {
        ride.onPosition(info);
        WatchUi.requestUpdate();
    }

    function getInitialView() as [WatchUi.Views] or [WatchUi.Views, WatchUi.InputDelegates] {
        var view = new ESkateView(ride, board);
        return [view, new ESkateDelegate(view, ride)];
    }
}

function getApp() as ESkateApp {
    return Application.getApp() as ESkateApp;
}
