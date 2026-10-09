import Toybox.Activity;
import Toybox.Application;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Math;
import Toybox.System;
import Toybox.Time;
import Toybox.Time.Gregorian;
import Toybox.Weather;
import Toybox.WatchUi;

class LcdView extends WatchUi.WatchFace {

    private const GHOST = 0x1C1C1C;
    // Always-on brightness, in percent of the chosen digit color
    private const AOD_DIM = 55;
    private const DAYS = ["SUN", "MON", "TUE", "WED", "THU", "FRI", "SAT"] as Array<String>;

    private var _sleeping as Boolean = false;
    private var _cx as Number = 0;
    private var _cy as Number = 0;
    private var _big as WatchUi.FontResource?;
    private var _small as WatchUi.FontResource?;
    private var _color as Number = 0xE6E6E6;
    private var _ghost as Boolean = true;
    private var _seconds as Boolean = true;

    function initialize() {
        WatchFace.initialize();
        loadSettings();
    }

    function loadSettings() as Void {
        var color = Application.Properties.getValue("Color");
        _color = color instanceof Number ? color : 0xE6E6E6;
        _ghost = flag("Ghost");
        _seconds = flag("Seconds");
    }

    private function flag(key as String) as Boolean {
        var v = Application.Properties.getValue(key);
        return !(v instanceof Boolean) || v;
    }

    function onLayout(dc as Dc) as Void {
        _cx = dc.getWidth() / 2;
        _cy = dc.getHeight() / 2;
        _big = WatchUi.loadResource(Rez.Fonts.Big) as WatchUi.FontResource;
        _small = WatchUi.loadResource(Rez.Fonts.Small) as WatchUi.FontResource;
    }

    function onEnterSleep() as Void {
        _sleeping = true;
        WatchUi.requestUpdate();
    }

    function onExitSleep() as Void {
        _sleeping = false;
        WatchUi.requestUpdate();
    }

    function onUpdate(dc as Dc) as Void {
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();
        var clock = System.getClockTime();
        var hour = clock.hour;
        if (!System.getDeviceSettings().is24Hour) {
            hour = hour % 12;
            hour = hour == 0 ? 12 : hour;
        }
        var time = hour.format("%02d") + ":" + clock.min.format("%02d");
        if (_sleeping) {
            drawAod(dc, time);
        } else {
            drawActive(dc, time, clock.sec);
        }
    }

    // Lit segments over their unlit "ghosts", like a real LCD
    private function segments(dc as Dc, x as Number, y as Number, font as WatchUi.FontResource,
            text as String, ghost as String) as Void {
        if (_ghost) {
            dc.setColor(GHOST, Graphics.COLOR_TRANSPARENT);
            dc.drawText(x, y, font, ghost, Graphics.TEXT_JUSTIFY_LEFT);
        }
        dc.setColor(_color, Graphics.COLOR_TRANSPARENT);
        dc.drawText(x, y, font, text, Graphics.TEXT_JUSTIFY_LEFT);
    }

    private function drawActive(dc as Dc, time as String, sec as Number) as Void {
        var big = _big;
        var small = _small;
        if (big == null || small == null) {
            return;
        }
        var bigHeight = dc.getFontHeight(big);
        var smallHeight = dc.getFontHeight(small);
        var gap = smallHeight / 3;
        var timeWidth = dc.getTextWidthInPixels(time, big);
        // The time is centred on its own, exactly where the always-on screen draws it
        var x = _cx - timeWidth / 2;
        var y = _cy - bigHeight / 2;

        // Main row: time, with the seconds sitting on its baseline
        segments(dc, x, y, big, time, "88:88");
        if (_seconds) {
            segments(dc, x + timeWidth + gap, y + bigHeight - smallHeight, small, sec.format("%02d"), "88");
        }

        // Top row: weekday on the left, day of the month on the right
        var info = Gregorian.info(Time.now(), Time.FORMAT_SHORT);
        var top = y - gap - smallHeight;
        dc.setColor(_color, Graphics.COLOR_TRANSPARENT);
        dc.drawText(x, top, small, DAYS[(info.day_of_week as Number) - 1], Graphics.TEXT_JUSTIFY_LEFT);
        var day = (info.day as Number).format("%02d");
        segments(dc, x + timeWidth - dc.getTextWidthInPixels(day, small), top, small, day, "88");

        // Bottom row: altitude on the left, temperature on the right
        var bottom = y + bigHeight + gap;
        var temperature = temperatureText();
        dc.setColor(_color, Graphics.COLOR_TRANSPARENT);
        dc.drawText(x, bottom, small, altitudeText(), Graphics.TEXT_JUSTIFY_LEFT);
        dc.drawText(x + timeWidth - dc.getTextWidthInPixels(temperature, small), bottom, small,
            temperature, Graphics.TEXT_JUSTIFY_LEFT);
    }

    // "195M", or feet with statute units; "---" when there is no reading
    private function altitudeText() as String {
        var info = Activity.getActivityInfo();
        var altitude = info != null ? info.altitude : null;
        if (altitude == null) {
            return "---";
        }
        if (System.getDeviceSettings().elevationUnits == System.UNIT_STATUTE) {
            return Math.round(altitude * 3.28084).format("%d") + "FT";
        }
        return Math.round(altitude).format("%d") + "M";
    }

    // Current weather temperature in the user's unit, "--°" when there is no reading
    private function temperatureText() as String {
        var conditions = Weather.getCurrentConditions();
        var temperature = conditions != null ? conditions.temperature : null;
        if (temperature == null) {
            return "--°";
        }
        var t = temperature.toFloat();
        if (System.getDeviceSettings().temperatureUnits == System.UNIT_STATUTE) {
            t = t * 9.0 / 5.0 + 32.0;
        }
        return Math.round(t).format("%d") + "°";
    }

    // Always-on: the same time digits in the same place, dimmed, and nothing else;
    // one update per minute
    private function drawAod(dc as Dc, time as String) as Void {
        var font = _big;
        if (font == null) {
            return;
        }
        var dimmed = (((_color >> 16) & 0xFF) * AOD_DIM / 100) << 16
            | (((_color >> 8) & 0xFF) * AOD_DIM / 100) << 8
            | ((_color & 0xFF) * AOD_DIM / 100);
        dc.setColor(dimmed, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_cx - dc.getTextWidthInPixels(time, font) / 2, _cy - dc.getFontHeight(font) / 2, font,
            time, Graphics.TEXT_JUSTIFY_LEFT);
    }
}
