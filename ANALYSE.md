# ToDo-List Plasma Applet - Technische Analyse

## Projektübersicht

**Projektname**: ToDo-List
**Typ**: KDE Plasma Applet (Plasmoid)
**Zweck**: Ein natives To-Do-Listen-Widget für den KDE Plasma Desktop

## Verzeichnisstruktur

```
.
├── .gitignore
├── Readme.md
├── metadata.json
└── contents/
    ├── config/
    │   └── main.xml
    ├── locale/
    │   └── de/
    │       └── LC_MESSAGES/
    │           ├── plasma_applet_de.marc.todo.mo
    │           └── plasma_applet_de.marc.todo.po
    └── ui/
        ├── TaskDelegate.qml
        ├── TaskModel.qml
        └── main.qml
```

## Technische Details

### 1. metadata.json
Enthält die Metadaten für das Plasma-Applet:
- Name: "Task List"
- ID: "de.marc.todo"
- Version: 1.0
- KDE Frameworks: 6
- X-KDE-ServiceTypes: ["Plasma/Applet"]

### 2. contents/config/main.xml
Definiert das Konfigurationsschema:
```xml
<entry name="tasksJson" type="String">
    <default>[]</default>
</entry>
```

### 3. UI-Komponenten

**a. main.qml**:
- Hauptbenutzeroberfläche mit Aufgabenliste
- Eingabefeld für neue Aufgaben
- Fußzeile mit Aufgabenanzahl

**b. TaskModel.qml**:
- Datenmodell für Aufgaben
- JSON-basierte Persistenz
- CRUD-Operationen
- Drag & Drop-Unterstützung

**c. TaskDelegate.qml**:
- Darstellung einzelner Aufgaben
- Prioritätsanzeige
- Fälligkeitsdatum
- Bearbeitungsoptionen
- Drag & Drop-Funktionalität

## Funktionsweise

1. **Datenfluss**:
   - Aufgaben → JSON → Plasma-Konfiguration → TaskModel → UI

2. **Hauptfunktionen**:
   - Aufgaben hinzufügen/entfernen
   - Aufgaben als erledigt markieren
   - Aufgaben priorisieren
   - Fälligkeitsdaten setzen
   - Drag & Drop zum Neuordnen
   - Erledigte Aufgaben löschen

## Technische Umsetzung

- **Programmiersprache**: QML (Qt Modeling Language)
- **Framework**: KDE Plasma 6 / Qt 6
- **Datenformat**: JSON für Aufgabenpersistenz
- **UI-Komponenten**: PlasmaComponents für KDE-konformes Aussehen

## Zusammenfassung

Dies ist ein KDE Plasma 6 Applet, das als To-Do-Liste fungiert. Es integriert sich in die Plasma-Desktopumgebung und bietet eine vollständige Aufgabenverwaltungslösung mit Persistenz, Drag & Drop-Funktionalität und einer anpassbaren Benutzeroberfläche.

## Status nach Reparatur (6. April 2026)

### Durchgeführte Fixes
- **main.qml**: Vollständig umgebaut mit konsistenten Qt6/Plasma-6/Kirigami-Imports
- **Struktur**: Fehlerhaft verschachtelte Container und Properties korrigiert
- **ListView**: Auf QtQuick.ListView migriert statt PlasmaComponents.ListView
- **Heading**: Kirigami.Heading statt PlasmaComponents.Label
- **Controls**: QtControls-Varianten für Qt6-Konsistenz
- **ToolTip**: Standardisierte QtControls.ToolTip-API
- **metadata.json**: KPackageStructure und X-Plasma-MainScript hinzugefügt

### Test-Ergebnis
✅ Applet ladet erfolgreich in plasmoidviewer
✅ Keine kritischen Ladefehler
✅ QML-Struktur ist Plasma-6-konform

## Empfehlungen für weitere Entwicklung

1. **Erweiterungen**:
    - Aufgabenfilterung und -sortierung
    - Kategorienverwaltung
    - Wiederkehrende Aufgaben
    - Drag & Drop zum Neuordnen

2. **Technische Verbesserungen**:
    - Unit Tests für AufgabenModell
    - Performance-Optimierung für große Aufgabenlisten
    - Barrierefreiheitsverbesserungen
    - Nextcloud-Synchronisation vollständig implementieren
