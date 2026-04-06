import QtQuick

/*
 * Dieses Projekt steht unter der MIT-Lizenz.
 * Copyright (c) [Jahr] [Dein Name]
 */

QtObject {
    id: datenSynchronisierer

    property string benutzername: ""
    property string nextcloudUrl: ""
    readonly property bool kannSynchronisieren: nextcloudUrl.length > 0 && benutzername.length > 0

    function synchronisiereMitCloud(aufgaben) {
        if (!kannSynchronisieren) {
            console.warn("Synchronisation uebersprungen: Nextcloud ist nicht konfiguriert.");
            return false;
        }

        console.log("Synchronisiere", aufgaben.length, "Aufgaben mit", nextcloudUrl);
        return true;
    }
}
