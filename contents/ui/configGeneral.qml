import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QtControls
import org.kde.kirigami as Kirigami

ColumnLayout {
    property alias cfg_listTitle: titelEingabe.text

    Kirigami.FormLayout {
        Layout.fillWidth: true

        QtControls.TextField {
            id: titelEingabe
            selectByMouse: true
            // qmllint disable unqualified
            Kirigami.FormData.label: i18n("Listenname:")
            placeholderText: i18n("Aufgabenliste")
            // qmllint enable unqualified
        }
    }
}
