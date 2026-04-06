import QtQuick
import "../logic/AufgabenLogik.js" as AufgabenLogik

/*
 * Dieses Projekt steht unter der MIT-Lizenz.
 * Copyright (c) [Jahr] [Dein Name]
 */

ListModel {
    id: aufgabenModell

    property string tasksJson: "[]"
    property bool _laedtAusSpeicher: false

    signal persistRequested(string json)

    function aufgabeHinzufuegen(beschreibung, prioritaet, faelligkeit) {
        const neueAufgabe = AufgabenLogik.erzeugeAufgabe(beschreibung, prioritaet, faelligkeit);
        if (!neueAufgabe) {
            return;
        }

        append(neueAufgabe);
        persistiere();
    }

    function aufgabeLoeschen(index) {
        if (!istGueltigerIndex(index)) {
            return;
        }

        remove(index, 1);
        persistiere();
    }

    function erledigtSetzen(index, erledigt) {
        if (!istGueltigerIndex(index)) {
            return;
        }

        setProperty(index, "erledigt", !!erledigt);
        persistiere();
    }

    function aktualisiereFaelligkeit(index, faelligkeit) {
        if (!istGueltigerIndex(index)) {
            return;
        }

        setProperty(index, "faelligkeit", faelligkeit || "");
        persistiere();
    }

    function alsArray() {
        const aufgaben = [];

        for (let i = 0; i < count; ++i) {
            aufgaben.push(get(i));
        }

        return aufgaben;
    }

    function persistiere() {
        if (_laedtAusSpeicher) {
            return;
        }

        const json = JSON.stringify(alsArray());
        persistRequested(json);
    }

    function ausJsonLaden(json) {
        const daten = AufgabenLogik.parseAufgaben(json);
        _laedtAusSpeicher = true;
        clear();

        for (let i = 0; i < daten.length; ++i) {
            append(daten[i]);
        }

        _laedtAusSpeicher = false;
    }

    function istGueltigerIndex(index) {
        return index >= 0 && index < count;
    }

    Component.onCompleted: ausJsonLaden(tasksJson)
    onTasksJsonChanged: ausJsonLaden(tasksJson)
}
