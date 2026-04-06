import QtQuick
import org.kde.plasma.configuration as PlasmaConfig

PlasmaConfig.ConfigModel {
    PlasmaConfig.ConfigCategory {
        name: i18n("Allgemein")
        icon: "preferences-other"
        source: "configGeneral.qml"
    }
}
