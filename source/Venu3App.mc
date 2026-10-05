import Toybox.Application;
import Toybox.Lang;
import Toybox.WatchUi;

//! Point d'entree du cadran Venu 3 (entry="Venu3App" dans le manifest).
class Venu3App extends Application.AppBase {

    function initialize() {
        AppBase.initialize();
    }

    //! Appele au demarrage de l'application.
    function onStart(state as Dictionary?) as Void {
    }

    //! Appele a l'arret de l'application.
    function onStop(state as Dictionary?) as Void {
    }

    //! Un watchface ne retourne qu'une vue (pas de delegate d'entree).
    function getInitialView() as [Views] or [Views, InputDelegates] {
        return [new Venu3WatchFaceView()];
    }

    //! Appele quand les reglages sont modifies depuis Garmin Connect.
    function onSettingsChanged() as Void {
        WatchUi.requestUpdate();
    }
}

//! Accesseur typé vers l'instance d'application.
function getApp() as Venu3App {
    return Application.getApp() as Venu3App;
}
