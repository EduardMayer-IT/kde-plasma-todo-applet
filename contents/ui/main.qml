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
    // qmllint enable unqualified

    implicitWidth: Kirigami.Units.gridUnit * 22
    implicitHeight: Kirigami.Units.gridUnit * 18

    function aufgabeAusEingabeHinzufuegen() {
        const text = neueAufgabeEingabe.text.trim();
        if (text.length === 0) return;
        aufgabenModell.aufgabeHinzufuegen(text, 0, "");
        neueAufgabeEingabe.text = "";
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Kirigami.Units.largeSpacing
        spacing: Kirigami.Units.largeSpacing

        Kirigami.Heading {
            level: 2
            // qmllint disable unqualified
            text: i18n("Aufgabenliste")
            // qmllint enable unqualified
            Layout.fillWidth: true
        }

        Rectangle {
            color: Kirigami.Theme.backgroundColor
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.minimumHeight: Kirigami.Units.gridUnit * 10
            radius: Kirigami.Units.smallSpacing
            border.width: 1
            border.color: Qt.rgba(1, 1, 1, 0.12)
            
            ListView {
                id: aufgabenListe
                anchors.fill: parent
                anchors.margins: Kirigami.Units.smallSpacing
                clip: true
                spacing: Kirigami.Units.smallSpacing
                model: aufgabenModell

                delegate: AufgabenDelegate {
                    width: aufgabenListe.width

                    onErledigtGewechselt: function(istErledigt) {
                        aufgabenModell.erledigtSetzen(index, istErledigt);
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
            Layout.preferredHeight: Kirigami.Units.gridUnit * 2.6
            spacing: Kirigami.Units.smallSpacing

            QtControls.TextField {
                id: neueAufgabeEingabe
                Layout.fillWidth: true
                Layout.preferredHeight: Kirigami.Units.gridUnit * 2.1
                // qmllint disable unqualified
                placeholderText: i18n("Neue Aufgabe eingeben...")
                // qmllint enable unqualified
                focus: true
                
                onAccepted: root.aufgabeAusEingabeHinzufuegen()
            }

            QtControls.Button {
                // qmllint disable unqualified
                text: i18n("Hinzufuegen")
                // qmllint enable unqualified
                Layout.preferredHeight: Kirigami.Units.gridUnit * 2.1
                Layout.preferredWidth: Kirigami.Units.gridUnit * 6.3
                onClicked: root.aufgabeAusEingabeHinzufuegen()
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
