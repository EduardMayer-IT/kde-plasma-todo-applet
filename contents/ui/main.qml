import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QtControls
import org.kde.plasma.plasmoid
import org.kde.kirigami as Kirigami

pragma ComponentBehavior: Bound

PlasmoidItem {
    id: root
    // qmllint disable unqualified
    readonly property string gespeicherteAufgaben: Plasmoid.configuration.tasksJson || "[]"
    readonly property string listenTitel: (Plasmoid.configuration.listTitle || "").trim() || i18n("Aufgabenliste")
    property int neueAufgabePrioritaet: 0
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

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Kirigami.Units.smallSpacing * 0.7
        spacing: Kirigami.Units.smallSpacing * 0.45

        Kirigami.Heading {
            level: 3
            text: root.listenTitel
            Layout.fillWidth: true
            wrapMode: Text.NoWrap
            elide: Text.ElideRight
            maximumLineCount: 1
            clip: true
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
                }
                
                QtControls.ScrollBar.vertical: QtControls.ScrollBar {}
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
                font.pixelSize: Kirigami.Units.gridUnit * 0.72
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
}
