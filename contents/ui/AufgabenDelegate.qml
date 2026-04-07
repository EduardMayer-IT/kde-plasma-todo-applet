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
    property int letzterZielIndex: -1

    signal erledigtGewechselt(bool istErledigt)
    signal prioritaetGewechselt(int neuePrioritaet)
    signal beschreibungGewechselt(string neueBeschreibung)
    signal loeschenAngefragt()
    signal verschoben(int vonIndex, int nachIndex)
    signal verschiebenBeendet()

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

    opacity: dragMausflaeche.pressed ? 0.72 : 1.0

    background: Rectangle {
        radius: 4
        color: aufgabenDelegate.hovered
            ? Kirigami.Theme.hoverColor
            : Kirigami.Theme.backgroundColor
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

        Item {
            id: dragGriff
            Layout.preferredWidth: Kirigami.Units.gridUnit * 0.55
            Layout.maximumWidth: Kirigami.Units.gridUnit * 0.55
            Layout.fillHeight: true
            Layout.alignment: Qt.AlignVCenter
            opacity: dragMausflaeche.pressed ? 1.0 : (aufgabenDelegate.hovered ? 0.45 : 0.0)

            Text {
                anchors.centerIn: parent
                text: "⠿"
                color: Kirigami.Theme.textColor
                font.pixelSize: Kirigami.Units.gridUnit * 0.6
            }

            MouseArea {
                id: dragMausflaeche
                anchors.fill: parent
                preventStealing: true
                cursorShape: dragMausflaeche.pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor

                onPressed: {
                    aufgabenDelegate.letzterZielIndex = -1;
                }

                onReleased: {
                    aufgabenDelegate.letzterZielIndex = -1;
                    aufgabenDelegate.verschiebenBeendet();
                }

                onPositionChanged: function(mouse) {
                    if (!dragMausflaeche.pressed) return;
                    const listView = aufgabenDelegate.ListView.view;
                    if (!listView) return;
                    const posInList = dragMausflaeche.mapToItem(listView, mouse.x, mouse.y);
                    const yInContent = listView.contentY + posInList.y;
                    let targetIdx = listView.indexAt(listView.width * 0.5, yInContent);

                    if (targetIdx < 0) {
                        targetIdx = yInContent < 0 ? 0 : listView.count - 1;
                    }

                    targetIdx = Math.max(0, Math.min(listView.count - 1, targetIdx));

                    if (targetIdx === aufgabenDelegate.index || targetIdx === aufgabenDelegate.letzterZielIndex) {
                        return;
                    }

                    aufgabenDelegate.letzterZielIndex = targetIdx;
                    aufgabenDelegate.verschoben(aufgabenDelegate.index, targetIdx);
                }
            }
        }

        QtControls.CheckBox {
            id: erledigtCheck
            checked: aufgabenDelegate.erledigt
            hoverEnabled: true
            Layout.preferredWidth: aufgabenDelegate.checkboxSpaltenBreite
            Layout.maximumWidth: aufgabenDelegate.checkboxSpaltenBreite
            Layout.preferredHeight: aufgabenDelegate.zeilenHoehe - (aufgabenDelegate.padding * 2)
            Layout.alignment: Qt.AlignVCenter
            onToggled: aufgabenDelegate.erledigtGewechselt(checked)

            indicator: Rectangle {
                implicitWidth: Kirigami.Units.gridUnit * 0.58
                implicitHeight: Kirigami.Units.gridUnit * 0.58
                x: (erledigtCheck.width - width) / 2
                y: (erledigtCheck.height - height) / 2
                radius: 3
                color: Qt.rgba(1, 1, 1, erledigtCheck.hovered ? 0.08 : 0.04)
                border.width: 1
                border.color: Qt.rgba(1, 1, 1, erledigtCheck.hovered ? 0.18 : 0.1)

                Text {
                    anchors.centerIn: parent
                    text: "✓"
                    visible: erledigtCheck.checked
                    color: Kirigami.Theme.textColor
                    font.pixelSize: Kirigami.Units.gridUnit * 0.46
                    font.bold: true
                }
            }

            contentItem: Item {}
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
            font.bold: false
            Layout.preferredHeight: Kirigami.Units.gridUnit * 0.78
            Layout.preferredWidth: Kirigami.Units.gridUnit * 0.78
            Layout.maximumWidth: Kirigami.Units.gridUnit * 0.78
            Layout.alignment: Qt.AlignVCenter
            opacity: loeschenButton.hovered ? 1.0 : 0.72
            
            background: Rectangle {
                radius: 3
                color: loeschenButton.hovered
                    ? Qt.rgba(0.84, 0.2, 0.2, 0.28)
                    : Qt.rgba(1, 1, 1, 0.04)
                border.width: 1
                border.color: loeschenButton.hovered
                    ? Qt.rgba(0.92, 0.26, 0.26, 0.7)
                    : Qt.rgba(1, 1, 1, 0.1)
            }
            
            contentItem: Text {
                text: loeschenButton.text
                color: loeschenButton.hovered
                    ? Kirigami.Theme.negativeTextColor
                    : Kirigami.Theme.disabledTextColor
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
