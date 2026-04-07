# KDE Plasma 6 To-Do List Applet

**English** | [Deutsch](#deutsch)

A native, lightweight to-do list widget for KDE Plasma 6. Manage your daily tasks directly from your desktop with a clean, integrated UI.

## Features

-  **Add, edit, and delete tasks** – Manage your to-do list efficiently
-  **Structured subentries** – Convert tasks into visible subentries with their own checkbox and priority state
-  **Drag-and-drop organization** – Reorder tasks vertically or drag right to turn them into subentries
-  **Live drag preview** – The widget highlights source and target while dragging
-  **Priority levels** – Mark tasks as low, medium, or high priority with visual indicators
-  **Due dates** – Set and track task deadlines
-  **Persistent storage** – Tasks are saved automatically in Plasma configuration
-  **Plasma-integrated design** – Respects your system theme (light/dark)
-  **Responsive layout** – Works on desktop, horizontal, and vertical panels
-  **Fast and lightweight** – Pure QML, no external dependencies
-  **Nextcloud integration** – (Framework ready, opt-in configuration)

## Installation

### From Source

1. **Clone the repository:**
   ```bash
   git clone https://github.com/EduardMayer-IT/kde-plasma-todo-applet.git
   cd kde-plasma-todo-applet
   ```

2. **Install the applet:**
   ```bash
   kpackagetool6 -t Plasma/Applet -i .
   ```

3. **Restart Plasma Shell:**
   ```bash
   kquitapp6 plasmashell
   plasmashell &
   ```

4. **Add the widget:**
   - Right-click on your desktop or panel
   - Select "Add Widgets" / "Widgets konfigurieren"
   - Search for "Aufgabenliste" or "Task List"
   - Click "Add Widget"

### System Requirements

- **KDE Plasma 6** (tested on Plasma 6.0+)
- **Qt 6** (Qt 6.4 or later)
- **Kirigami** (already included with Plasma)

## Usage

### Adding Tasks
1. Type your task description in the input field at the bottom
2. Press **Enter** or click "Hinzufügen" (Add)

### Managing Tasks
- **Mark as done:** Click the checkbox to toggle completion status
- **Delete:** Click the "Löschen" (Delete) button on the right
- **Reorder tasks:** Drag the handle vertically or use the `↑` / `↓` fallback buttons
- **Create a subentry:** Drag a task clearly to the right onto another task or use the `→` button
- **Move a subentry back to top level:** Click the `←` button next to the subentry
- **Priority indicator:** The colored bar on the left shows task priority (green=low, orange=medium, red=high)
- **Due date:** Displayed below the task description (red if overdue)

### Drag Feedback
- **QUELLE** marks the task currently being dragged
- **ZIEL: EINFUEGEN** shows the current reorder target
- **ZIEL: UNTEREINTRAG** shows that the current drop target will receive the task as a subentry

### Configuration
Tasks are stored in:
```
~/.config/plasmarc
```

To manually export/import tasks, edit the `tasksJson` property in the Plasma configuration.

## Development

### Building from Source

1. **Dependencies:**
   ```bash
   sudo apt install qt6-base-dev qt6-declarative-dev qt6-declarative-dev-tools
   sudo apt install cmake extra-cmake-modules kf6-kconfig-dev
   ```

2. **Testing with plasmoidviewer:**
   ```bash
   plasmoidviewer -a com.meinprojekt.aufgaben -f horizontal -s 760x460
   ```

3. **QML Linting:**
   ```bash
   /usr/lib/qt6/bin/qmllint -I /usr/lib/x86_64-linux-gnu/qt6/qml -I .plasma-stubs contents/ui/main.qml
   ```

### Project Structure

```
kde-plasma-todo-applet/
├── contents/
│   ├── config/
│   │   └── main.xml           # Configuration schema
│   ├── logic/
│   │   └── AufgabenLogik.js   # Task logic & parsing
│   └── ui/
│       ├── main.qml           # Main widget layout
│       ├── AufgabenDelegate.qml   # Task row component
│       ├── AufgabenModell.qml     # Task data model
│       └── DatenSynchronisierer.qml  # Cloud sync (stub)
├── .plasma-stubs/             # QML tooling stubs
├── .vscode/                   # VS Code configuration
├── metadata.json              # Plasma applet metadata
└── README.md                  # This file
```

### Key Files

- **main.qml** – Root component, layout, and event handlers
- **AufgabenDelegate.qml** – Visual representation of each task row
- **AufgabenModell.qml** – ListModel with persistence logic
- **AufgabenLogik.js** – JSON serialization & data normalization

### Development Workflow

1. Edit QML files in `contents/ui/`
2. Update and reinstall: `kpackagetool6 -t Plasma/Applet -u .`
3. Restart plasmashell: `kquitapp6 plasmashell; plasmashell &`
4. Preview in widget UI

### QML Language Tooling

VS Code configuration is included (`.vscode/settings.json`). The project includes custom QML stubs in `.plasma-stubs/` for type resolution of Plasma-specific components.

## Contributing

Contributions are welcome! Please:

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/my-feature`)
3. Commit your changes (`git commit -m 'Add my feature'`)
4. Push to the branch (`git push origin feature/my-feature`)
5. Open a Pull Request

## License

This project is licensed under the **MIT License** – see [LICENSE](LICENSE) for details.

## Author

**Eduard Mayer**
- GitHub: [@EduardMayer-IT](https://github.com/EduardMayer-IT)

## Roadmap

- [ ] Edit existing tasks
- [ ] Recurring tasks / reminders
- [ ] Categories / tags
- [ ] Nextcloud sync (full implementation)
- [ ] Dark mode refinements
- [ ] Multi-language UI translations

## Support

For issues, feature requests, or questions, please open an [Issue](https://github.com/EduardMayer-IT/kde-plasma-todo-applet/issues) on GitHub.

---

<h1 id="deutsch">KDE Plasma 6 Aufgabenlisten-Applet</h1>

[English](#kde-plasma-6-to-do-list-applet) | **Deutsch**

Ein natives, schlankes Aufgabenlisten-Widget für KDE Plasma 6. Verwalte deine täglichen Aufgaben direkt vom Desktop aus mit einer sauberen, integrierten Benutzeroberfläche.

## Funktionen

-  **Aufgaben hinzufügen, bearbeiten und löschen** – Effiziente Aufgabenverwaltung
-  **Strukturierte Untereinträge** – Aufgaben können als sichtbare Untereinträge mit eigener Checkbox und Priorität geführt werden
-  **Drag-and-drop-Organisation** – Aufgaben vertikal sortieren oder nach rechts ziehen, um sie als Untereintrag abzulegen
-  **Live-Vorschau beim Ziehen** – Quelle und Ziel werden beim Draggen sichtbar markiert
-  **Prioritätsstufen** – Kennzeichne Aufgaben mit niedrig, mittel oder hoch (visuelle Indikatoren)
-  **Fälligkeitsdaten** – Setze und verfolge Aufgabenfristen
-  **Persistente Speicherung** – Aufgaben werden automatisch in der Plasma-Konfiguration gespeichert
-  **Plasma-integriert** – Respektiert dein System-Theme (hell/dunkel)
-  **Responsive Layouts** – Funktioniert auf Desktop-, horizontalen und vertikalen Panels
-  **Schnell und leicht** – Reines QML, keine externen Abhängigkeiten
-  **Nextcloud-Integration** – (Framework vorbereitet, optionale Konfiguration)

## Installation

### Aus dem Quellcode

1. **Repository klonen:**
   ```bash
   git clone https://github.com/EduardMayer-IT/kde-plasma-todo-applet.git
   cd kde-plasma-todo-applet
   ```

2. **Applet installieren:**
   ```bash
   kpackagetool6 -t Plasma/Applet -i .
   ```

3. **Plasma Shell neu starten:**
   ```bash
   kquitapp6 plasmashell
   plasmashell &
   ```

4. **Widget hinzufügen:**
   - Rechtsklick auf Desktop oder Panel
   - "Widgets hinzufügen" / "Add Widget" wählen
   - Nach "Aufgabenliste" suchen
   - "Add Widget" / "Hinzufügen" klicken

### Systemanforderungen

- **KDE Plasma 6** (getestet auf Plasma 6.0+)
- **Qt 6** (Qt 6.4 oder später)
- **Kirigami** (bereits in Plasma enthalten)

## Verwendung

### Aufgaben hinzufügen
1. Aufgabenbeschreibung im Eingabefeld unten eingeben
2. **Enter** drücken oder "Hinzufügen" klicken

### Aufgaben verwalten
- **Als erledigt markieren:** Checkbox klicken
- **Löschen:** "Löschen"-Button auf der rechten Seite klicken
- **Aufgaben verschieben:** Am Griff vertikal ziehen oder die Fallback-Buttons `↑` / `↓` verwenden
- **Untereintrag erzeugen:** Eine Aufgabe deutlich nach rechts auf eine andere ziehen oder den `→`-Button verwenden
- **Untereintrag zurückholen:** Beim Untereintrag auf `←` klicken, um ihn wieder auf Hauptebene zu holen
- **Prioritätsanzeige:** Der farbige Balken links zeigt die Priorität (grün=niedrig, orange=mittel, rot=hoch)
- **Fälligkeitsdatum:** Unter der Aufgabenbeschreibung angezeigt (rot wenn überfällig)

### Zieh-Vorschau
- **QUELLE** markiert den aktuell gezogenen Eintrag
- **ZIEL: EINFUEGEN** zeigt das aktuelle Sortierziel beim vertikalen Verschieben
- **ZIEL: UNTEREINTRAG** zeigt, dass der Eintrag beim Loslassen als Untereintrag abgelegt wird

### Konfiguration
Aufgaben werden gespeichert in:
```
~/.config/plasmarc
```

Zum manuellen Exportieren/Importieren der Aufgaben die `tasksJson`-Property in der Plasma-Konfiguration bearbeiten.

## Entwicklung

### Aus Quellcode kompilieren

1. **Abhängigkeiten:**
   ```bash
   sudo apt install qt6-base-dev qt6-declarative-dev qt6-declarative-dev-tools
   sudo apt install cmake extra-cmake-modules kf6-kconfig-dev
   ```

2. **Mit plasmoidviewer testen:**
   ```bash
   plasmoidviewer -a com.meinprojekt.aufgaben -f horizontal -s 760x460
   ```

3. **QML-Syntax prüfen:**
   ```bash
   /usr/lib/qt6/bin/qmllint -I /usr/lib/x86_64-linux-gnu/qt6/qml -I .plasma-stubs contents/ui/main.qml
   ```

### Projektstruktur

```
kde-plasma-todo-applet/
├── contents/
│   ├── config/
│   │   └── main.xml           # Konfigurationsschema
│   ├── logic/
│   │   └── AufgabenLogik.js   # Aufgaben-Logik & Parsing
│   └── ui/
│       ├── main.qml           # Haupt-Widget-Layout
│       ├── AufgabenDelegate.qml   # Aufgabenzeile
│       ├── AufgabenModell.qml     # Aufgaben-Datenmodell
│       └── DatenSynchronisierer.qml  # Cloud-Sync (Stub)
├── .plasma-stubs/             # QML Tooling Stubs
├── .vscode/                   # VS Code Konfiguration
├── metadata.json              # Plasma Applet Metadaten
└── README.md                  # Diese Datei
```

### Wichtige Dateien

- **main.qml** – Wurzel-Komponente, Layout und Event-Handler
- **AufgabenDelegate.qml** – Visuelle Darstellung jeder Aufgabenzeile
- **AufgabenModell.qml** – ListModel mit Persistierungs-Logik
- **AufgabenLogik.js** – JSON-Serialisierung & Datennormalisierung

### Entwicklungs-Workflow

1. QML-Dateien in `contents/ui/` bearbeiten
2. Aktualisieren und neu installieren: `kpackagetool6 -t Plasma/Applet -u .`
3. Plasmashell neu starten: `kquitapp6 plasmashell; plasmashell &`
4. In der Widget-UI testen

### QML Language Tooling

VS Code Konfiguration ist enthalten (`.vscode/settings.json`). Das Projekt enthält eigene QML Stubs in `.plasma-stubs/` für die Typauflösung von Plasma-spezifischen Komponenten.

## Mitarbeit

Beiträge sind willkommen! Bitte:

1. Forke das Repository
2. Erstelle einen Feature Branch (`git checkout -b feature/meine-funktion`)
3. Committe deine Änderungen (`git commit -m 'Meine Funktion hinzufügen'`)
4. Push zum Branch (`git push origin feature/meine-funktion`)
5. Öffne einen Pull Request

## Lizenz

Dieses Projekt steht unter der **MIT-Lizenz** – siehe [LICENSE](LICENSE) für Details.

## Autor

**Eduard Mayer**
- GitHub: [@EduardMayer-IT](https://github.com/EduardMayer-IT)

## Roadmap

- [ ] Existing tasks bearbeiten
- [ ] Wiederkehrende Aufgaben / Erinnerungen
- [ ] Kategorien / Tags
- [ ] Nextcloud Sync (vollständige Implementierung)
- [ ] Dark Mode Verbesserungen
- [ ] Mehrsprachige UI Übersetzungen

## Unterstützung

Bei Problemen, Feature Requests oder Fragen bitte ein [Issue](https://github.com/EduardMayer-IT/kde-plasma-todo-applet/issues) auf GitHub öffnen.
