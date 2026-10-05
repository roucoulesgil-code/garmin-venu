import Toybox.Lang;
import Toybox.Math;

//! Calculs Zambretti purs, separes des lectures de capteurs de WatchData.
class ZambrettiCalculator {

    //! Convertit Pa ou hPa en pression au niveau de la mer.
    static function seaLevelPressure(rawPressure as Numeric, altitudeMeters as Float) as Float {
        var pressureHpa = rawPressure.toNumber().toFloat();
        if (pressureHpa > 2000.0) { pressureHpa = pressureHpa / 100.0; }

        var correction = Math.pow(1.0 - altitudeMeters / 44330.0, -5.255).toFloat();
        return pressureHpa * correction;
    }

    //! Retourne l'indice Zambretti arrondi selon la tendance: -1 baisse, 0 stable, 1 hausse.
    static function forecastIndex(pressureHpa as Float, trend as Number) as Number {
        var forecastValue = 0.0;
        var minimum = 1.0;
        var maximum = 9.0;
        if (trend > 0) {
            forecastValue = 179.0 - pressureHpa / 6.45;
            minimum = 20.0;
            maximum = 32.0;
        } else if (trend < 0) {
            forecastValue = 130.0 - pressureHpa / 8.1;
        } else {
            forecastValue = 147.0 - pressureHpa / 7.52;
            minimum = 10.0;
            maximum = 19.0;
        }

        if (forecastValue < minimum) { forecastValue = minimum; }
        if (forecastValue > maximum) { forecastValue = maximum; }
        return (forecastValue + 0.5).toNumber();
    }

    //! Lettre de prevision correspondant a un indice Zambretti valide (1 a 32).
    static function forecastLetter(index as Number) as String {
        var letters = ["", "A", "D", "D", "H", "O", "R", "U", "V", "X", "A", "B", "E", "K", "N", "P", "S", "W", "X", "Z", "A", "B", "C", "F", "G", "I", "J", "L", "M", "Q", "T", "Y", "Z"];
        return letters[index] as String;
    }

    //! Etat d'icone 0-6 associe a une lettre Zambretti.
    static function stateForLetter(letter as String) as Number {
        if (letter.equals("A")) { return 0; }
        if (letter.equals("B") || letter.equals("C")) { return 1; }
        if (letter.equals("D") || letter.equals("E") || letter.equals("F") || letter.equals("G") || letter.equals("H") || letter.equals("I")) { return 2; }
        if (letter.equals("J") || letter.equals("K") || letter.equals("L") || letter.equals("M") || letter.equals("N") || letter.equals("O")) { return 3; }
        if (letter.equals("P") || letter.equals("Q") || letter.equals("R")) { return 4; }
        if (letter.equals("S") || letter.equals("T") || letter.equals("U") || letter.equals("V") || letter.equals("W") || letter.equals("X")) { return 5; }
        return 6;
    }
}
