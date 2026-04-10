import QtQuick
import QtCore
import QtQuick.Layouts
import QtQuick.Controls as QtControls
import QtQuick.Dialogs as QtDialogs
import org.kde.plasma.plasmoid
import org.kde.plasma.plasma5support as P5Support
import org.kde.kirigami as Kirigami
import org.kde.notification

pragma ComponentBehavior: Bound

PlasmoidItem {
    id: root
    // qmllint disable unqualified
    readonly property string gespeicherteAufgaben: Plasmoid.configuration.tasksJson || "[]"
    property int neueAufgabePrioritaet: 0
    property bool dragAktiv: false
    property int dragQuellIndex: -1
    property int dragZielIndex: -1
    property bool dragUnterModus: false
    property int filterModus: 0   // 0=alle, 1=offen, 2=erledigt
    property int sortierModus: 0  // 0=standard, 1=prioritaet, 2=datum
    property string letzterExportPfad: ""
    // qmllint enable unqualified

    implicitWidth: Kirigami.Units.gridUnit * 15.5
    implicitHeight: Kirigami.Units.gridUnit * 12.2

    function aufgabeAusEingabeHinzufuegen() {
        const text = neueAufgabeEingabe.text.trim();
        if (text.length === 0) return;
        aufgabenModell.aufgabeHinzufuegen(text, neueAufgabePrioritaet, "", "");
        neueAufgabeEingabe.text = "";
        neueAufgabePrioritaet = 0;
    }

    function prioritaetFarbe(prioritaet) {
        switch (prioritaet) {
        case 2:
            return "#d64545";
        case 1:
            return "#d9b000";
        default:
            return "#3da35a";
        }
    }

    function prioritaetText(prioritaet) {
        // qmllint disable unqualified
        switch (prioritaet) {
        case 2:
            return i18n("Hoch");
        case 1:
            return i18n("Mittel");
        default:
            return i18n("Niedrig");
        }
        // qmllint enable unqualified
    }

    function shellQuote(text) {
        return "'" + String(text).replace(/'/g, "'\"'\"'") + "'";
    }

    function urlZuDateipfad(fileUrl) {
        const raw = String(fileUrl || "");
        if (!raw) {
            return "";
        }

        if (raw.startsWith("file://")) {
            return decodeURIComponent(raw.replace("file://", ""));
        }
        return raw;
    }

    function exportiereAufgabenAlsDatei(fileUrl) {
        let zielPfad = urlZuDateipfad(fileUrl);
        if (!zielPfad) {
            return;
        }
        if (!zielPfad.endsWith(".txt")) {
            zielPfad += ".txt";
        }

        const text = aufgabenModell.exportAlsText();
        let marker = "__TODO_EXPORT_EOF__";
        while (text.indexOf(marker) !== -1) {
            marker += "_X";
        }

        const script = "cat <<'" + marker + "' > " + shellQuote(zielPfad) + "\n"
            + text
            + "\n" + marker;

        letzterExportPfad = zielPfad;
        exportEngine.connectSource("sh -c " + shellQuote(script));
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Kirigami.Units.smallSpacing * 0.7
        spacing: Kirigami.Units.smallSpacing * 0.45

        RowLayout {
            Layout.fillWidth: true
            spacing: Kirigami.Units.smallSpacing * 0.4

            QtControls.Button {
                id: filterButton
                Layout.fillWidth: true
                Layout.preferredHeight: Kirigami.Units.gridUnit * 0.9
                font.pixelSize: Kirigami.Units.gridUnit * 0.62
                // qmllint disable unqualified
                text: [i18n("Alle"), i18n("Offen"), i18n("Erledigt")][root.filterModus]
                // qmllint enable unqualified
                onClicked: filterMenu.popup(filterButton, 0, filterButton.height)

                QtControls.Menu {
                    id: filterMenu
                    // qmllint disable unqualified
                    QtControls.MenuItem {
                        text: i18n("Alle")
                        font.pixelSize: Kirigami.Units.gridUnit * 0.62
                        onTriggered: root.filterModus = 0
                    }
                    QtControls.MenuItem {
                        text: i18n("Offen")
                        font.pixelSize: Kirigami.Units.gridUnit * 0.62
                        onTriggered: root.filterModus = 1
                    }
                    QtControls.MenuItem {
                        text: i18n("Erledigt")
                        font.pixelSize: Kirigami.Units.gridUnit * 0.62
                        onTriggered: root.filterModus = 2
                    }
                    // qmllint enable unqualified
                }
            }

            QtControls.Button {
                id: sortierButton
                Layout.fillWidth: true
                Layout.preferredHeight: Kirigami.Units.gridUnit * 0.9
                font.pixelSize: Kirigami.Units.gridUnit * 0.62
                // qmllint disable unqualified
                text: [i18n("Sort: Std"), i18n("Sort: Prio"), i18n("Sort: Datum")][root.sortierModus]
                // qmllint enable unqualified
                onClicked: sortierMenu.popup(sortierButton, 0, sortierButton.height)

                QtControls.Menu {
                    id: sortierMenu
                    // qmllint disable unqualified
                    QtControls.MenuItem {
                        text: i18n("Sortierung: Standard")
                        font.pixelSize: Kirigami.Units.gridUnit * 0.62
                        onTriggered: root.sortierModus = 0
                    }
                    QtControls.MenuItem {
                        text: i18n("Sortierung: Priorität")
                        font.pixelSize: Kirigami.Units.gridUnit * 0.62
                        onTriggered: {
                            root.sortierModus = 1;
                            aufgabenModell.sortierenNachPrioritaet();
                        }
                    }
                    QtControls.MenuItem {
                        text: i18n("Sortierung: Datum")
                        font.pixelSize: Kirigami.Units.gridUnit * 0.62
                        onTriggered: {
                            root.sortierModus = 2;
                            aufgabenModell.sortierenNachDatum();
                        }
                    }
                    // qmllint enable unqualified
                }
            }

            QtControls.Button {
                id: exportButton
                Layout.fillWidth: true
                Layout.preferredHeight: Kirigami.Units.gridUnit * 0.9
                font.pixelSize: Kirigami.Units.gridUnit * 0.6
                // qmllint disable unqualified
                text: i18n("Export")
                // qmllint enable unqualified
                onClicked: exportDialog.open()
            }
        }

        Rectangle {
            color: Kirigami.Theme.backgroundColor
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.minimumHeight: Kirigami.Units.gridUnit * 6.2
            radius: Kirigami.Units.smallSpacing
            border.width: 1
            border.color: Qt.rgba(1, 1, 1, 0.12)
            
            ListView {
                id: aufgabenListe
                anchors.fill: parent
                anchors.margins: Kirigami.Units.smallSpacing * 0.14
                clip: true
                spacing: Kirigami.Units.smallSpacing * 0.05
                model: aufgabenModell

                displaced: Transition {
                    NumberAnimation {
                        properties: "x,y"
                        duration: 95
                        easing.type: Easing.OutCubic
                    }
                }

                delegate: AufgabenDelegate {
                    width: aufgabenListe.width
                    dragController: root
                    filterModus: root.filterModus

                    onErledigtGewechselt: function(istErledigt) {
                        aufgabenModell.erledigtSetzen(index, istErledigt);
                    }

                    onPrioritaetGewechselt: function(neuePrioritaet) {
                        aufgabenModell.prioritaetSetzen(index, neuePrioritaet);
                    }

                    onBeschreibungGewechselt: function(neueBeschreibung) {
                        aufgabenModell.beschreibungSetzen(index, neueBeschreibung);
                    }

                    onUntertextGedroppt: function(untertext) {
                        aufgabenModell.untereintragHinzufuegen(index, untertext, 0, false);
                    }

                    onUnterBeschreibungGewechselt: function(unterIndex, neuerText) {
                        aufgabenModell.untereintragBeschreibungSetzen(index, unterIndex, neuerText);
                    }

                    onUnterPrioritaetGewechselt: function(unterIndex, neuePrioritaet) {
                        aufgabenModell.untereintragPrioritaetSetzen(index, unterIndex, neuePrioritaet);
                    }

                    onUnterErledigtGewechselt: function(unterIndex, istErledigt) {
                        aufgabenModell.untereintragErledigtSetzen(index, unterIndex, istErledigt);
                    }

                    onAlsUnterzeileVerschiebenAngefragt: function(quellIndex, zielIndex) {
                        aufgabenModell.eintragAlsUnterzeileVerschieben(quellIndex, zielIndex);
                    }

                    onVerschoben: function(vonIndex, nachIndex) {
                        aufgabenModell.verschieben(vonIndex, nachIndex, false);
                    }

                    onVerschiebenBeendet: {
                        aufgabenModell.persistiere();
                    }

                    onLoeschenAngefragt: {
                        aufgabenModell.aufgabeLoeschen(index);
                    }

                    onFaelligkeitGewechselt: function(neueFaelligkeit) {
                        aufgabenModell.aktualisiereFaelligkeit(index, neueFaelligkeit);
                    }
                }
                
                QtControls.ScrollBar.vertical: QtControls.ScrollBar {
                    policy: QtControls.ScrollBar.AsNeeded
                    width: Kirigami.Units.gridUnit * 0.28
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: Math.max(
                Kirigami.Units.gridUnit * 1.46,
                neueAufgabeEingabe.contentHeight + (neueAufgabeEingabe.padding * 2) + (Kirigami.Units.smallSpacing * 0.2)
            )
            spacing: Kirigami.Units.smallSpacing * 0.45

            Rectangle {
                id: prioritaetFeld
                Layout.preferredHeight: Kirigami.Units.gridUnit * 1.18
                Layout.preferredWidth: Kirigami.Units.gridUnit * 1.18
                Layout.alignment: Qt.AlignTop
                radius: 3
                color: root.prioritaetFarbe(root.neueAufgabePrioritaet)
                border.width: 1
                border.color: Qt.rgba(1, 1, 1, 0.2)

                MouseArea {
                    id: prioritaetKlickflaeche
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        root.neueAufgabePrioritaet = (root.neueAufgabePrioritaet + 1) % 3;
                    }
                }

                QtControls.ToolTip {
                    // qmllint disable unqualified
                    text: i18n("Prioritaet: %1", root.prioritaetText(root.neueAufgabePrioritaet))
                    // qmllint enable unqualified
                    delay: 300
                    visible: prioritaetKlickflaeche.containsMouse
                }
            }

            QtControls.TextArea {
                id: neueAufgabeEingabe
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignTop
                Layout.preferredHeight: Math.min(
                    Kirigami.Units.gridUnit * 3.1,
                    Math.max(Kirigami.Units.gridUnit * 1.18, contentHeight + (padding * 2))
                )
                font.pixelSize: Kirigami.Units.gridUnit * 0.70
                padding: Kirigami.Units.smallSpacing * 0.45
                wrapMode: Text.Wrap
                // qmllint disable unqualified
                placeholderText: i18n("Neue Aufgabe eingeben...")
                // qmllint enable unqualified
                focus: true

                Keys.onPressed: function(event) {
                    if ((event.key === Qt.Key_Return || event.key === Qt.Key_Enter)
                            && (event.modifiers & Qt.ControlModifier)) {
                        event.accepted = true;
                        root.aufgabeAusEingabeHinzufuegen();
                    }
                }
            }

            QtControls.Button {
                id: hinzufuegenButton
                // qmllint disable unqualified
                text: i18n("+")
                // qmllint enable unqualified
                Layout.preferredHeight: Kirigami.Units.gridUnit * 1.18
                Layout.preferredWidth: Kirigami.Units.gridUnit * 1.18
                Layout.alignment: Qt.AlignTop
                font.bold: true
                onClicked: root.aufgabeAusEingabeHinzufuegen()
                QtControls.ToolTip {
                    // qmllint disable unqualified
                    text: i18n("Aufgabe hinzufuegen (Ctrl+Enter)")
                    // qmllint enable unqualified
                    delay: 300
                    visible: hinzufuegenButton.hovered
                }
            }
        }

    }

    AufgabenModell {
        id: aufgabenModell
        tasksJson: root.gespeicherteAufgaben

        onPersistRequested: function(json) {
            // qmllint disable unqualified
            Plasmoid.configuration.tasksJson = json;
            // qmllint enable unqualified
        }
    }

    DatenSynchronisierer {
        id: datenSync
        // qmllint disable unqualified
        nextcloudUrl: Plasmoid.configuration.nextcloudUrl || ""
        benutzername: Plasmoid.configuration.nextcloudUsername || ""
        // qmllint enable unqualified
    }

    Notification {
        id: faelligkeitsHinweis
        componentName: "plasma_applet_com.meinprojekt.aufgaben"
        eventId: "faelligkeit"
        iconName: "view-task"
        flags: Notification.Persistent
    }

    Notification {
        id: exportHinweis
        componentName: "plasma_applet_com.meinprojekt.aufgaben"
        eventId: "faelligkeit"
        iconName: "document-save"
    }

    QtDialogs.FileDialog {
        id: exportDialog
        // qmllint disable unqualified
        title: i18n("Aufgaben als TXT exportieren")
        fileMode: QtDialogs.FileDialog.SaveFile
        nameFilters: [i18n("Textdateien (*.txt)"), i18n("Alle Dateien (*)")]
        // qmllint enable unqualified
        currentFolder: StandardPaths.standardLocations(StandardPaths.DocumentsLocation)[0]
        currentFile: "aufgaben-export.txt"
        onAccepted: root.exportiereAufgabenAlsDatei(selectedFile)
    }

    P5Support.DataSource {
        id: exportEngine
        engine: "executable"

        onNewData: function(sourceName, data) {
            const code = data["exit code"] !== undefined
                ? data["exit code"]
                : (data.exitCode !== undefined ? data.exitCode : 0);

            if (code === 0) {
                // qmllint disable unqualified
                exportHinweis.title = i18n("Export erfolgreich")
                exportHinweis.text = i18n("Datei gespeichert: %1", root.letzterExportPfad)
                // qmllint enable unqualified
            } else {
                // qmllint disable unqualified
                exportHinweis.title = i18n("Export fehlgeschlagen")
                exportHinweis.text = i18n("Datei konnte nicht geschrieben werden")
                // qmllint enable unqualified
            }
            exportHinweis.sendEvent();

            disconnectSource(sourceName);
            removeSource(sourceName);
        }
    }

    Timer {
        interval: 60000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            const heute = new Date();
            heute.setHours(0, 0, 0, 0);
            const aufgaben = aufgabenModell.alsArray();
            const faellige = aufgaben.filter(function(a) {
                if (a.erledigt || !a.faelligkeit) return false;
                const d = new Date(a.faelligkeit);
                return !isNaN(d.getTime()) && d <= heute;
            });
            if (faellige.length > 0) {
                // qmllint disable unqualified
                faelligkeitsHinweis.title = i18n("Fällige Aufgaben");
                faelligkeitsHinweis.text = faellige.map(function(a) { return "• " + a.beschreibung; }).join("\n");
                // qmllint enable unqualified
                faelligkeitsHinweis.sendEvent();
            }
        }
    }
}
