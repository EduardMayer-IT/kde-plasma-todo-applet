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

    function untereintragHinzufuegen(index, beschreibung, prioritaet, erledigt) {
        if (!istGueltigerIndex(index)) {
            return;
        }

        const bereinigt = (beschreibung || "").trim();
        if (!bereinigt) {
            return;
        }

        const liste = klonUntereintraege(index);
        liste.push({
            beschreibung: bereinigt,
            prioritaet: AufgabenLogik.istGueltigePrioritaet(prioritaet) ? prioritaet : 0,
            erledigt: !!erledigt
        });

        setProperty(index, "untereintraege", liste);
        persistiere();
    }

    function untereintragBeschreibungSetzen(index, unterIndex, beschreibung) {
        if (!istGueltigerUntereintragIndex(index, unterIndex)) {
            return;
        }

        const bereinigt = (beschreibung || "").trim();
        if (!bereinigt) {
            return;
        }

        const liste = klonUntereintraege(index);
        if ((liste[unterIndex].beschreibung || "") === bereinigt) {
            return;
        }

        liste[unterIndex].beschreibung = bereinigt;
        setProperty(index, "untereintraege", liste);
        persistiere();
    }

    function untereintragPrioritaetSetzen(index, unterIndex, prioritaet) {
        if (!istGueltigerUntereintragIndex(index, unterIndex) || !AufgabenLogik.istGueltigePrioritaet(prioritaet)) {
            return;
        }

        const liste = klonUntereintraege(index);
        liste[unterIndex].prioritaet = prioritaet;
        setProperty(index, "untereintraege", liste);
        persistiere();
    }

    function untereintragErledigtSetzen(index, unterIndex, erledigt) {
        if (!istGueltigerUntereintragIndex(index, unterIndex)) {
            return;
        }

        const liste = klonUntereintraege(index);
        liste[unterIndex].erledigt = !!erledigt;
        setProperty(index, "untereintraege", liste);
        persistiere();
    }

    function eintragAlsUnterzeileVerschieben(quellIndex, zielIndex) {
        if (!istGueltigerIndex(quellIndex) || !istGueltigerIndex(zielIndex) || quellIndex === zielIndex) {
            return;
        }

        const quelle = get(quellIndex);
        const quellBeschreibung = (quelle.beschreibung || "").trim();
        if (!quellBeschreibung) {
            return;
        }

        const zielUntereintraege = klonUntereintraege(zielIndex);
        zielUntereintraege.push({
            beschreibung: quellBeschreibung,
            prioritaet: AufgabenLogik.istGueltigePrioritaet(quelle.prioritaet) ? quelle.prioritaet : 0,
            erledigt: !!quelle.erledigt
        });

        const quellenUnter = Array.isArray(quelle.untereintraege) ? quelle.untereintraege : [];
        for (let i = 0; i < quellenUnter.length; ++i) {
            const unter = quellenUnter[i];
            const text = (unter && unter.beschreibung ? unter.beschreibung : "").trim();
            if (!text) {
                continue;
            }

            zielUntereintraege.push({
                beschreibung: text,
                prioritaet: AufgabenLogik.istGueltigePrioritaet(unter.prioritaet) ? unter.prioritaet : 0,
                erledigt: !!unter.erledigt
            });
        }

        setProperty(zielIndex, "untereintraege", zielUntereintraege);
        remove(quellIndex, 1);
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

    function klonUntereintraege(index) {
        const quelle = get(index).untereintraege;
        if (!Array.isArray(quelle)) {
            return [];
        }

        const kopie = [];
        for (let i = 0; i < quelle.length; ++i) {
            const eintrag = quelle[i] || {};
            kopie.push({
                beschreibung: (eintrag.beschreibung || "").trim(),
                prioritaet: AufgabenLogik.istGueltigePrioritaet(eintrag.prioritaet) ? eintrag.prioritaet : 0,
                erledigt: !!eintrag.erledigt
            });
        }

        return kopie;
    }

    function istGueltigerUntereintragIndex(index, unterIndex) {
        if (!istGueltigerIndex(index) || unterIndex < 0) {
            return false;
        }

        const liste = get(index).untereintraege;
        return Array.isArray(liste) && unterIndex < liste.length;
    }

    Component.onCompleted: ausJsonLaden(tasksJson)
    onTasksJsonChanged: ausJsonLaden(tasksJson)
}
