# Guide du dépôt

## Projet

Ce dépôt contient un cadran Garmin Connect IQ écrit en Monkey C pour la Venu 3 (`venu3`, 454x454) et la Venu 3S (`venu3s`, 390x390). Toute modification doit rester compatible avec les deux appareils et les API Connect IQ configurées dans le projet.

## Responsabilités des fichiers

- `source/Venu3App.mc` gère le démarrage de l’application et les notifications de changement des réglages.
- `source/Venu3WatchFaceView.mc` gère la mise en page, le dessin, les couleurs et le rendu basse consommation.
- `source/WatchData.mc` gère la lecture des métriques d’activité et de santé, ainsi que leurs valeurs et ratios d’affichage.
- `resources/` contient les ressources et réglages communs ; `resources-fre/` contient les traductions françaises ; `resources-venu3/` et `resources-venu3s/` contiennent les ressources propres à chaque appareil.
- `monkey.jungle` configure les chemins des sources et ressources ainsi que le manifeste.

Respectez le style Monkey C existant et limitez chaque modification au module concerné. Protégez les appels aux API facultatives lorsque leur disponibilité peut varier selon l’appareil ou la version de l’API. Conservez le comportement des données indisponibles (`--` et jauge vide), sauf demande contraire.

## Compilation et validation

Depuis la racine du dépôt, lancez ces commandes dans PowerShell :

```powershell
.\scripts\build.ps1 -Device venu3
.\scripts\build.ps1 -Device venu3s
```

Les deux compilations nécessitent un SDK Connect IQ configuré et une clé développeur. Le script peut générer `developer_key.der` si le fichier est absent ; cette clé est une donnée d’identité locale : ne la publiez pas et ne la remplacez pas sans raison.

Pour générer un aperçu visuel sans le SDK, lancez `.\scripts\preview.ps1 -Size 454` ou utilisez `-Size 390` pour la Venu 3S. La validation dans le simulateur est disponible avec `.\scripts\run.ps1 -Device venu3` (ou `venu3s`) ; elle nécessite le SDK et le simulateur.

Le dépôt ne contient pas de suite de tests automatisés distincte. Après une modification des sources ou des ressources, compilez chaque appareil concerné ; utilisez l’aperçu ou le simulateur si le rendu ou le comportement propre à un appareil a changé.

## Fichiers générés et sensibles

Ne modifiez pas manuellement les aperçus générés ni les artefacts de compilation dans `preview/` et `bin/`. N’exposez pas, ne remplacez pas et ne validez pas les clés développeur dans le dépôt. Limitez les changements au besoin demandé et ne modifiez pas l’identité de l’application ni sa configuration de paquetage sans demande explicite.
