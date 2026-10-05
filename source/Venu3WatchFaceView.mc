import Toybox.Application;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.System;
import Toybox.Time;
import Toybox.Time.Gregorian;
import Toybox.WatchUi;

//! Cadran Venu 3 / Venu 3S
//!
//!   +------------------------------+
//!   |          9 - VEN             |  date : jour + 3 lettres
//!   |          10:42               |  heure numerique
//!   |           (!)                |  icone alarme (allumee si alarme active)
//!   |   (o)  (o)  (o)  (o)         |  4 jauges circulaires
//!   |   [#]  [V]  [B]  [Z]         |  pictogrammes : chaussure / coeur / batterie / eclair
//!   +------------------------------+
class Venu3WatchFaceView extends WatchUi.WatchFace {

    // Abreviations FR : Gregorian FORMAT_SHORT renvoie day_of_week = 1 (dimanche) .. 7 (samedi)
    private var _daysFr as Array<String> = ["DIM", "LUN", "MAR", "MER", "JEU", "VEN", "SAM"];

    // Couleurs des jauges
    private const COLOR_STEPS  = 0x00AAFF; // bleu
    private const COLOR_HR     = 0xFF3B30; // rouge
    private const COLOR_BB     = 0x34C759; // vert
    private const COLOR_STRESS = 0xFF9500; // orange
    private const COLOR_TRACK  = 0x303030; // fond des jauges
    private const COLOR_ALTITUDE = 0xC080A0; // mauve
    private const MOON_REFERENCE_SECONDS = 947182440.0; // nouvelle lune du 2000-01-06 18:14 UTC
    private const MOON_SYNODIC_SECONDS = 2551442.89; // cycle synodique moyen : 29.5305888 jours

    private var _width as Number = 0;
    private var _height as Number = 0;
    private var _lowPower as Boolean = false;

    // Pictogrammes des jauges (generes par scripts\make-icons.ps1)
    private var _iconSteps as BitmapResource?;
    private var _iconHr as BitmapResource?;
    private var _iconBb as BitmapResource?;
    private var _iconStress as BitmapResource?;
    private var _iconAlarmOn as BitmapResource?;
    private var _iconAlarmOff as BitmapResource?;
    private var _iconMoonNew as BitmapResource?;
    private var _iconMoonWaxingCrescent as BitmapResource?;
    private var _iconMoonFirstQuarter as BitmapResource?;
    private var _iconMoonWaxingGibbous as BitmapResource?;
    private var _iconMoonFull as BitmapResource?;
    private var _iconMoonWaningGibbous as BitmapResource?;
    private var _iconMoonLastQuarter as BitmapResource?;
    private var _iconMoonWaningCrescent as BitmapResource?;
    private var _iconWeatherStable as BitmapResource?;
    private var _iconWeatherFair as BitmapResource?;
    private var _iconWeatherClouds as BitmapResource?;
    private var _iconWeatherVariable as BitmapResource?;
    private var _iconWeatherShowers as BitmapResource?;
    private var _iconWeatherRain as BitmapResource?;
    private var _iconWeatherStorm as BitmapResource?;

    function initialize() {
        WatchFace.initialize();
    }

    function onLayout(dc as Dc) as Void {
        _width = dc.getWidth();
        _height = dc.getHeight();

        _iconSteps  = WatchUi.loadResource(Rez.Drawables.IconSteps) as BitmapResource;
        _iconHr     = WatchUi.loadResource(Rez.Drawables.IconHr) as BitmapResource;
        _iconBb     = WatchUi.loadResource(Rez.Drawables.IconBb) as BitmapResource;
        _iconStress = WatchUi.loadResource(Rez.Drawables.IconStress) as BitmapResource;
        _iconAlarmOn = WatchUi.loadResource(Rez.Drawables.IconAlarmOn) as BitmapResource;
        _iconAlarmOff = WatchUi.loadResource(Rez.Drawables.IconAlarmOff) as BitmapResource;
        _iconMoonNew = WatchUi.loadResource(Rez.Drawables.IconMoonNew) as BitmapResource;
        _iconMoonWaxingCrescent = WatchUi.loadResource(Rez.Drawables.IconMoonWaxingCrescent) as BitmapResource;
        _iconMoonFirstQuarter = WatchUi.loadResource(Rez.Drawables.IconMoonFirstQuarter) as BitmapResource;
        _iconMoonWaxingGibbous = WatchUi.loadResource(Rez.Drawables.IconMoonWaxingGibbous) as BitmapResource;
        _iconMoonFull = WatchUi.loadResource(Rez.Drawables.IconMoonFull) as BitmapResource;
        _iconMoonWaningGibbous = WatchUi.loadResource(Rez.Drawables.IconMoonWaningGibbous) as BitmapResource;
        _iconMoonLastQuarter = WatchUi.loadResource(Rez.Drawables.IconMoonLastQuarter) as BitmapResource;
        _iconMoonWaningCrescent = WatchUi.loadResource(Rez.Drawables.IconMoonWaningCrescent) as BitmapResource;
        _iconWeatherStable = WatchUi.loadResource(Rez.Drawables.IconWeatherStable) as BitmapResource;
        _iconWeatherFair = WatchUi.loadResource(Rez.Drawables.IconWeatherFair) as BitmapResource;
        _iconWeatherClouds = WatchUi.loadResource(Rez.Drawables.IconWeatherClouds) as BitmapResource;
        _iconWeatherVariable = WatchUi.loadResource(Rez.Drawables.IconWeatherVariable) as BitmapResource;
        _iconWeatherShowers = WatchUi.loadResource(Rez.Drawables.IconWeatherShowers) as BitmapResource;
        _iconWeatherRain = WatchUi.loadResource(Rez.Drawables.IconWeatherRain) as BitmapResource;
        _iconWeatherStorm = WatchUi.loadResource(Rez.Drawables.IconWeatherStorm) as BitmapResource;
    }

    function onShow() as Void {
    }

    //! Mode economie d'energie (always-on display AMOLED).
    function onEnterSleep() as Void {
        _lowPower = true;
        WatchUi.requestUpdate();
    }

    function onExitSleep() as Void {
        _lowPower = false;
        WatchUi.requestUpdate();
    }

    //! Rendu complet du cadran (appele chaque minute, ou chaque seconde en mode actif).
    function onUpdate(dc as Dc) as Void {
        _width = dc.getWidth();
        _height = dc.getHeight();

        // Fond noir : indispensable sur AMOLED
        if (dc has :setAntiAlias) {
            dc.setAntiAlias(true);
        }
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
        dc.clear();

        var settings = System.getDeviceSettings();
        var data = new WatchData();

        drawBatteryArc(dc, data.batteryRatio());
        drawDate(dc);
        drawMoonPhase(dc);
        drawTime(dc, settings);
        drawAlarmIcon(dc, settings);
        drawGauges(dc, data);
        drawAltitude(dc, data.altitudeText());
        drawZambrettiIcon(dc, data.zambrettiState());
    }

    //! Arc superieur de 90 degres indiquant la batterie de la montre.
    private function drawBatteryArc(dc as Dc, ratio as Float) as Void {
        var cx = _width / 2;
        var cy = _height / 2;
        var radius = (_width * 0.46).toNumber();
        var pct = ratio > 1.0 ? 1.0 : ratio;
        if (pct < 0.0) { pct = 0.0; }

        dc.setPenWidth(4);
        dc.setColor(COLOR_TRACK, Graphics.COLOR_TRANSPARENT);
        dc.drawArc(cx, cy, radius, Graphics.ARC_CLOCKWISE, 135, 45);

        if (pct > 0.0) {
            var end = 135.0 - (90.0 * pct);
            dc.setColor(_lowPower ? dimColor(COLOR_BB) : COLOR_BB, Graphics.COLOR_TRANSPARENT);
            dc.drawArc(cx, cy, radius, Graphics.ARC_CLOCKWISE, 150, end.toNumber());
        }
    }

    // -----------------------------------------------------------------------
    // Date : "9 - VEN"
    // -----------------------------------------------------------------------
    private function drawDate(dc as Dc) as Void {
        var now = Gregorian.info(Time.now(), Time.FORMAT_SHORT);
        var dowIndex = (now.day_of_week as Number) - 1;
        if (dowIndex < 0 || dowIndex > 6) { dowIndex = 0; }

        var text = Lang.format("$1$ - $2$", [
            (now.day as Number).format("%d"),
            _daysFr[dowIndex]
        ]);

        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(
            _width / 2,
            (_height * 0.13).toNumber(),
            Graphics.FONT_XTINY,
            text,
            Graphics.TEXT_JUSTIFY_CENTER
        );
    }

    //! Phase approximative depuis la nouvelle lune de reference, avec un cycle synodique moyen.
    private function drawMoonPhase(dc as Dc) as Void {
        var elapsed = Time.now().value().toFloat() - MOON_REFERENCE_SECONDS;
        var cycles = elapsed / MOON_SYNODIC_SECONDS;
        var phase = cycles - cycles.toNumber().toFloat();
        var phaseIndex = (phase * 8.0 + 0.5).toNumber();
        if (phaseIndex >= 8) { phaseIndex = 0; }
        var centerX = _width / 2;
        var centerY = (_height * 0.235).toNumber();
        var icon = _iconMoonNew;
        if (phaseIndex == 1) { icon = _iconMoonWaxingCrescent; }
        else if (phaseIndex == 2) { icon = _iconMoonFirstQuarter; }
        else if (phaseIndex == 3) { icon = _iconMoonWaxingGibbous; }
        else if (phaseIndex == 4) { icon = _iconMoonFull; }
        else if (phaseIndex == 5) { icon = _iconMoonWaningGibbous; }
        else if (phaseIndex == 6) { icon = _iconMoonLastQuarter; }
        else if (phaseIndex == 7) { icon = _iconMoonWaningCrescent; }

        if (icon != null) {
            var bitmap = icon as BitmapResource;
            dc.drawBitmap(centerX - bitmap.getWidth() / 2, centerY - bitmap.getHeight() / 2, bitmap);
        }
    }

    // -----------------------------------------------------------------------
    // Heure numerique
    // -----------------------------------------------------------------------
    private function drawTime(dc as Dc, settings as System.DeviceSettings) as Void {
        var clock = System.getClockTime();
        var hour = clock.hour;

        if (!settings.is24Hour) {
            hour = hour % 12;
            if (hour == 0) { hour = 12; }
        }

        var text = Lang.format("$1$:$2$", [
            settings.is24Hour ? hour.format("%02d") : hour.format("%d"),
            clock.min.format("%02d")
        ]);

        var font = Graphics.FONT_NUMBER_HOT;
        var fontHeight = dc.getFontHeight(font);

        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(
            _width / 2,
            (_height * 0.40).toNumber() - fontHeight / 2,
            font,
            text,
            Graphics.TEXT_JUSTIFY_CENTER
        );
    }

    // -----------------------------------------------------------------------
    // Icone alarme (dessinee en vectoriel : aucun PNG necessaire)
    // -----------------------------------------------------------------------
    private function drawAlarmIcon(dc as Dc, settings as System.DeviceSettings) as Void {
        // Reglage utilisateur (Garmin Connect) : afficher ou non l'icone
        var show = Application.Properties.getValue("showAlarm");
        if (show instanceof Lang.Boolean && (show as Boolean) == false) {
            return;
        }

        var active = (settings.alarmCount != null) && ((settings.alarmCount as Number) > 0);

        if (_lowPower && !active) {
            return; // rien a afficher en veille si aucune alarme
        }

        var cx = (_width / 2 - 46).toNumber();
        var cy = (_height * 0.235).toNumber();

        // Pictogramme cloche U+1F56D (icon_alarm_on / icon_alarm_off)
        var icon = active ? _iconAlarmOn : _iconAlarmOff;
        if (icon != null) {
            var bmp = icon as BitmapResource;
            dc.drawBitmap(cx - bmp.getWidth() / 2, cy - bmp.getHeight() / 2, bmp);
        }
    }

    // -----------------------------------------------------------------------
    // 4 jauges circulaires : pas, frequence cardiaque, body battery, stress
    // -----------------------------------------------------------------------
    private function drawGauges(dc as Dc, data as WatchData) as Void {
        var radius  = (_width * 0.082).toNumber();
        var spacing = (_width * 0.23).toNumber();
        var cy      = (_height * 0.64).toNumber();
        var cx0     = _width / 2 - (spacing * 3) / 2;

        drawGauge(dc, cx0,                 cy, radius, data.stepsRatio(),  COLOR_STEPS,  data.stepsText(),  _iconSteps);
        drawGauge(dc, cx0 + spacing,       cy, radius, data.hrRatio(),     COLOR_HR,     data.hrText(),     _iconHr);
        drawGauge(dc, cx0 + spacing * 2,   cy, radius, data.bodyRatio(),   COLOR_BB,     data.bodyText(),   _iconBb);
        drawGauge(dc, cx0 + spacing * 3,   cy, radius, data.stressRatio(), COLOR_STRESS, data.stressText(), _iconStress);
    }

    //! Affiche l'altitude sous les jauges avec un petit symbole de montagne.
    private function drawAltitude(dc as Dc, value as String) as Void {
        var centerX = _width / 2;
        var baseline = (_height * 0.92).toNumber();
        var metricFont = Graphics.FONT_SYSTEM_XTINY;
        var lineHeight = dc.getFontHeight(metricFont);
        var altitudeY = baseline - lineHeight;
        var textX = centerX + 5;
        var mountainX = centerX - 22;
        var mountainBottom = baseline - 1;
        var mountainTop = mountainBottom - 8;

        dc.setPenWidth(2);
        dc.setColor(COLOR_ALTITUDE, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(mountainX, mountainBottom, mountainX + 5, mountainTop);
        dc.drawLine(mountainX + 5, mountainTop, mountainX + 10, mountainBottom);
        dc.drawLine(mountainX + 7, mountainBottom, mountainX + 12, mountainBottom - 6);
        dc.drawLine(mountainX + 12, mountainBottom - 6, mountainX + 17, mountainBottom);

        dc.setPenWidth(1);
        dc.setColor(COLOR_ALTITUDE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(textX, altitudeY, metricFont, value, Graphics.TEXT_JUSTIFY_LEFT);
    }

    //! Affiche le PNG Segoe UI Emoji associe a l'etat Zambretti.
    private function drawZambrettiIcon(dc as Dc, state as Number or Null) as Void {
        if (state == null) { return; }

        var cx = (_width / 2 + 46).toNumber();
        var cy = (_height * 0.235).toNumber();
        var icon = _iconWeatherStorm;
        if (state == 0) { icon = _iconWeatherStable; }
        else if (state == 1) { icon = _iconWeatherFair; }
        else if (state == 2) { icon = _iconWeatherClouds; }
        else if (state == 3) { icon = _iconWeatherVariable; }
        else if (state == 4) { icon = _iconWeatherShowers; }
        else if (state == 5) { icon = _iconWeatherRain; }

        if (icon == null) { return; }
        var bitmap = icon as BitmapResource;
        dc.drawBitmap(cx - bitmap.getWidth() / 2, cy - bitmap.getHeight() / 2, bitmap);
    }

    //! Dessine une jauge : anneau de fond, arc de progression, valeur et pictogramme.
    private function drawGauge(
        dc as Dc,
        cx as Number, cy as Number, r as Number,
        ratio as Float,
        color as Number,
        value as String,
        icon as BitmapResource?
    ) as Void {

        var penWidth = (r * 0.28).toNumber();
        if (penWidth < 3) { penWidth = 3; }

        // Anneau de fond
        dc.setPenWidth(penWidth);
        dc.setColor(COLOR_TRACK, Graphics.COLOR_TRANSPARENT);
        dc.drawCircle(cx, cy, r);

        // Arc de progression (sens horaire depuis midi)
        if (ratio > 0.0) {
            var pct = ratio > 1.0 ? 1.0 : ratio;
            dc.setColor(_lowPower ? dimColor(color) : color, Graphics.COLOR_TRANSPARENT);
            if (pct >= 0.999) {
                dc.drawCircle(cx, cy, r);
            } else {
                var end = 90.0 - 360.0 * pct;
                while (end < 0.0) { end += 360.0; }
                dc.drawArc(cx, cy, r, Graphics.ARC_CLOCKWISE, 90, end.toNumber());
            }
        }

        // Valeur au centre
        dc.setPenWidth(1);
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        var vFont = Graphics.FONT_XTINY;
        dc.drawText(cx, cy - dc.getFontHeight(vFont) / 2, vFont, value, Graphics.TEXT_JUSTIFY_CENTER);

        // Pictogramme sous la jauge (chaussure, coeur, batterie, eclair)
        if (icon != null) {
            var bmp = icon as BitmapResource;
            dc.drawBitmap(cx - bmp.getWidth() / 2, cy + r + 2, bmp);
        }
    }

    //! Assombrit une couleur pour le mode veille (economie AMOLED).
    private function dimColor(color as Number) as Number {
        var r = ((color >> 16) & 0xFF) / 3;
        var g = ((color >> 8) & 0xFF) / 3;
        var b = (color & 0xFF) / 3;
        return (r << 16) | (g << 8) | b;
    }
}
