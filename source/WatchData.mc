import Toybox.Application;
import Toybox.Activity;
import Toybox.ActivityMonitor;
import Toybox.Lang;
import Toybox.Math;
import Toybox.System;
import Toybox.SensorHistory;
import Toybox.Time;

//! Acces centralise aux metriques affichees par le cadran :
//! pas, frequence cardiaque, batterie de la montre, body battery, stress.
//! Chaque accesseur renvoie :
//!   - xxxRatio() : un Float 0.0 -> 1.0 pour l'arc de la jauge
//!   - xxxText()  : la valeur a afficher ("--" si indisponible)
class WatchData {

    private const HR_MIN = 40.0;
    private const HR_MAX = 180.0;
    private const STRESS_SAMPLE_COUNT = 10;

    private var _steps as Number = 0;
    private var _stepGoal as Number = 0;
    private var _hr as Number or Null = null;
    private var _battery as Float = 0.0;
    private var _altitude as Number or Null = null;
    private var _zambrettiState as Number or Null = null;
    private var _zambrettiIndex as Number or Null = null;
    private var _zambrettiLetter as String or Null = null;
    private var _body as Number or Null = null;
    private var _stress as Number or Null = null;

    function initialize() {
        readActivityMonitor();
        readHeartRate();
        _battery = System.getSystemStats().battery;
        _altitude = readAltitude();
        _zambrettiState = readZambrettiState();
        _body = readWithCache(readBodyBattery(), "last_body_battery");
        _stress = readWithCache(readStress(), "last_stress");
    }

    // ----------------------------------------------------------- Pas
    private function readActivityMonitor() as Void {
        var info = ActivityMonitor.getInfo();

        if (info has :steps && info.steps != null) {
            _steps = info.steps as Number;
        }
        if (info has :stepGoal && info.stepGoal != null) {
            _stepGoal = info.stepGoal as Number;
        }
    }

    function stepsRatio() as Float {
        if (_stepGoal <= 0) { return 0.0; }
        return _steps.toFloat() / _stepGoal.toFloat();
    }

    function stepsText() as String {
        if (_steps > 1000) {
            return (_steps.toFloat() / 1000.0).format("%.1f") + "k";
        }
        return _steps.format("%d");
    }

    // -------------------------------------------- Frequence cardiaque
    private function readHeartRate() as Void {
        // 1) capteur temps reel
        var activity = Activity.getActivityInfo();
        if (activity != null && activity.currentHeartRate != null) {
            _hr = activity.currentHeartRate as Number;
            return;
        }

        // 2) dernier echantillon de l'historique
        var iterator = ActivityMonitor.getHeartRateHistory(1, true);

        var sample = iterator.next();
        if (sample != null
            && sample.heartRate != null
            && sample.heartRate != ActivityMonitor.INVALID_HR_SAMPLE) {
            _hr = sample.heartRate as Number;
        }
    }

    function hrRatio() as Float {
        if (_hr == null) { return 0.0; }
        var ratio = ((_hr as Number).toFloat() - HR_MIN) / (HR_MAX - HR_MIN);
        if (ratio < 0.0) { return 0.0; }
        if (ratio > 1.0) { return 1.0; }
        return ratio;
    }

    function hrText() as String {
        return _hr == null ? "--" : (_hr as Number).format("%d");
    }

    function batteryRatio() as Float {
        var ratio = _battery / 100.0;
        if (ratio < 0.0) { return 0.0; }
        if (ratio > 1.0) { return 1.0; }
        return ratio;
    }

    //! Dernier echantillon d'altitude en metres (null si indisponible).
    private function readAltitude() as Number or Null {
        if (!(Toybox has :SensorHistory)) { return null; }
        if (!(Toybox.SensorHistory has :getElevationHistory)) { return null; }

        return latestSample(SensorHistory.getElevationHistory({
            :period => 1,
            :order => SensorHistory.ORDER_NEWEST_FIRST
        }));
    }

    function altitudeText() as String {
        return _altitude == null ? "--m" : (_altitude as Number).format("%d") + "m";
    }

    //! Calcule une classe Zambretti a partir de la pression en hPa et de sa tendance sur 3 h.
    private function readZambrettiState() as Number or Null {
        if (!(Toybox has :SensorHistory)) { return null; }
        if (!(Toybox.SensorHistory has :getPressureHistory)) { return null; }
        if (_altitude == null) { return null; }

        var altitudeMeters = (_altitude as Number).toFloat();
        // Zambretti attend une pression ramenee au niveau de la mer, pas la pression locale.
        var currentTime = 0.0;

        var iterator = SensorHistory.getPressureHistory({
            :period => new Time.Duration(10800),
            :order => SensorHistory.ORDER_NEWEST_FIRST
        });

        var current = iterator.next();
        if (current == null || current.data == null) { return null; }

        var pressure = ZambrettiCalculator.seaLevelPressure(current.data as Numeric, altitudeMeters);
        currentTime = current.when.value().toFloat();
        var oldestPressure = pressure;
        var oldestTime = currentTime;
        var sample = iterator.next();
        while (sample != null) {
            if (sample.data != null) {
                oldestPressure = ZambrettiCalculator.seaLevelPressure(sample.data as Numeric, altitudeMeters);
                oldestTime = sample.when.value().toFloat();
            }
            sample = iterator.next();
        }

        // Normalise la variation mesuree a une fenetre de 3 h; moins de 30 min est considere stable.
        var trend = 0;
        var elapsed = currentTime - oldestTime;
        if (elapsed >= 1800.0) {
            var changePerThreeHours = (pressure - oldestPressure) * 10800.0 / elapsed;
            if (changePerThreeHours > 0.5) {
                trend = 1;
            } else if (changePerThreeHours < -0.5) {
                trend = -1;
            }
        }

        var forecastIndex = ZambrettiCalculator.forecastIndex(pressure, trend);
        var letter = ZambrettiCalculator.forecastLetter(forecastIndex);
        _zambrettiIndex = forecastIndex;
        _zambrettiLetter = letter;
        return ZambrettiCalculator.stateForLetter(letter);
    }

    function zambrettiState() as Number or Null {
        return _zambrettiState;
    }

    function zambrettiDebugText() as String or Null {
        if (_zambrettiIndex == null || _zambrettiLetter == null) { return null; }
        return "Z" + (_zambrettiIndex as Number).format("%d") + "/" + (_zambrettiLetter as String);
    }

    // --------------------------------- Body battery / stress (0 - 100)
    //! Dernier echantillon de Body Battery (null si indisponible).
    private function readBodyBattery() as Number or Null {
        if (!(Toybox has :SensorHistory)) { return null; }
        if (!(Toybox.SensorHistory has :getBodyBatteryHistory)) { return null; }

        return latestSample(SensorHistory.getBodyBatteryHistory({
            :period => 1,
            :order => SensorHistory.ORDER_NEWEST_FIRST
        }));
    }

    //! Moyenne des derniers echantillons de stress disponibles.
    private function readStress() as Number or Null {
        if (!(Toybox has :SensorHistory)) { return null; }
        if (!(Toybox.SensorHistory has :getStressHistory)) { return null; }

        return averageSamples(SensorHistory.getStressHistory({
            :period => STRESS_SAMPLE_COUNT,
            :order => SensorHistory.ORDER_NEWEST_FIRST
        }));
    }

    //! Calcule la moyenne des valeurs presentes dans un iterateur.
    private function averageSamples(iterator as SensorHistory.SensorHistoryIterator or Null) as Number or Null {
        if (iterator == null) { return null; }

        var total = 0.0;
        var count = 0;
        var sample = iterator.next();
        while (sample != null) {
            if (sample.data != null) {
                total += (sample.data as Numeric).toNumber().toFloat();
                count += 1;
            }
            sample = iterator.next();
        }

        if (count == 0) { return null; }
        return (total / count).toNumber();
    }

    //! Extrait la valeur du premier echantillon d'un iterateur SensorHistory.
    private function latestSample(iterator as SensorHistory.SensorHistoryIterator or Null) as Number or Null {
        if (iterator == null) { return null; }

        var sample = iterator.next();
        if (sample == null || sample.data == null) { return null; }
        return (sample.data as Numeric).toNumber();
    }

    //! Conserve la derniere mesure valide pour les actualisations sans nouvel echantillon.
    private function readWithCache(current as Number or Null, key as String) as Number or Null {
        var cached = Application.Storage.getValue(key);
        if (current != null) {
            if (cached == null || !(cached instanceof Lang.Number) || (cached as Number) != current) {
                Application.Storage.setValue(key, current);
            }
            return current;
        }

        return cached instanceof Lang.Number ? cached as Number : null;
    }

    function bodyRatio() as Float {
        return _body == null ? 0.0 : (_body as Number).toFloat() / 100.0;
    }

    function bodyText() as String {
        return _body == null ? "--" : (_body as Number).format("%d");
    }

    function stressRatio() as Float {
        return _stress == null ? 0.0 : (_stress as Number).toFloat() / 100.0;
    }

    function stressText() as String {
        return _stress == null ? "--" : (_stress as Number).format("%d");
    }
}
