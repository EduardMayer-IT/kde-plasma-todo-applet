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
    property var dragController: null
    property bool bearbeitungsModus: false
    property int filterModus: 0   // 0=alle, 1=offen, 2=erledigt
    property string bearbeitungsText: ""
    property int bearbeiteterUntereintragIndex: -1
    property string bearbeiteterUntereintragText: ""
    property int letzterZielIndex: -1
    property bool dropAktiv: false
    property bool unterzeilenModusAktiv: false
    property real dragStartXInList: 0
    property real dragStartYInList: 0
    property int unterzeilenZielIndex: -1

    signal erledigtGewechselt(bool istErledigt)
    signal prioritaetGewechselt(int neuePrioritaet)
    signal beschreibungGewechselt(string neueBeschreibung)
    signal untertextGedroppt(string untertext)
    signal unterBeschreibungGewechselt(int unterIndex, string neuerText)
    signal unterPrioritaetGewechselt(int unterIndex, int neuePrioritaet)
    signal unterErledigtGewechselt(int unterIndex, bool istErledigt)
    signal alsUnterzeileVerschiebenAngefragt(int quellIndex, int zielIndex)
    signal faelligkeitGewechselt(string neueFaelligkeit)
    signal loeschenAngefragt()
    signal verschoben(int vonIndex, int nachIndex)
    signal verschiebenBeendet()

    readonly property real zeilenHoehe: Kirigami.Units.gridUnit * 0.9
    readonly property real loeschenSpaltenBreite: Kirigami.Units.gridUnit * 4.8
    readonly property real checkboxSpaltenBreite: Kirigami.Units.gridUnit * 0.82
    readonly property real prioritaetsSpaltenBreite: Kirigami.Units.gridUnit * 0.33
    readonly property real unterzeilenHorizontalSchwelle: 18
    readonly property bool istDragQuelleGlobal: dragStatusAktiv() && dragStatusQuellIndex() === index
    readonly property bool istDragZielGlobal: dragStatusAktiv() && dragStatusZielIndex() === index
    readonly property bool istDragUnterModusGlobal: dragStatusUnterModus()

    readonly property bool gefiltertAusgeblendet:
        (aufgabenDelegate.filterModus === 1 && aufgabenDelegate.erledigt) ||
        (aufgabenDelegate.filterModus === 2 && !aufgabenDelegate.erledigt)

    width: ListView.view ? ListView.view.width : implicitWidth
    padding: Kirigami.Units.smallSpacing * 0.04
    implicitHeight: gefiltertAusgeblendet ? 0 : Math.max(zeilenHoehe, contentItem.implicitHeight + (padding * 2))
    height: implicitHeight
    clip: true
    opacity: gefiltertAusgeblendet ? 0 : (dragMausflaeche.pressed ? 0.72 : 1.0)

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

    function untereintraegeAnzahl() {
        const wert = aufgabenDelegate.untereintraege;
        if (!wert) {
            return 0;
        }
        if (typeof wert.count === "number") {
            return wert.count;
        }
        if (typeof wert.length === "number") {
            return wert.length;
        }
        return 0;
    }

    function holeModell() {
        const listView = aufgabenDelegate.ListView.view;
        return listView ? listView.model : null;
    }

    function setzeDragStatus(aktiv, quellIndex, zielIndex, unterModus) {
        if (!aufgabenDelegate.dragController) {
            return;
        }

        aufgabenDelegate.dragController.dragAktiv = aktiv;
        aufgabenDelegate.dragController.dragQuellIndex = quellIndex;
        aufgabenDelegate.dragController.dragZielIndex = zielIndex;
        aufgabenDelegate.dragController.dragUnterModus = unterModus;
    }

    function dragStatusAktiv() {
        return !!(aufgabenDelegate.dragController && aufgabenDelegate.dragController.dragAktiv);
    }

    function dragStatusQuellIndex() {
        return aufgabenDelegate.dragController ? aufgabenDelegate.dragController.dragQuellIndex : -1;
    }

    function dragStatusZielIndex() {
        return aufgabenDelegate.dragController ? aufgabenDelegate.dragController.dragZielIndex : -1;
    }

    function dragStatusUnterModus() {
        return !!(aufgabenDelegate.dragController && aufgabenDelegate.dragController.dragUnterModus);
    }

    function verschiebeEintrag(vonIndex, nachIndex) {
        const modell = holeModell();
        if (modell && typeof modell.verschieben === "function") {
            modell.verschieben(vonIndex, nachIndex, false);
        } else {
            aufgabenDelegate.verschoben(vonIndex, nachIndex);
        }
        aufgabenDelegate.verschiebenBeendet();
    }

    function verschiebeAlsUnterzeile(quellIndex, zielIndex) {
        const modell = holeModell();
        if (modell && typeof modell.eintragAlsUnterzeileVerschieben === "function") {
            modell.eintragAlsUnterzeileVerschieben(quellIndex, zielIndex);
        } else {
            aufgabenDelegate.alsUnterzeileVerschiebenAngefragt(quellIndex, zielIndex);
        }
        aufgabenDelegate.verschiebenBeendet();
    }

    function untereintragZuHaupteintrag(unterIndex) {
        const modell = holeModell();
        if (modell && typeof modell.untereintragZuHaupteintrag === "function") {
            modell.untereintragZuHaupteintrag(aufgabenDelegate.index, unterIndex);
            aufgabenDelegate.verschiebenBeendet();
        }
    }

    function dragAbschliessen() {
        const quellIndex = aufgabenDelegate.index;
        const modeOK = aufgabenDelegate.unterzeilenModusAktiv;
        const targetOK = aufgabenDelegate.unterzeilenZielIndex >= 0;
        const notSameOK = aufgabenDelegate.unterzeilenZielIndex !== quellIndex;

        if (modeOK && targetOK && notSameOK) {
            aufgabenDelegate.verschiebeAlsUnterzeile(quellIndex, aufgabenDelegate.unterzeilenZielIndex);
        }

        aufgabenDelegate.setzeDragStatus(false, -1, -1, false);

        aufgabenDelegate.letzterZielIndex = -1;
        aufgabenDelegate.unterzeilenModusAktiv = false;
        aufgabenDelegate.unterzeilenZielIndex = -1;
    }

    background: Rectangle {
        radius: 4
        color: aufgabenDelegate.unterzeilenModusAktiv
            ? Qt.rgba(1, 1, 1, 0.08)
            : (aufgabenDelegate.hovered
            ? Qt.rgba(1, 1, 1, 0.05)
            : Kirigami.Theme.backgroundColor)
        border.width: (aufgabenDelegate.unterzeilenModusAktiv || aufgabenDelegate.istDragZielGlobal || aufgabenDelegate.istDragQuelleGlobal) ? 2 : 1
        border.color: aufgabenDelegate.unterzeilenModusAktiv
            ? Kirigami.Theme.highlightColor
            : (aufgabenDelegate.istDragZielGlobal
            ? Qt.rgba(Kirigami.Theme.highlightColor.r, Kirigami.Theme.highlightColor.g, Kirigami.Theme.highlightColor.b, 0.85)
            : (aufgabenDelegate.istDragQuelleGlobal
            ? Qt.rgba(Kirigami.Theme.negativeTextColor.r, Kirigami.Theme.negativeTextColor.g, Kirigami.Theme.negativeTextColor.b, 0.65)
            : (aufgabenDelegate.dropAktiv
            ? Kirigami.Theme.highlightColor
            : Qt.rgba(1, 1, 1, 0.12))))

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

        Rectangle {
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.margins: Kirigami.Units.smallSpacing * 0.45
            visible: aufgabenDelegate.istDragZielGlobal
            radius: 3
            color: aufgabenDelegate.istDragUnterModusGlobal
                ? Qt.rgba(Kirigami.Theme.highlightColor.r, Kirigami.Theme.highlightColor.g, Kirigami.Theme.highlightColor.b, 0.88)
                : Qt.rgba(0.2, 0.68, 0.36, 0.88)
            border.width: 1
            border.color: Qt.rgba(0, 0, 0, 0.22)
            width: zielText.implicitWidth + Kirigami.Units.smallSpacing * 1.2
            height: zielText.implicitHeight + Kirigami.Units.smallSpacing * 0.8

            Text {
                id: zielText
                anchors.centerIn: parent
                text: aufgabenDelegate.istDragUnterModusGlobal ? "ZIEL: UNTEREINTRAG" : "ZIEL: EINFUEGEN"
                color: Kirigami.Theme.highlightedTextColor
                font.pixelSize: Kirigami.Units.gridUnit * 0.42
                font.bold: true
            }
        }

        Rectangle {
            anchors.left: parent.left
            anchors.bottom: parent.bottom
            anchors.margins: Kirigami.Units.smallSpacing * 0.45
            visible: aufgabenDelegate.istDragQuelleGlobal
            radius: 3
            color: Qt.rgba(Kirigami.Theme.negativeTextColor.r, Kirigami.Theme.negativeTextColor.g, Kirigami.Theme.negativeTextColor.b, 0.78)
            border.width: 1
            border.color: Qt.rgba(0, 0, 0, 0.22)
            width: quellText.implicitWidth + Kirigami.Units.smallSpacing * 1.2
            height: quellText.implicitHeight + Kirigami.Units.smallSpacing * 0.8

            Text {
                id: quellText
                anchors.centerIn: parent
                text: "QUELLE"
                color: Kirigami.Theme.highlightedTextColor
                font.pixelSize: Kirigami.Units.gridUnit * 0.4
                font.bold: true
            }
        }

        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            height: 3
            radius: 1
            z: 10
            visible: aufgabenDelegate.istDragZielGlobal && !aufgabenDelegate.istDragUnterModusGlobal
            color: Qt.rgba(0.2, 0.68, 0.36, 0.92)
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
            Layout.preferredWidth: Kirigami.Units.gridUnit * 1.2
            Layout.maximumWidth: Kirigami.Units.gridUnit * 1.2
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
                propagateComposedEvents: false
                preventStealing: true
                acceptedButtons: Qt.LeftButton
                anchors.fill: parent
                cursorShape: dragMausflaeche.pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor

                onPressAndHold: function(mouse) {
                    mouse.accepted = true;
                }

                onPressed: function(mouse) {
                    mouse.accepted = true;
                    aufgabenDelegate.letzterZielIndex = -1;
                    aufgabenDelegate.unterzeilenModusAktiv = false;
                    aufgabenDelegate.unterzeilenZielIndex = -1;

                    const listView = aufgabenDelegate.ListView.view;
                    if (!listView) {
                        return;
                    }
                    const posInList = dragMausflaeche.mapToItem(listView, mouse.x, mouse.y);
                    aufgabenDelegate.dragStartXInList = posInList.x;
                    aufgabenDelegate.dragStartYInList = posInList.y;
                    aufgabenDelegate.setzeDragStatus(true, aufgabenDelegate.index, aufgabenDelegate.index, false);
                }

                onReleased: {
                    aufgabenDelegate.dragAbschliessen();
                }

                onCanceled: {
                    aufgabenDelegate.dragAbschliessen();
                }

                onPositionChanged: function(mouse) {
                    if (!dragMausflaeche.pressed) return;
                    const listView = aufgabenDelegate.ListView.view;
                    if (!listView) {
                        return;
                    }

                    const posInList = dragMausflaeche.mapToItem(listView, mouse.x, mouse.y);
                    const horizontalerVersatz = posInList.x - aufgabenDelegate.dragStartXInList;
                    const vertikalerVersatz = posInList.y - aufgabenDelegate.dragStartYInList;
                    const yInContent = listView.contentY + posInList.y;
                    const horizontalAbs = Math.abs(horizontalerVersatz);
                    const vertikalAbs = Math.abs(vertikalerVersatz);

                    // Aktivierung nur bei klar dominanter Rechtsbewegung
                    if (!aufgabenDelegate.unterzeilenModusAktiv
                            && horizontalerVersatz > aufgabenDelegate.unterzeilenHorizontalSchwelle
                            && horizontalAbs > (vertikalAbs * 1.35)) {
                        aufgabenDelegate.unterzeilenModusAktiv = true;
                    }
                    aufgabenDelegate.setzeDragStatus(
                        true,
                        aufgabenDelegate.dragStatusQuellIndex(),
                        aufgabenDelegate.dragStatusZielIndex(),
                        aufgabenDelegate.unterzeilenModusAktiv
                    );

                    let targetIdx = listView.indexAt(listView.width * 0.5, yInContent);
                    if (targetIdx < 0) {
                        targetIdx = yInContent < 0 ? 0 : (listView.count - 1);
                    }
                    targetIdx = Math.max(0, Math.min(listView.count - 1, targetIdx));

                    // Always keep target index current (needed for correct release handling)
                    aufgabenDelegate.unterzeilenZielIndex = targetIdx;
                    aufgabenDelegate.setzeDragStatus(
                        true,
                        aufgabenDelegate.dragStatusQuellIndex(),
                        targetIdx,
                        aufgabenDelegate.unterzeilenModusAktiv
                    );

                    // In subentry mode: only track target, never reorder
                    if (aufgabenDelegate.unterzeilenModusAktiv) {
                        return;
                    }

                    // Normal vertical reorder
                    if (targetIdx === aufgabenDelegate.index || targetIdx === aufgabenDelegate.letzterZielIndex) {
                        return;
                    }
                    aufgabenDelegate.letzterZielIndex = targetIdx;
                    aufgabenDelegate.verschiebeEintrag(aufgabenDelegate.index, targetIdx);
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
                         && aufgabenDelegate.untereintraegeAnzahl() > 0
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

                            QtControls.Button {
                                id: unterZurueckButton
                                visible: aufgabenDelegate.bearbeiteterUntereintragIndex !== parent.index
                                text: "←"
                                font.pixelSize: Kirigami.Units.gridUnit * 0.5
                                Layout.preferredHeight: Kirigami.Units.gridUnit * 0.68
                                Layout.preferredWidth: Kirigami.Units.gridUnit * 0.68
                                Layout.maximumWidth: Kirigami.Units.gridUnit * 0.68
                                Layout.alignment: Qt.AlignTop
                                opacity: unterZurueckButton.hovered ? 1.0 : 0.75

                                onClicked: {
                                    aufgabenDelegate.untereintragZuHaupteintrag(untereintragZeile.index);
                                }

                                QtControls.ToolTip {
                                    // qmllint disable unqualified
                                    text: i18n("Zur Hauptebene verschieben")
                                    // qmllint enable unqualified
                                    delay: 500
                                    visible: unterZurueckButton.hovered
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

            RowLayout {
                Layout.fillWidth: true
                spacing: Kirigami.Units.smallSpacing * 0.5
                visible: !aufgabenDelegate.bearbeitungsModus

                QtControls.Button {
                    id: datumButton
                    Layout.preferredHeight: Kirigami.Units.gridUnit * 0.78
                    padding: Kirigami.Units.smallSpacing * 0.6
                    // qmllint disable unqualified
                    text: aufgabenDelegate.faelligkeit.length > 0
                        ? (aufgabenDelegate.istUeberfaellig(aufgabenDelegate.faelligkeit)
                            ? "⚠ " + aufgabenDelegate.faelligkeit
                            : "📅 " + aufgabenDelegate.faelligkeit)
                        : i18n("+ Datum")
                    // qmllint enable unqualified
                    font.pixelSize: Kirigami.Units.gridUnit * 0.52
                    opacity: datumButton.hovered ? 1.0 : (aufgabenDelegate.faelligkeit.length > 0 ? 0.9 : 0.45)

                    background: Rectangle {
                        radius: 3
                        color: aufgabenDelegate.istUeberfaellig(aufgabenDelegate.faelligkeit)
                            ? Qt.rgba(0.84, 0.2, 0.2, datumButton.hovered ? 0.22 : 0.1)
                            : Qt.rgba(1, 1, 1, datumButton.hovered ? 0.1 : 0.0)
                        border.width: aufgabenDelegate.faelligkeit.length > 0 ? 1 : 0
                        border.color: aufgabenDelegate.istUeberfaellig(aufgabenDelegate.faelligkeit)
                            ? Qt.rgba(0.92, 0.26, 0.26, 0.5)
                            : Qt.rgba(1, 1, 1, 0.18)
                    }

                    contentItem: Text {
                        text: datumButton.text
                        font: datumButton.font
                        color: aufgabenDelegate.istUeberfaellig(aufgabenDelegate.faelligkeit)
                            ? Kirigami.Theme.negativeTextColor
                            : (aufgabenDelegate.faelligkeit.length > 0
                                ? Kirigami.Theme.textColor
                                : Kirigami.Theme.disabledTextColor)
                        verticalAlignment: Text.AlignVCenter
                        horizontalAlignment: Text.AlignLeft
                    }

                    onClicked: datumPopup.open()

                    QtControls.Popup {
                        id: datumPopup
                        y: datumButton.height + Kirigami.Units.smallSpacing * 0.5
                        x: 0
                        width: Kirigami.Units.gridUnit * 11
                        padding: Kirigami.Units.smallSpacing * 0.8
                        modal: true
                        focus: true
                        closePolicy: QtControls.Popup.CloseOnEscape | QtControls.Popup.CloseOnPressOutside

                        background: Rectangle {
                            radius: 5
                            color: Kirigami.Theme.backgroundColor
                            border.width: 1
                            border.color: Qt.rgba(1, 1, 1, 0.18)
                        }

                        ColumnLayout {
                            anchors.fill: parent
                            spacing: Kirigami.Units.smallSpacing * 0.5

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: Kirigami.Units.smallSpacing * 0.5

                                QtControls.TextField {
                                    id: datumEingabe
                                    Layout.fillWidth: true
                                    // qmllint disable unqualified
                                    placeholderText: i18n("YYYY-MM-DD")
                                    // qmllint enable unqualified
                                    text: aufgabenDelegate.faelligkeit
                                    font.pixelSize: Kirigami.Units.gridUnit * 0.6
                                    padding: Kirigami.Units.smallSpacing * 0.5

                                    Keys.onReturnPressed: {
                                        datumPopup.datumUebernehmen(datumEingabe.text.trim());
                                    }
                                }

                                QtControls.Button {
                                    // qmllint disable unqualified
                                    text: i18n("OK")
                                    // qmllint enable unqualified
                                    font.pixelSize: Kirigami.Units.gridUnit * 0.55
                                    Layout.preferredHeight: Kirigami.Units.gridUnit * 0.9
                                    onClicked: datumPopup.datumUebernehmen(datumEingabe.text.trim())
                                }
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: Kirigami.Units.smallSpacing * 0.5

                                Repeater {
                                    model: [
                                        // qmllint disable unqualified
                                        { label: i18n("Heute"),   tage: 0 },
                                        { label: i18n("Morgen"),  tage: 1 },
                                        { label: i18n("+7 Tage"), tage: 7 }
                                        // qmllint enable unqualified
                                    ]

                                    delegate: QtControls.Button {
                                        required property var modelData
                                        text: modelData.label
                                        font.pixelSize: Kirigami.Units.gridUnit * 0.52
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: Kirigami.Units.gridUnit * 0.82
                                        onClicked: {
                                            const d = new Date();
                                            d.setDate(d.getDate() + modelData.tage);
                                            const iso = d.toISOString().substring(0, 10);
                                            datumPopup.datumUebernehmen(iso);
                                        }
                                    }
                                }
                            }

                            QtControls.Button {
                                // qmllint disable unqualified
                                text: i18n("Datum entfernen")
                                // qmllint enable unqualified
                                font.pixelSize: Kirigami.Units.gridUnit * 0.52
                                Layout.fillWidth: true
                                Layout.preferredHeight: Kirigami.Units.gridUnit * 0.78
                                visible: aufgabenDelegate.faelligkeit.length > 0
                                opacity: 0.72
                                onClicked: datumPopup.datumUebernehmen("")
                            }
                        }

                        function datumUebernehmen(wert) {
                            datumPopup.close();
                            aufgabenDelegate.faelligkeitGewechselt(wert);
                        }
                    }
                }
            }
        }

        RowLayout {
            Layout.alignment: Qt.AlignVCenter
            spacing: Kirigami.Units.smallSpacing * 0.2

            QtControls.Button {
                id: hochButton
                text: "↑"
                font.pixelSize: Kirigami.Units.gridUnit * 0.52
                Layout.preferredHeight: Kirigami.Units.gridUnit * 0.72
                Layout.preferredWidth: Kirigami.Units.gridUnit * 0.72
                Layout.maximumWidth: Kirigami.Units.gridUnit * 0.72
                enabled: aufgabenDelegate.index > 0
                opacity: hochButton.enabled ? (hochButton.hovered ? 1.0 : 0.72) : 0.35

                onClicked: {
                    aufgabenDelegate.verschiebeEintrag(aufgabenDelegate.index, aufgabenDelegate.index - 1);
                }

                QtControls.ToolTip {
                    // qmllint disable unqualified
                    text: i18n("Eine Position nach oben")
                    // qmllint enable unqualified
                    delay: 500
                    visible: hochButton.hovered
                }
            }

            QtControls.Button {
                id: runterButton
                text: "↓"
                font.pixelSize: Kirigami.Units.gridUnit * 0.52
                Layout.preferredHeight: Kirigami.Units.gridUnit * 0.72
                Layout.preferredWidth: Kirigami.Units.gridUnit * 0.72
                Layout.maximumWidth: Kirigami.Units.gridUnit * 0.72
                enabled: aufgabenDelegate.ListView.view ? aufgabenDelegate.index < (aufgabenDelegate.ListView.view.count - 1) : false
                opacity: runterButton.enabled ? (runterButton.hovered ? 1.0 : 0.72) : 0.35

                onClicked: {
                    aufgabenDelegate.verschiebeEintrag(aufgabenDelegate.index, aufgabenDelegate.index + 1);
                }

                QtControls.ToolTip {
                    // qmllint disable unqualified
                    text: i18n("Eine Position nach unten")
                    // qmllint enable unqualified
                    delay: 500
                    visible: runterButton.hovered
                }
            }

            QtControls.Button {
                id: unterzeileButton
                text: "→"
                font.pixelSize: Kirigami.Units.gridUnit * 0.52
                Layout.preferredHeight: Kirigami.Units.gridUnit * 0.72
                Layout.preferredWidth: Kirigami.Units.gridUnit * 0.72
                Layout.maximumWidth: Kirigami.Units.gridUnit * 0.72
                enabled: aufgabenDelegate.index > 0
                opacity: unterzeileButton.enabled ? (unterzeileButton.hovered ? 1.0 : 0.72) : 0.35

                onClicked: {
                    aufgabenDelegate.verschiebeAlsUnterzeile(aufgabenDelegate.index, aufgabenDelegate.index - 1);
                }

                QtControls.ToolTip {
                    // qmllint disable unqualified
                    text: i18n("Als Unterzeile unter die vorherige Aufgabe")
                    // qmllint enable unqualified
                    delay: 500
                    visible: unterzeileButton.hovered
                }
            }
        }

        QtControls.Button {
            id: loeschenButton
            text: "✕"
            font.pixelSize: Kirigami.Units.gridUnit * 0.82
            font.bold: false
            Layout.preferredHeight: Kirigami.Units.gridUnit * 1.18
            Layout.preferredWidth: Kirigami.Units.gridUnit * 1.18
            Layout.maximumWidth: Kirigami.Units.gridUnit * 1.18
            Layout.alignment: Qt.AlignVCenter
            Layout.rightMargin: Kirigami.Units.smallSpacing * 0.85
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
