import Toybox.Lang;
import Toybox.Test;

//! Tests purs du calcul Zambretti, executes dans le simulateur avec -t.
class ZambrettiTests {

    (:test)
    static function testPressureUnits(logger as Test.Logger) as Boolean {
        var hPa = ZambrettiCalculator.seaLevelPressure(1024.0, 0.0);
        var pascals = ZambrettiCalculator.seaLevelPressure(102400.0, 0.0);
        Test.assertEqual(1024.0, hPa);
        Test.assertEqual(hPa, pascals);
        logger.debug("Pa et hPa donnent la meme pression normalisee");
        return true;
    }

    (:test)
    static function testElevationCorrection(logger as Test.Logger) as Boolean {
        var seaLevelPressure = ZambrettiCalculator.seaLevelPressure(1024.0, 95.0);
        Test.assert(seaLevelPressure > 1035.0);
        Test.assert(seaLevelPressure < 1036.0);
        logger.debug("1024 hPa a 95 m est corrige au niveau de la mer");
        return true;
    }

    (:test)
    static function testZ2DoesNotMapToB(logger as Test.Logger) as Boolean {
        var pressure = ZambrettiCalculator.seaLevelPressure(1024.0, 95.0);
        var index = ZambrettiCalculator.forecastIndex(pressure, -1);
        var letter = ZambrettiCalculator.forecastLetter(index);
        var state = ZambrettiCalculator.stateForLetter(letter);
        Test.assertEqual(2, index);
        Test.assertEqual("D", letter);
        logger.debug("Lettre Zambretti=" + letter + ", etat calcule=" + state.format("%d"));
        Test.assertEqual(2, state);
        logger.debug("L'indice Z2 ne produit plus la lettre B");
        return true;
    }

    (:test)
    static function testForecastRangesAndStormMapping(logger as Test.Logger) as Boolean {
        var pressure = 1013.0;
        var fallingIndex = ZambrettiCalculator.forecastIndex(pressure, -1);
        var steadyIndex = ZambrettiCalculator.forecastIndex(pressure, 0);
        var risingIndex = ZambrettiCalculator.forecastIndex(pressure, 1);
        Test.assert(fallingIndex >= 1 && fallingIndex <= 9);
        Test.assert(steadyIndex >= 10 && steadyIndex <= 19);
        Test.assert(risingIndex >= 20 && risingIndex <= 32);
        Test.assertEqual(6, ZambrettiCalculator.stateForLetter("Z"));
        logger.debug("Les plages de tendance et l'etat tempete sont coherents");
        return true;
    }
}
