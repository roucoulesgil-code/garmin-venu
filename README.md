# Garmin Venu 3 — Cadran Connect IQ (exemple complet)

Projet Connect IQ (Monkey C) prêt à l'emploi : **watchface** pour **Garmin Venu 3**
(`venu3`, 454 × 454) et **Venu 3S** (`venu3s`, 390 × 390).

## Installation avec la version 2

Ce projet est la version 1, affichee sous le nom **Garmin Venu 1**.
Son identifiant Connect IQ reste `7f3c9a21d84e4b5c8f26ad10e5b3c704`.
La version 2 utilise un identifiant distinct : les deux cadrans peuvent etre
installes ensemble, avec leurs propres reglages. Un seul cadran est actif a la fois.

Les compilations produisent `bin/Garmin-venu-1-venu3.prg` et
`bin/Garmin-venu-1-venu3s.prg`; le paquet Store est `bin/Garmin-venu-1.iq`.
Depuis chaque projet, lancer `./scripts/deploy.ps1 -Device venu3` (ou `venu3s`)
pour installer sa version, puis choisir le cadran dans les reglages de la montre.
Les anciens fichiers sans numero de version ne doivent plus etre utilises.

## Rendu du cadran

```
             arc batterie montre
                 9 - VEN          <- jour du mois + jour de la semaine
       [alarme]    [lune]    [météo] <- alarme, phase lunaire, prévision Zambretti
                 10:42            <- heure numérique (12/24 h automatique)
        (5.2k)     (72)      (85)      (12) <- valeurs au centre des jauges
        👟         💖        💪         😟  <- pas, FC, Body Battery, stress
                 ⛰ 127 m          <- altitude
```

| Jauge | Pictogramme | Source | Progression de l'arc | Couleur |
|---|---|---|---|---|
| Pas | 👟 `U+1F45F` | `ActivityMonitor.getInfo().steps` | pas / objectif du jour | bleu `#00AAFF` |
| FC | 💖 `U+1F493` | `Activity.getActivityInfo().currentHeartRate`, repli sur `ActivityMonitor.getHeartRateHistory` | normalisée 40–180 bpm | rouge `#FF3B30` |
| Body Battery | 💪 `U+1F4AA` | `SensorHistory.getBodyBatteryHistory` | 0–100 | vert `#34C759` |
| Stress | 😟 `U+1F615` | `SensorHistory.getStressHistory` | 0–100 | orange `#FF9500` |
| Batterie montre | arc supérieur | `System.getSystemStats().battery` | charge restante | vert `#34C759` |
| Altitude | montagne | `SensorHistory.getElevationHistory` | mètres | mauve `#C080A0` |
| Prévision météo | PNG Segoe UI Emoji | Zambretti adapté, pression + tendance sur 3 h | 7 états | couleurs météo |

> Les pictogrammes des jauges, de la lune et de la météo sont des PNG générés depuis
> Segoe UI Emoji par `scripts\make-icons.ps1` :
> ```powershell
> .\scripts\make-icons.ps1 -IconSize 40     # -> resources\drawables\icon_*.png
> ```
> Changer un pictogramme = modifier le code point dans ce script et relancer.

Valeur indisponible → affichage `--` et arc vide (jamais de plantage).
Mode veille (always-on AMOLED) : fond noir, couleurs atténuées, icône alarme masquée
si aucune alarme n'est active.

### Aperçu sans SDK

Une maquette PNG reprenant exactement les proportions du code est générée par :

```powershell  -ExecutionPolicy Bypass 
.\scripts\preview.ps1 -Size 454    # Venu 3  -> preview\venu3-preview-454.png
.\scripts\preview.ps1 -Size 390    # Venu 3S -> preview\venu3-preview-390.png
```

Paramètres disponibles pour simuler les valeurs :
`-Steps`, `-StepGoal`, `-Hr`, `-Battery`, `-Altitude`, `-Pressure`,
`-PressureTrend` (`rising`, `steady`, `falling`), `-BodyBattery`, `-Stress`,
`-MoonPhase`, `-AlarmActive`.

### Phase lunaire

`drawMoonPhase()` utilise une nouvelle lune de référence le 6 janvier 2000 à 18:14 UTC
et une durée moyenne de cycle synodique de 2 551 442,89 secondes (29,5305888 jours).
La fraction du cycle est arrondie à l'une des huit images Segoe UI Emoji
`U+1F311`–`U+1F318`. La phase reste approximative, basée sur une période moyenne,
sans correction des irrégularités orbitales.

### Calcul et icônes Zambretti

`WatchData.readZambrettiState()` lit l'historique barométrique sur 3 h. Les valeurs
supérieures à 2 000 sont interprétées en Pa et converties en hPa; les valeurs plus
basses sont déjà en hPa/mbar. Comme le baromètre mesure la pression locale, le calcul
la ramène au niveau de la mer à partir de l'altitude `h` en mètres :
`P0 = P_locale / (1 - h / 44330)^5,255`. Sans altitude, l'icône météo est masquée
plutôt que de produire une prévision trompeuse. La variation est ramenée à 3 h : au
moins `+0,5 hPa/3 h` signifie pression en hausse, au plus `-0,5 hPa/3 h` pression en
baisse; entre ces seuils, ou avec moins de 30 minutes d'historique, elle est stable.

La formule empirique dépend de cette tendance, avec `P` en hPa :

| Tendance | Calcul de l'indice Z | Plage utilisée |
|---|---|---|
| Baisse | `130 - P / 8,1` | 1–9 |
| Stable | `147 - P / 7,52` | 10–19 |
| Hausse | `179 - P / 6,45` | 20–32 |

L'indice arrondi sélectionne une lettre dans la table Zambretti, puis les lettres
sont regroupées pour garder sept petites icônes lisibles :

| État | Lettres | PNG Segoe UI Emoji |
|---|---|---|
| Temps très stable | A | soleil `U+2600` |
| Beau temps | B–C | soleil avec visage `U+1F31E` |
| Nuageux avec éclaircies | D–I | soleil et nuage `U+1F325` |
| Variable | J–O | visage dans le vent `U+1F32C` |
| Risque d'averses | P–R | soleil et pluie `U+1F326` |
| Pluie | S–X | nuage et pluie `U+1F327` |
| Tempête | Y–Z | nuage avec éclair `U+1F329` |

Les fichiers `icon_moon_*.png` et `icon_weather_*.png` sont chargés par
`Venu3WatchFaceView.mc`; ils sont générés par `scripts\make-icons.ps1`.
Cette adaptation n'applique pas les corrections saisonnières et de direction du
vent de l'instrument historique, car ces entrées ne sont pas utilisées par le cadran.

## 1. Prérequis

| Outil | Rôle | Lien / commande |
|---|---|---|
| JDK 17+ (64 bits) | requis par le compilateur `monkeyc` | `winget install EclipseAdoptium.Temurin.17.JDK` |
| Connect IQ SDK Manager | téléchargement du SDK + des devices | https://developer.garmin.com/connect-iq/sdk/ |
| VS Code + extension **Monkey C** (`garmin.monkey-c`) | éditeur officiel, debug, simulateur | https://marketplace.visualstudio.com/items?itemName=garmin.monkey-c |
| OpenSSL | génération de la clé développeur | fourni par Git for Windows (`C:\Program Files\Git\usr\bin\openssl.exe`) |

### Installation du SDK
1. Lancer le **SDK Manager**, se connecter avec un compte Garmin.
2. Onglet *SDK* : installer la dernière version (≥ 7.x) et la marquer **current**.
3. Onglet *Devices* : cocher et télécharger **Venu 3** et **Venu 3S**.

Le SDK courant est résolu automatiquement par les scripts via
`%APPDATA%\Garmin\ConnectIQ\current-sdk.cfg`.
Pour forcer un chemin : `$env:CIQ_SDK_HOME = "C:\chemin\vers\connectiq-sdk"`.

## 2. Clé développeur (obligatoire pour compiler)

```powershell
cd C:\D\projet_DSTG\Garmin
.\scripts\new-developer-key.ps1
```

Crée `developer_key.der` à la racine. **Ce fichier est ignoré par git** : sauvegarder
une copie hors dépôt (c'est elle qui identifie vos applis sur le store).

## 3. Compiler / exécuter

### En ligne de commande
```powershell
.\scripts\build.ps1 -Device venu3          # compile -> bin\Garmin-venu-1-venu3.prg
.\scripts\build.ps1 -Device venu3s
.\scripts\run.ps1  -Device venu3           # compile + lance le simulateur
.\scripts\test-zambretti.ps1 -Device venu3s # tests unitaires Zambretti dans le simulateur
.\scripts\package.ps1                      # génère bin\Garmin-venu-1.iq (store)
```


powershell -ExecutionPolicy Bypass -File E:\eclipse\PROJETS\Garmin/scripts/build.ps1 -Device venu3s
powershell -ExecutionPolicy Bypass -File E:\eclipse\PROJETS\Garmin/scripts/preview.ps1  -Device venu3

### Tests unitaires Zambretti

Avec le SDK Connect IQ et le simulateur installés, lancez :

```powershell
.\scripts\test-zambretti.ps1 -Device venu3s
```

Le script compile avec l'option `-t`, puis exécute les méthodes `(:test)` de
`source/ZambrettiTests.mc` dans le simulateur. Le résultat `PASSED` ou `FAILED`
et le détail de chaque test sont affichés dans le terminal. Utilisez
`-Device venu3` pour tester l'autre modèle.

La suite vérifie la conversion Pa/hPa, la correction d'altitude, les plages des
trois tendances et que l'indice `Z2` ne produit pas la lettre `B`.

### Dans VS Code
- `Ctrl+Shift+B` → **CIQ: Build Venu 3**
- `F5` → configuration **Venu 3 - Simulateur** (debug pas à pas, points d'arrêt)
- `Ctrl+Shift+P` → *Monkey C: Run App / Edit Application Settings / Build for Device*

## 4. Structure

```
Garmin/
├── manifest.xml                 # type=watchface, devices venu3/venu3s, permissions, API 5.0.0
├── monkey.jungle                # configuration de build (sources, ressources, typecheck)
├── source/
│   ├── Venu3App.mc              # AppBase : retourne le cadran
│   ├── Venu3WatchFaceView.mc    # WatchFace : date, heure, icône alarme, 4 jauges
│   ├── WatchData.mc             # lecture des métriques et capteurs
│   ├── ZambrettiCalculator.mc   # calculs purs de pression et prévision
│   └── ZambrettiTests.mc       # tests unitaires Toybox.Test
├── resources/
│   ├── drawables/               # drawables.xml + launcher_icon.png (60×60, généré)
│   ├── settings/settings.xml    # réglages Garmin Connect (showAlarm, accentColor)
│   └── strings/strings.xml      # libellés (anglais)
├── resources-fre/strings/       # traduction française
├── resources-venu3/             # ressources spécifiques Venu 3
├── resources-venu3s/            # ressources spécifiques Venu 3S
├── preview/                     # maquettes PNG générées par scripts/preview.ps1
├── scripts/                     # build / run / package / clé / aperçu / deploy
└── .vscode/                     # launch, tasks, settings, extensions
```

## 5. Tester le cadran dans le simulateur

```powershell
.\scripts\run.ps1 -Device venu3     # compile, ouvre le simulateur et charge le cadran
```
ou, dans VS Code, `F5` → **Venu 3 - Simulateur** (points d'arrêt et `System.println`
disponibles dans la console de debug).

Une fois le simulateur ouvert, forcer les valeurs pour vérifier chaque élément :

| Donnée | Menu du simulateur |
|---|---|
| Alarme (icône allumée) | *Settings > Alarm Count* → mettre 1 (0 = icône grise) |
| Pas / objectif | *Simulation > Activity Monitoring Data* |
| Fréquence cardiaque | *Simulation > Health > Heart Rate* (ou lecture d'un fichier FIT) |
| Body Battery / Stress | *Simulation > Health > Body Battery / Stress* |
| Date et heure | *Simulation > Time* (vérifier le passage DIM → LUN …) |
| Format 12 h / 24 h | *Settings > 12/24 Hour Mode* |
| Mode veille AMOLED | *Simulation > Trigger Watchface Sleep / Wake* |
| Réglages utilisateur | *File > Edit Persistent Storage* ou *Settings > Edit Application Settings* (`showAlarm`) |
| Consommation mémoire | *View > Memory Viewer* (un watchface a un budget limité) |

Vérifier aussi le rendu sur **venu3s** (`.\scripts\run.ps1 -Device venu3s`) : la mise
en page est proportionnelle, mais l'écran 390 px est plus serré.

## 6. Personnalisation rapide

Tout se règle dans `source/Venu3WatchFaceView.mc` :

| Quoi | Où |
|---|---|
| Position date / heure / alarme | constantes `0.20`, `0.40`, `0.545` (fraction de la hauteur) dans `drawDate`, `drawTime`, `drawAlarmIcon` |
| Taille et espacement des jauges | `radius`, `spacing`, `cy` dans `drawGauges` |
| Couleurs | constantes `COLOR_STEPS`, `COLOR_HR`, `COLOR_BB`, `COLOR_STRESS`, `COLOR_ALARM` |
| Jours de la semaine | tableau `_daysFr` |
| Police de l'heure | `Graphics.FONT_NUMBER_THAI_HOT` dans `drawTime` |
| Plage FC de la jauge | `HR_MIN` / `HR_MAX` dans `WatchData.mc` |

## 7. Installer le cadran sur la montre

### Méthode A — script automatique (recommandée)

1. Brancher la Venu 3 en USB, la **déverrouiller** et accepter l'accès aux données.
2. Lancer :

```powershell
.\scripts\deploy.ps1 -Device venu3
```

Le script compile puis copie `bin\Garmin-venu-1-venu3.prg` dans `GARMIN\APPS` de la montre
(gère le mode MTP de la Venu 3, qui n'apparaît pas comme lecteur `E:\`).

3. Débrancher la montre (elle redémarre l'inventaire des applis).
4. Sur la montre : **appui long sur le cadran actuel** → faire défiler jusqu'au nouveau
   cadran, ou *Paramètres > Apparence > Cadran de montre*.

### Méthode B — copie manuelle

1. Compiler : `.\scripts\build.ps1 -Device venu3`
2. Ouvrir l'Explorateur Windows → la montre apparaît sous *Ce PC* (ex. « Venu 3 »).
3. Glisser `bin\Garmin-venu-1-venu3.prg` dans `Internal Storage\GARMIN\APPS`.
4. Débrancher, puis sélectionner le cadran sur la montre.

### Méthode C — depuis VS Code

`Ctrl+Shift+P` → *Tasks: Run Task* → **CIQ: Installer sur la montre (USB)**.
(L'extension Monkey C propose aussi *Monkey C: Build for Device* qui génère le `.prg`
à copier à la main.)

### Points à vérifier si le cadran n'apparaît pas

| Symptôme | Cause / solution |
|---|---|
| Cadran absent de la liste | Le `.prg` doit être dans `GARMIN\APPS` (pas `GARMIN\APPS\LOGS`), montre débranchée |
| « Erreur applicative » au lancement | Regarder `GARMIN\APPS\LOGS\CIQ_LOG.YAML` sur la montre |
| Jauges FC/BB/stress vides | Permission `SensorHistory` refusée : *Garmin Connect > Appareil > Connect IQ > autorisations* |
| Build refusé | `developer_key.der` manquante → `.\scripts\new-developer-key.ps1` |
| Mémoire insuffisante | Supprimer d'autres applis CIQ (la montre limite le nombre de cadrans installés) |

> Un cadran chargé manuellement (sideload) reste installé tant que Garmin Connect ne
> resynchronise pas la liste des applis ; pour une installation permanente, publier
> le `.iq` sur le Connect IQ Store.

## 8. Avant la première publication

- Remplacer l'`id` dans `manifest.xml` par un UUID à vous
  (VS Code : *Monkey C: Generate a New App Id*, ou `[guid]::NewGuid().ToString('N')`).
- Remplacer `resources/drawables/launcher_icon.png` (icône générée automatiquement,
  70 × 70 px) par votre visuel définitif.

## 8. Caractéristiques Venu 3 utiles

| Élément | Venu 3 | Venu 3S |
|---|---|---|
| Écran | AMOLED rond 454 × 454 | AMOLED rond 390 × 390 |
| Tactile | oui | oui |
| Boutons | 3 (Start/Stop, Back, Light) | 3 |
| Connect IQ | niveau 5.x | 5.x |
| Always-On Display | oui (limiter les pixels allumés) | oui |

Bonnes pratiques AMOLED : fond noir, pas de larges aplats clairs, respecter le
mode basse consommation (`onEnterSleep` / `onExitSleep`, déjà implémentés).

## 9. Changer de type d'application

Dans `manifest.xml`, attribut `type` :
- `watchface` (actuel) — cadran, vue `WatchUi.WatchFace` ;
- `watch-app` — application lancée depuis le menu (vue `WatchUi.View` + delegate) ;
- `widget` / `glance` — vue rapide ;
- `datafield` — champ de données d'activité.

## 10. Eclipse

Le plugin Eclipse Connect IQ n'est plus maintenu par Garmin depuis le SDK 3.x :
le projet s'ouvre dans Eclipse comme projet générique (édition des fichiers),
mais **la compilation et le debug passent par VS Code ou les scripts PowerShell**
de `scripts/`.


trouver les png des icons : 
https://icones8.fr/icons/set/phase-de-lune
https://icones8.fr/icons/set/meteo
