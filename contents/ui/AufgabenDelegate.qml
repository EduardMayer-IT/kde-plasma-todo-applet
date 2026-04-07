import QtQuick
import QtQuick.Controls as QtControls
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

/*
 * Dieses Projekt steht unter der MIT-Lizenz.
 * Copyright (c) [Jahr] [Dein Name]
 */

QtControls.ItemDelegate {
    id: aufgabenDelegate

    required property int index
    required property string beschreibung
    required property int prioritaet
    required property string faelligkeit
    required property bool erledigt
    property bool bearbeitungsModus: false
    property string bearbeitungsText: ""

    signal erledigtGewechselt(bool istErledigt)
    signal prioritaetGewechselt(int neuePrioritaet)
    signal beschreibungGewechselt(string neueBeschreibung)
    signal loeschenAngefragt()

    readonly property real zeilenHoehe: Kirigami.Units.gridUnit * 0.9
    readonly property real loeschenSpaltenBreite: Kirigami.Units.gridUnit * 4.8
    readonly property real checkboxSpaltenBreite: Kirigami.Units.gridUnit * 0.82
    readonly property real prioritaetsSpaltenBreite: Kirigami.Units.gridUnit * 0.33

    width: ListView.view ? ListView.view.width : implicitWidth
    padding: Kirigami.Units.smallSpacing * 0.04
    implicitHeight: Math.max(zeilenHoehe, contentItem.implicitHeight + (padding * 2))
    height: implicitHeight

    function bearbeitungStarten() {
        bearbeitungsText = beschreibung;
        bearbeitungsModus = true;
    }

    function bearbeitungSpeichern() {
        const bereinigt = bearbeitungsText.trim();
        if (bereinigt.length > 0 && bereinigt !== beschreibung) {
            beschreibungGewechselt(bereinigt);
        }
        bearbeitungsModus = false;
    }

    function bearbeitungAbbrechen() {
        bearbeitungsText = beschreibung;
        bearbeitungsModus = false;
    }

    background: Rectangle {
        radius: 4
        color: aufgabenDelegate.erledigt
            ? Qt.rgba(0.2, 0.65, 0.3, 0.16)
            : (aufgabenDelegate.hovered ? Kirigami.Theme.hoverColor : Kirigami.Theme.backgroundColor)
        border.width: 1
        border.color: Qt.rgba(1, 1, 1, 0.12)
    }

    contentItem: RowLayout {
        spacing: Kirigami.Units.smallSpacing * 0.03
        width: aufgabenDelegate.availableWidth
        height: implicitHeight

        implicitHeight: Math.max(
            erledigtCheck.implicitHeight,
            loeschenButton.implicitHeight,
            textBlock.implicitHeight,
            aufgabenDelegate.zeilenHoehe - (aufgabenDelegate.padding * 2)
        )

        QtControls.CheckBox {
            id: erledigtCheck
            checked: aufgabenDelegate.erledigt
            Layout.preferredWidth: aufgabenDelegate.checkboxSpaltenBreite
            Layout.maximumWidth: aufgabenDelegate.checkboxSpaltenBreite
            Layout.preferredHeight: aufgabenDelegate.zeilenHoehe - (aufgabenDelegate.padding * 2)
            Layout.alignment: Qt.AlignVCenter
            onToggled: aufgabenDelegate.erledigtGewechselt(checked)
        }

        Rectangle {
            id: prioritaetsBalken
            Layout.preferredWidth: aufgabenDelegate.prioritaetsSpaltenBreite
            Layout.maximumWidth: aufgabenDelegate.prioritaetsSpaltenBreite
            Layout.alignment: Qt.AlignVCenter
            Layout.fillHeight: true
            radius: 3
            color: aufgabenDelegate.prioritaetFarbe(aufgabenDelegate.prioritaet)

            MouseArea {
                id: prioritaetKlickflaeche
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    const naechstePrioritaet = (aufgabenDelegate.prioritaet + 1) % 3;
                    aufgabenDelegate.prioritaetGewechselt(naechstePrioritaet);
                }
            }

            QtControls.ToolTip {
                // qmllint disable unqualified
                text: i18n("Klicken zum Wechseln der Prioritaet")
                // qmllint enable unqualified
                delay: 500
                visible: prioritaetKlickflaeche.containsMouse
            }
        }

        ColumnLayout {
            id: textBlock
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            spacing: 0

            QtControls.Label {
                id: beschreibungsLabel
                Layout.fillWidth: true
                visible: !aufgabenDelegate.bearbeitungsModus
                text: aufgabenDelegate.beschreibung
                font.pixelSize: Kirigami.Units.gridUnit * 0.66
                font.bold: true
                font.strikeout: aufgabenDelegate.erledigt
                elide: Text.ElideRight
                wrapMode: Text.NoWrap
                opacity: aufgabenDelegate.erledigt ? 0.65 : 1.0
                color: Kirigami.Theme.textColor

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.IBeamCursor
                    onClicked: {
                        aufgabenDelegate.bearbeitungStarten();
                        bearbeitungsEingabe.forceActiveFocus();
                        bearbeitungsEingabe.selectAll();
                    }
                }
            }

            QtControls.TextField {
                id: bearbeitungsEingabe
                Layout.fillWidth: true
                visible: aufgabenDelegate.bearbeitungsModus
                text: aufgabenDelegate.bearbeitungsText
                font.pixelSize: Kirigami.Units.gridUnit * 0.66
                selectByMouse: true
                onTextChanged: aufgabenDelegate.bearbeitungsText = text
                onAccepted: aufgabenDelegate.bearbeitungSpeichern()
                onActiveFocusChanged: {
                    if (!activeFocus && aufgabenDelegate.bearbeitungsModus) {
                        aufgabenDelegate.bearbeitungSpeichern();
                    }
                }

                Keys.onEscapePressed: function(event) {
                    event.accepted = true;
                    aufgabenDelegate.bearbeitungAbbrechen();
                }
            }

            QtControls.Label {
                Layout.fillWidth: true
                visible: aufgabenDelegate.faelligkeit.length > 0
                font.pixelSize: Kirigami.Units.gridUnit * 0.56
                // qmllint disable unqualified
                text: i18n("Faellig: %1", aufgabenDelegate.faelligkeit)
                // qmllint enable unqualified
                elide: Text.ElideRight
                color: aufgabenDelegate.istUeberfaellig(aufgabenDelegate.faelligkeit) ? Kirigami.Theme.negativeTextColor : Kirigami.Theme.disabledTextColor
            }
        }

        QtControls.Button {
            id: loeschenButton
            text: "✕"
            font.pixelSize: Kirigami.Units.gridUnit * 0.7
            font.bold: true
            Layout.preferredHeight: Kirigami.Units.gridUnit * 0.78
            Layout.preferredWidth: Kirigami.Units.gridUnit * 0.78
            Layout.maximumWidth: Kirigami.Units.gridUnit * 0.78
            Layout.alignment: Qt.AlignVCenter
            
            background: Rectangle {
                radius: 3
                color: loeschenButton.hovered ? "#ff5555" : "#cc3333"
                border.width: 0
            }
            
            contentItem: Text {
                text: loeschenButton.text
                color: "white"
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                font: loeschenButton.font
            }
            
            onClicked: aufgabenDelegate.loeschenAngefragt()
            
            QtControls.ToolTip {
                // qmllint disable unqualified
                text: i18n("Aufgabe löschen")
                // qmllint enable unqualified
                delay: 500
                visible: loeschenButton.hovered
            }
        }
    }

    function prioritaetFarbe(prioritaet) {
        switch (prioritaet) {
        case 2:
            return "#d64545";
        case 1:
            return "#d98a00";
        default:
            return "#3da35a";
        }
    }

    function istUeberfaellig(faelligkeit) {
        if (!faelligkeit) {
            return false;
        }

        const datum = new Date(faelligkeit);
        return !isNaN(datum.getTime()) && datum < new Date();
    }
}
