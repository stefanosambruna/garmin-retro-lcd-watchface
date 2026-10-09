import Toybox.Application;
import Toybox.Lang;
import Toybox.WatchUi;

class LcdApp extends Application.AppBase {

    private var _view as LcdView?;

    function initialize() {
        AppBase.initialize();
    }

    function getInitialView() as [Views] or [Views, InputDelegates] {
        var view = new LcdView();
        _view = view;
        return [view];
    }

    function onSettingsChanged() as Void {
        var view = _view;
        if (view != null) {
            view.loadSettings();
        }
        WatchUi.requestUpdate();
    }
}
