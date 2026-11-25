# Raw Cycle

Ein modernes Flutter-Grundgerüst für eine Zyklus- und Frauen-Gesundheits-App.

## Starten

```bash
flutter pub get
flutter run
```

Die App verwendet Material 3 und passt das helle oder dunkle Theme automatisch
an die Systemeinstellung an.

## Struktur

- `lib/app.dart`: App-Einstieg und Theme-Konfiguration
- `lib/core/theme/`: Farb- und Theme-Definitionen
- `lib/features/calendar/`: lokalisierte Monatskalenderansicht
- `lib/features/navigation/`: Navigation und Seiten-Platzhalter
- `lib/features/cycle_tracking/data/`: Zykluseintragsmodell und lokale Hive-CE-Datenbank

Zykluseinträge werden ausschließlich lokal auf dem Gerät gespeichert. Pro
Kalendertag gibt es einen Eintrag; erneutes Speichern aktualisiert diesen.
Nach Änderungen an Hive-Modellen Adapterdateien neu generieren:

```bash
dart run build_runner build
```
