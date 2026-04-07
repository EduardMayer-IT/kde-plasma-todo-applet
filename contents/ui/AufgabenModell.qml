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

    function aufgabeHinzufuegen(beschreibung, prioritaet, faelligkeit, notiz) {
        const neueAufgabe = AufgabenLogik.erzeugeAufgabe(beschreibung, prioritaet, faelligkeit, notiz);
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

    function prioritaetSetzen(index, prioritaet) {
        if (!istGueltigerIndex(index) || !AufgabenLogik.istGueltigePrioritaet(prioritaet)) {
            return;
        }

        setProperty(index, "prioritaet", prioritaet);
        persistiere();
    }

    function beschreibungSetzen(index, beschreibung) {
        if (!istGueltigerIndex(index)) {
            return;
        }

        const bereinigt = (beschreibung || "").trim();
        if (!bereinigt) {
            return;
        }

        if (get(index).beschreibung === bereinigt) {
            return;
        }

        setProperty(index, "beschreibung", bereinigt);
        persistiere();
    }

    function notizSetzen(index, notiz) {
        if (!istGueltigerIndex(index)) {
            return;
        }

        const bereinigt = (notiz || "").trim();
        if (get(index).notiz === bereinigt) {
            return;
        }

        setProperty(index, "notiz", bereinigt);
        persistiere();
    }

    function notizAnhaengen(index, text) {
        if (!istGueltigerIndex(index)) {
            return;
        }

        const bereinigt = (text || "").trim();
        if (!bereinigt) {
            return;
        }

        const aktuelleNotiz = (get(index).notiz || "").trim();
        const neueNotiz = aktuelleNotiz.length > 0 ? (aktuelleNotiz + "\n" + bereinigt) : bereinigt;
        setProperty(index, "notiz", neueNotiz);
        persistiere();
    }

    function verschieben(von, nach, persistieren) {
        if (!istGueltigerIndex(von) || !istGueltigerIndex(nach) || von === nach) {
            return;
        }

        move(von, nach, 1);
        if (persistieren !== false) {
            persistiere();
        }
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
