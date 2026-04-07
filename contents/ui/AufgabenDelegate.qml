import QtQuick
import QtQuick.Controls as QtControls
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

pragma ComponentBehavior: Bound

/*
 * Dieses Projekt steht unter der MIT-Lizenz.
 * Copyright (c) [Jahr] [Dein Name]
 */

QtControls.ItemDelegate {
    id: aufgabenDelegate

    required property int index
    required property string beschreibung
    required property var untereintraege
    required property int prioritaet
    required property string faelligkeit
    required property bool erledigt
    property bool bearbeitungsModus: false
    property string bearbeitungsText: ""
    property int bearbeiteterUntereintragIndex: -1
    property string bearbeiteterUntereintragText: ""
    property int letzterZielIndex: -1
    property bool dropAktiv: false
    property bool unterzeilenModusAktiv: false
    property real dragStartScreenX: 0
    property int dragStartIndex: -1
    property int unterzeilenZielIndex: -1

    signal erledigtGewechselt(bool istErledigt)
    signal prioritaetGewechselt(int neuePrioritaet)
    signal beschreibungGewechselt(string neueBeschreibung)
    signal untertextGedroppt(string untertext)
    signal unterBeschreibungGewechselt(int unterIndex, string neuerText)
    signal unterPrioritaetGewechselt(int unterIndex, int neuePrioritaet)
    signal unterErledigtGewechselt(int unterIndex, bool istErledigt)
    signal alsUnterzeileVerschiebenAngefragt(int quellIndex, int zielIndex)
    signal loeschenAngefragt()
    signal verschoben(int vonIndex, int nachIndex)
    signal verschiebenBeendet()

    readonly property real zeilenHoehe: Kirigami.Units.gridUnit * 0.9
    readonly property real loeschenSpaltenBreite: Kirigami.Units.gridUnit * 4.8
    readonly property real checkboxSpaltenBreite: Kirigami.Units.gridUnit * 0.82
    readonly property real prioritaetsSpaltenBreite: Kirigami.Units.gridUnit * 0.33
    readonly property real unterzeilenHorizontalSchwelle: 25

    width: ListView.view ? ListView.view.width : implicitWidth
    padding: Kirigami.Units.smallSpacing * 0.04
    implicitHeight: Math.max(zeilenHoehe, contentItem.implicitHeight + (padding * 2))
    height: implicitHeight

    function bearbeitungStarten() {
        bearbeitungsText = beschreibung;
        bearbeitungsModus = true;
        bearbeiteterUntereintragIndex = -1;
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

    function untereintragBearbeitungStarten(unterIndex, text) {
        bearbeiteterUntereintragIndex = unterIndex;
        bearbeiteterUntereintragText = text;
    }

    function untereintragBearbeitungSpeichern() {
        if (bearbeiteterUntereintragIndex < 0) {
            return;
        }

        const bereinigt = bearbeiteterUntereintragText.trim();
        if (bereinigt.length > 0) {
            unterBeschreibungGewechselt(bearbeiteterUntereintragIndex, bereinigt);
        }

        bearbeiteterUntereintragIndex = -1;
        bearbeiteterUntereintragText = "";
    }

    function untereintragBearbeitungAbbrechen() {
        bearbeiteterUntereintragIndex = -1;
        bearbeiteterUntereintragText = "";
    }

    function textAusDrop(drop) {
        let text = "";

        if (drop && drop.text !== undefined && drop.text !== null) {
            text = String(drop.text);
        }

        if ((!text || text.trim().length === 0) && drop && typeof drop.getDataAsString === "function") {
            const mimeTypen = [
                "text/plain",
                "text/plain;charset=utf-8",
                "STRING",
                "TEXT",
                "text/uri-list"
            ];

            for (let i = 0; i < mimeTypen.length; ++i) {
                const daten = drop.getDataAsString(mimeTypen[i]);
                if (daten && daten.trim().length > 0) {
                    text = daten;
                    break;
                }
            }
        }

        return (text || "").trim();
    }

    opacity: dragMausflaeche.pressed ? 0.72 : 1.0

    background: Rectangle {
        radius: 4
        color: aufgabenDelegate.unterzeilenModusAktiv
            ? Qt.rgba(1, 1, 1, 0.08)
            : (aufgabenDelegate.hovered
            ? Kirigami.Theme.hoverColor
            : Kirigami.Theme.backgroundColor)
        border.width: aufgabenDelegate.unterzeilenModusAktiv ? 2 : 1
        border.color: aufgabenDelegate.unterzeilenModusAktiv
            ? Kirigami.Theme.highlightColor
            : (aufgabenDelegate.dropAktiv
            ? Kirigami.Theme.highlightColor
            : Qt.rgba(1, 1, 1, 0.12))

        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            visible: aufgabenDelegate.dropAktiv
            color: Qt.rgba(
                Kirigami.Theme.highlightColor.r,
                Kirigami.Theme.highlightColor.g,
                Kirigami.Theme.highlightColor.b,
                0.16
            )
            border.width: 1
            border.color: Qt.rgba(
                Kirigami.Theme.highlightColor.r,
                Kirigami.Theme.highlightColor.g,
                Kirigami.Theme.highlightColor.b,
                0.45
            )
        }

        Rectangle {
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: Kirigami.Units.smallSpacing * 0.45
            visible: aufgabenDelegate.unterzeilenModusAktiv
            radius: 3
            color: Kirigami.Theme.highlightColor
            border.width: 1
            border.color: Qt.rgba(0, 0, 0, 0.22)
            width: modusText.implicitWidth + Kirigami.Units.smallSpacing * 1.2
            height: modusText.implicitHeight + Kirigami.Units.smallSpacing * 0.8

            Text {
                id: modusText
                anchors.centerIn: parent
                text: "UNTERZEILE"
                color: Kirigami.Theme.highlightedTextColor
                font.pixelSize: Kirigami.Units.gridUnit * 0.42
                font.bold: true
            }
        }

        DropArea {
            id: dropZone
            anchors.fill: parent

            onEntered: {
                aufgabenDelegate.dropAktiv = true;
            }

            onExited: {
                aufgabenDelegate.dropAktiv = false;
            }

            onDropped: function(drop) {
                const text = aufgabenDelegate.textAusDrop(drop);
                aufgabenDelegate.dropAktiv = false;
                if (!text) return;
                aufgabenDelegate.untertextGedroppt(text);
                drop.acceptProposedAction();
            }
        }
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
                cursorShape: dragMausflaeche.pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor

                onPressed: {
                    aufgabenDelegate.letzterZielIndex = -1;
                    const globalPos = dragMausflaeche.mapToGlobal(mouseX, mouseY);
                    aufgabenDelegate.dragStartScreenX = globalPos.x;
                    aufgabenDelegate.dragStartIndex = aufgabenDelegate.index;
                    aufgabenDelegate.unterzeilenModusAktiv = false;
                    aufgabenDelegate.unterzeilenZielIndex = -1;
                }

                onReleased: {
                    console.log("Drag ENDED - subenty mode: " + aufgabenDelegate.unterzeilenModusAktiv + ", target index: " + aufgabenDelegate.unterzeilenZielIndex);
                    if (aufgabenDelegate.unterzeilenModusAktiv && aufgabenDelegate.unterzeilenZielIndex >= 0
                            && aufgabenDelegate.unterzeilenZielIndex !== aufgabenDelegate.dragStartIndex) {
                        console.log("Converting entry " + aufgabenDelegate.dragStartIndex + " to subentry under " + aufgabenDelegate.unterzeilenZielIndex);
                        aufgabenDelegate.alsUnterzeileVerschiebenAngefragt(
                            aufgabenDelegate.dragStartIndex,
                            aufgabenDelegate.unterzeilenZielIndex
                        );
                    }
                    aufgabenDelegate.letzterZielIndex = -1;
                    aufgabenDelegate.dragStartIndex = -1;
                    aufgabenDelegate.unterzeilenModusAktiv = false;
                    aufgabenDelegate.unterzeilenZielIndex = -1;
                    aufgabenDelegate.verschiebenBeendet();
                }

                onPositionChanged: function(mouse) {
                    // CRITICAL: Only the delegate that was originally pressed handles movement
                    if (aufgabenDelegate.dragStartIndex !== aufgabenDelegate.index) {
                        return;
                    }
                    if (!dragMausflaeche.pressed) return;
                    const listView = aufgabenDelegate.ListView.view;
                    if (!listView) return;

                    // Horizontal delta via global coords (no coordinate-system drift)
                    const currentScreenX = dragMausflaeche.mapToGlobal(mouse.x, mouse.y).x;
                    const horizontalerVersatz = currentScreenX - aufgabenDelegate.dragStartScreenX;

                    // Sticky subentry mode: once triggered, stays ON until release
                    if (horizontalerVersatz > aufgabenDelegate.unterzeilenHorizontalSchwelle) {
                        aufgabenDelegate.unterzeilenModusAktiv = true;
                    }

                    // Resolve target from global cursor position into the ListView content item
                    const currentScreenY = dragMausflaeche.mapToGlobal(mouse.x, mouse.y).y;
                    const posInContent = listView.contentItem.mapFromGlobal(currentScreenX, currentScreenY);
                    let targetIdx = listView.indexAt(listView.width * 0.5, posInContent.y);
                    if (targetIdx < 0) {
                        targetIdx = posInContent.y < 0 ? 0 : (listView.count - 1);
                    }
                    targetIdx = Math.max(0, Math.min(listView.count - 1, targetIdx));

                    // Always keep target index current (needed for correct release handling)
                    aufgabenDelegate.unterzeilenZielIndex = targetIdx;

                    // In subentry mode: only track target, never reorder
                    if (aufgabenDelegate.unterzeilenModusAktiv) {
                        return;
                    }

                    // Pre-subentry guard: any rightward movement blocks reorder
                    // (prevents item jumping before 25px which would corrupt index)
                    if (horizontalerVersatz > 3) {
                        return;
                    }

                    // Normal vertical reorder
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
            spacing: Kirigami.Units.smallSpacing * 0.08

            QtControls.Label {
                id: beschreibungsLabel
                Layout.fillWidth: true
                visible: !aufgabenDelegate.bearbeitungsModus
                text: aufgabenDelegate.beschreibung
                font.pixelSize: Kirigami.Units.gridUnit * 0.66
                font.bold: true
                font.strikeout: aufgabenDelegate.erledigt
                wrapMode: Text.Wrap
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

            QtControls.TextArea {
                id: bearbeitungsEingabe
                Layout.fillWidth: true
                visible: aufgabenDelegate.bearbeitungsModus
                text: aufgabenDelegate.bearbeitungsText
                font.pixelSize: Kirigami.Units.gridUnit * 0.66
                selectByMouse: true
                wrapMode: Text.Wrap
                padding: Kirigami.Units.smallSpacing * 0.35
                Layout.preferredHeight: Math.min(
                    Kirigami.Units.gridUnit * 3.0,
                    Math.max(Kirigami.Units.gridUnit * 1.2, contentHeight + (padding * 2))
                )
                onTextChanged: aufgabenDelegate.bearbeitungsText = text
                onActiveFocusChanged: {
                    if (!activeFocus && aufgabenDelegate.bearbeitungsModus) {
                        aufgabenDelegate.bearbeitungSpeichern();
                    }
                }

                Keys.onPressed: function(event) {
                    if ((event.key === Qt.Key_Return || event.key === Qt.Key_Enter)
                            && (event.modifiers & Qt.ControlModifier)) {
                        event.accepted = true;
                        aufgabenDelegate.bearbeitungSpeichern();
                    }
                }

                Keys.onEscapePressed: function(event) {
                    event.accepted = true;
                    aufgabenDelegate.bearbeitungAbbrechen();
                }
            }

            Item {
                Layout.fillWidth: true
                visible: !aufgabenDelegate.bearbeitungsModus
                         && Array.isArray(aufgabenDelegate.untereintraege)
                         && aufgabenDelegate.untereintraege.length > 0
                implicitHeight: untereintraegeSpalte.implicitHeight

                ColumnLayout {
                    id: untereintraegeSpalte
                    anchors.left: parent.left
                    anchors.right: parent.right
                    spacing: Kirigami.Units.smallSpacing * 0.34

                    Repeater {
                        model: aufgabenDelegate.untereintraege

                        delegate: RowLayout {
                            id: untereintragZeile
                            required property int index
                            required property var modelData

                            readonly property string unterText: (modelData && modelData.beschreibung) ? modelData.beschreibung : ""
                            readonly property int unterPrioritaet: (modelData && modelData.prioritaet !== undefined) ? modelData.prioritaet : 0
                            readonly property bool unterErledigt: !!(modelData && modelData.erledigt)

                            Layout.fillWidth: true
                            spacing: Kirigami.Units.smallSpacing * 0.55
                            Layout.leftMargin: Kirigami.Units.smallSpacing * 1.45

                            Rectangle {
                                width: 3
                                Layout.fillHeight: true
                                radius: 1
                                color: Qt.rgba(1, 1, 1, 0.34)
                            }

                            QtControls.CheckBox {
                                checked: parent.unterErledigt
                                hoverEnabled: true
                                Layout.alignment: Qt.AlignTop
                                onToggled: aufgabenDelegate.unterErledigtGewechselt(untereintragZeile.index, checked)
                            }

                            Rectangle {
                                Layout.preferredWidth: Kirigami.Units.gridUnit * 0.26
                                Layout.maximumWidth: Kirigami.Units.gridUnit * 0.26
                                Layout.fillHeight: true
                                radius: 2
                                color: aufgabenDelegate.prioritaetFarbe(parent.unterPrioritaet)

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        const naechstePrioritaet = (untereintragZeile.unterPrioritaet + 1) % 3;
                                        aufgabenDelegate.unterPrioritaetGewechselt(untereintragZeile.index, naechstePrioritaet);
                                    }
                                }
                            }

                            QtControls.Label {
                                Layout.fillWidth: true
                                visible: aufgabenDelegate.bearbeiteterUntereintragIndex !== parent.index
                                text: parent.unterText
                                wrapMode: Text.Wrap
                                font.pixelSize: Kirigami.Units.gridUnit * 0.56
                                font.strikeout: parent.unterErledigt
                                opacity: parent.unterErledigt ? 0.62 : 1.0
                                color: Kirigami.Theme.disabledTextColor

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.IBeamCursor
                                    onClicked: {
                                        aufgabenDelegate.untereintragBearbeitungStarten(untereintragZeile.index, untereintragZeile.unterText);
                                        untereintragEingabe.forceActiveFocus();
                                        untereintragEingabe.selectAll();
                                    }
                                }
                            }

                            QtControls.TextArea {
                                id: untereintragEingabe
                                Layout.fillWidth: true
                                visible: aufgabenDelegate.bearbeiteterUntereintragIndex === parent.index
                                text: aufgabenDelegate.bearbeiteterUntereintragText
                                wrapMode: Text.Wrap
                                font.pixelSize: Kirigami.Units.gridUnit * 0.56
                                padding: Kirigami.Units.smallSpacing * 0.25
                                onTextChanged: aufgabenDelegate.bearbeiteterUntereintragText = text
                                onActiveFocusChanged: {
                                    if (!activeFocus && aufgabenDelegate.bearbeiteterUntereintragIndex === parent.index) {
                                        aufgabenDelegate.untereintragBearbeitungSpeichern();
                                    }
                                }

                                Keys.onPressed: function(event) {
                                    if ((event.key === Qt.Key_Return || event.key === Qt.Key_Enter)
                                            && (event.modifiers & Qt.ControlModifier)) {
                                        event.accepted = true;
                                        aufgabenDelegate.untereintragBearbeitungSpeichern();
                                    }
                                }

                                Keys.onEscapePressed: function(event) {
                                    event.accepted = true;
                                    aufgabenDelegate.untereintragBearbeitungAbbrechen();
                                }
                            }
                        }
                    }
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
