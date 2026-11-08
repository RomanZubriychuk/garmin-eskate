import Toybox.Lang;
import Toybox.System;
import Toybox.WatchUi;

// Native system toast over the app ("Ride started", "Lap 2", ...), the same
// component Garmin's own activities use. Vibration and tones are played by
// RideSession. Watches without system toasts (pre System 6) just skip it.
module Feedback {
    function toast(text as String, icon as ResourceId?) as Void {
        if (!(WatchUi has :showToast)) {
            return;
        }
        if (icon != null) {
            WatchUi.showToast(text, { :icon => icon });
        } else {
            WatchUi.showToast(text, null);
        }
    }
}
