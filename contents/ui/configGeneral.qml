import QtQuick
import QtQuick.Controls as QtControls
import org.kde.kirigami as Kirigami

Kirigami.FormLayout {
    id: root
    property string cfg_listTitle: ""
    anchors.fill: parent

    // Plasma initialisiert den Config-Dialog asynchron; der Timer
    // stellt sicher, dass das Feld erst nach der vollständigen
    // Initialisierung aktiviert wird.
    Timer {
        id: aktivierungsTimer
        interval: 50
        repeat: false
        running: false
        onTriggered: {
            titelEingabe.enabled = true;
            titelEingabe.readOnly = false;
            if (titelEingabe.text !== (root.cfg_listTitle || "")) {
                titelEingabe.text = root.cfg_listTitle || "";
            }
        }
    }

    Component.onCompleted: aktivierungsTimer.start()

    QtControls.TextField {
        id: titelEingabe
        selectByMouse: true
        activeFocusOnTab: true
        readOnly: true
        enabled: false
        // qmllint disable unqualified
        Kirigami.FormData.label: i18n("Listenname:")
        placeholderText: i18n("Aufgabenliste")
        // qmllint enable unqualified

        onTextEdited: {
            root.cfg_listTitle = text;
        }
    }
}
