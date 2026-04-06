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

    signal erledigtGewechselt(bool istErledigt)
    signal loeschenAngefragt()

    readonly property real zeilenHoehe: Kirigami.Units.gridUnit * 1.35
    readonly property real loeschenSpaltenBreite: Kirigami.Units.gridUnit * 4.8
    readonly property real checkboxSpaltenBreite: Kirigami.Units.gridUnit * 1.15
    readonly property real prioritaetsSpaltenBreite: Kirigami.Units.gridUnit * 0.33

    width: ListView.view ? ListView.view.width : implicitWidth
    padding: Kirigami.Units.smallSpacing * 0.22
    implicitHeight: Math.max(zeilenHoehe, contentItem.implicitHeight + (padding * 2))
    height: implicitHeight

    background: Rectangle {
        radius: 6
        color: aufgabenDelegate.erledigt
            ? Qt.rgba(0.2, 0.65, 0.3, 0.16)
            : (aufgabenDelegate.hovered ? Kirigami.Theme.hoverColor : Kirigami.Theme.backgroundColor)
        border.width: 1
        border.color: Qt.rgba(1, 1, 1, 0.12)
    }

    contentItem: RowLayout {
        spacing: Kirigami.Units.smallSpacing * 0.2
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
            Layout.preferredWidth: aufgabenDelegate.prioritaetsSpaltenBreite
            Layout.maximumWidth: aufgabenDelegate.prioritaetsSpaltenBreite
            Layout.alignment: Qt.AlignVCenter
            Layout.fillHeight: true
            radius: 3
            color: aufgabenDelegate.prioritaetFarbe(aufgabenDelegate.prioritaet)
        }

        ColumnLayout {
            id: textBlock
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            spacing: 0

            QtControls.Label {
                Layout.fillWidth: true
                text: aufgabenDelegate.beschreibung
                font.bold: true
                font.strikeout: aufgabenDelegate.erledigt
                elide: Text.ElideRight
                wrapMode: Text.NoWrap
                opacity: aufgabenDelegate.erledigt ? 0.65 : 1.0
                color: Kirigami.Theme.textColor
            }

            QtControls.Label {
                Layout.fillWidth: true
                visible: aufgabenDelegate.faelligkeit.length > 0
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
            font.pixelSize: Kirigami.Units.gridUnit * 1.0
            font.bold: true
            Layout.preferredHeight: Kirigami.Units.gridUnit * 1.15
            Layout.preferredWidth: Kirigami.Units.gridUnit * 1.15
            Layout.maximumWidth: Kirigami.Units.gridUnit * 1.15
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
